package Utils;

import com.google.gson.*;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/**
 * Resolves exact sample metadata and at most one audited primary publication.
 * Article text remains outside the WAR and is read from the private corpus.
 */
public final class LiteratureContextRepository {
    private static final int MAX_ARTICLE_CHARS = 1_000_000;

    private final Gson gson = new Gson();
    private final Map<String, JsonObject> datasets = new HashMap<>();
    private final Map<String, JsonObject> sampleContexts = new HashMap<>();
    private final Map<String, JsonObject> paperSelections = new HashMap<>();
    private final Path literatureRoot;

    public LiteratureContextRepository() throws IOException {
        this(resolveLiteratureRoot());
    }

    LiteratureContextRepository(Path literatureRoot) throws IOException {
        this.literatureRoot = literatureRoot;
        load();
    }

    private static Path resolveLiteratureRoot() {
        String configured = System.getenv("SCSAID_LITERATURE_ROOT");
        if (configured == null || configured.trim().isEmpty()) {
            configured = System.getProperty("scsaid.literature.root", "/srv/scsaid-literature");
        }
        return Paths.get(configured).toAbsolutePath().normalize();
    }

    private void load() throws IOException {
        JsonObject registry = resourceObject("literature/registry.json");
        for (JsonElement element : registry.getAsJsonArray("datasets")) {
            JsonObject dataset = element.getAsJsonObject();
            datasets.put(string(dataset, "said"), dataset);
        }

        JsonObject samples = resourceObject("literature/sample_context.json");
        for (Map.Entry<String, JsonElement> entry : samples.getAsJsonObject("samples").entrySet()) {
            sampleContexts.put(entry.getKey(), entry.getValue().getAsJsonObject());
        }

        JsonObject selections = resourceObject("literature/canonical_sample_papers.json");
        for (JsonElement element : selections.getAsJsonArray("samples")) {
            JsonObject selection = element.getAsJsonObject();
            paperSelections.put(string(selection, "said"), selection);
        }
        if (datasets.size() != 252 || sampleContexts.size() != 252 || paperSelections.size() != 252) {
            throw new IOException("The sample-resolved literature indexes are incomplete.");
        }
    }

    public Context resolve(String said) throws IOException {
        JsonObject dataset = datasets.get(said);
        JsonObject sample = sampleContexts.get(said);
        JsonObject paper = paperSelections.get(said);
        if (dataset == null || sample == null || paper == null) {
            throw new IllegalArgumentException("Unknown dataset identifier.");
        }
        String sampleAccession = string(dataset, "sample_accession");
        if (!sampleAccession.equals(string(sample, "sample_accession"))
                || !sampleAccession.equals(string(paper, "sample_accession"))) {
            throw new IOException("Sample context integrity check failed.");
        }
        if (!string(dataset, "study_accession").equals(string(sample, "parent_study_accession"))
                || !string(dataset, "study_accession").equals(string(paper, "study_accession"))) {
            throw new IOException("Parent study integrity check failed.");
        }

        JsonObject annotations = new JsonObject();
        for (String key : Arrays.asList(
                "said", "study_accession", "sample_accession", "species", "cells",
                "condition", "age", "sex", "tissue", "fine_cell_types", "gross_cell_types")) {
            if (dataset.has(key)) annotations.add(key, dataset.get(key).deepCopy());
        }

        JsonObject publication = null;
        String fullText = "";
        if ("verified_primary".equals(string(paper, "status"))) {
            publication = paper.deepCopy();
            String paperId = string(paper, "paper_id");
            if (!paperId.matches("PMID_\\d+")) {
                throw new IOException("Unsafe canonical paper identifier.");
            }
            Path textPath = literatureRoot.resolve("text").resolve(paperId + ".txt").normalize();
            Path textRoot = literatureRoot.resolve("text").normalize();
            if (!textPath.startsWith(textRoot) || !Files.isRegularFile(textPath)) {
                throw new IOException("Verified primary publication full text is unavailable.");
            }
            fullText = readLimited(textPath, MAX_ARTICLE_CHARS);
            if (fullText.trim().length() < 1_000) {
                throw new IOException("Verified primary publication full text is incomplete.");
            }
        }
        return new Context(annotations, sample.deepCopy(), publication, fullText);
    }

    public JsonObject publicSummary(String said) throws IOException {
        Context context = resolve(said);
        JsonObject summary = new JsonObject();
        summary.addProperty("said", string(context.annotations, "said"));
        summary.addProperty("sampleAccession", string(context.annotations, "sample_accession"));
        summary.addProperty("studyAccession", string(context.annotations, "study_accession"));
        summary.addProperty("repository", string(context.sampleContext, "repository"));
        summary.addProperty("sampleSourceUrl", string(context.sampleContext, "source_url"));
        summary.addProperty("hasVerifiedPrimaryPaper", context.publication != null);
        if (context.publication != null) {
            JsonObject citation = new JsonObject();
            for (String key : Arrays.asList("title", "pmid", "doi", "journal", "year")) {
                if (context.publication.has(key)) {
                    citation.add(key, context.publication.get(key).deepCopy());
                }
            }
            summary.add("publication", citation);
        }
        return summary;
    }

    private JsonObject resourceObject(String path) throws IOException {
        InputStream stream = LiteratureContextRepository.class.getClassLoader().getResourceAsStream(path);
        if (stream == null) throw new FileNotFoundException("Missing application resource: " + path);
        try (Reader reader = new InputStreamReader(stream, StandardCharsets.UTF_8)) {
            return JsonParser.parseReader(reader).getAsJsonObject();
        } catch (RuntimeException ex) {
            throw new IOException("Invalid application resource: " + path, ex);
        }
    }

    private String readLimited(Path path, int limit) throws IOException {
        try (Reader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
            char[] buffer = new char[8192];
            StringBuilder value = new StringBuilder();
            int count;
            while ((count = reader.read(buffer)) != -1) {
                if (value.length() + count > limit) {
                    throw new IOException("Canonical article exceeds the allowed size.");
                }
                value.append(buffer, 0, count);
            }
            return value.toString();
        }
    }

    private static String string(JsonObject object, String key) {
        return object != null && object.has(key) && !object.get(key).isJsonNull()
                ? object.get(key).getAsString() : "";
    }

    public static final class Context {
        public final JsonObject annotations;
        public final JsonObject sampleContext;
        public final JsonObject publication;
        public final String fullText;

        private Context(JsonObject annotations, JsonObject sampleContext,
                        JsonObject publication, String fullText) {
            this.annotations = annotations;
            this.sampleContext = sampleContext;
            this.publication = publication;
            this.fullText = fullText;
        }
    }
}
