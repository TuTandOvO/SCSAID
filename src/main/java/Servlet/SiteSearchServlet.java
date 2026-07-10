package Servlet;

import com.google.gson.Gson;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Lightweight navigation search for shared site functions and dataset sections. */
public class SiteSearchServlet extends HttpServlet {
    private static final Gson GSON = new Gson();
    private static final Pattern DATASET_ID = Pattern.compile("(?i)\\b(?:SAID|GSM|GSE)\\d+\\b");
    private static final int MAX_RESULTS = 8;

    private static final List<FunctionEntry> FUNCTIONS;
    private static final List<DatasetEntry> DATASETS;

    static {
        List<FunctionEntry> functions = new ArrayList<>();
        functions.add(new FunctionEntry("Browse datasets", "Explore all scRNA-seq datasets", "browse.jsp", "Browse", "browse dataset studies samples accession gse gsm said"));
        functions.add(new FunctionEntry("Search Marker", "Find cell-type marker genes across datasets", "gene-search.jsp", "Analysis", "marker markers cell type cluster gene search"));
        functions.add(new FunctionEntry("Search DEG", "Find condition or perturbation versus Healthy DEGs", "deg-search.jsp", "Analysis", "deg differential expression disease perturbation condition healthy gene search"));
        functions.add(new FunctionEntry("Gene expression", "Visualize integrated gene expression", "featureplot.jsp", "Analysis", "expression feature plot featureplot umap gene visualization"));
        functions.add(new FunctionEntry("Compare conditions", "Compare cell populations between conditions", "compare.jsp", "Analysis", "compare comparison condition disease healthy"));
        functions.add(new FunctionEntry("psoSpotter", "Run the biomarker panel selection pipeline on uploaded h5ad data", "psospotter.jsp", "Analysis", "psospotter biomarker panel selection uploaded h5ad gene list cross species ortholog"));
        functions.add(new FunctionEntry("Cell-cell communication", "Choose a dataset, then open communication inference", "browse.jsp", "Analysis", "ccc communication cell-cell cellphone cell phone ligand receptor interaction cpdb cellphonedb"));
        functions.add(new FunctionEntry("Cell clustering", "Choose a dataset to inspect clusters and UMAPs", "browse.jsp", "Analysis", "cell clustering cluster umap annotation"));
        functions.add(new FunctionEntry("Cell proportions", "Choose a dataset to inspect cell composition", "browse.jsp", "Analysis", "cell proportion proportions composition abundance"));
        functions.add(new FunctionEntry("Gene set scoring", "Choose a dataset to inspect gene signatures", "browse.jsp", "Analysis", "gene set scoring score signature module"));
        functions.add(new FunctionEntry("Enrichment analysis", "Choose a dataset to inspect enriched pathways", "browse.jsp", "Analysis", "enrichment pathway gsea ora ontology go kegg"));
        functions.add(new FunctionEntry("Download data", "Download processed scSAID datasets", "download.jsp", "Data", "download data files h5ad"));
        functions.add(new FunctionEntry("Help and FAQ", "Read answers to common questions", "help?topic=faq", "Help", "help faq questions support"));
        functions.add(new FunctionEntry("Methods", "Read analysis methods and definitions", "help?topic=methods", "Help", "methods methodology analysis"));
        functions.add(new FunctionEntry("Marker reference", "Review marker genes used by scSAID", "help?topic=markers", "Help", "markers marker reference genes"));
        functions.add(new FunctionEntry("Analysis pipeline", "Review the scSAID processing pipeline", "help?topic=pipeline", "Help", "pipeline workflow processing"));
        functions.add(new FunctionEntry("Usage guide", "Learn how to use scSAID", "help?topic=usage", "Help", "usage guide tutorial instructions"));
        functions.add(new FunctionEntry("Feedback", "Send feedback to the scSAID team", "feedback", "Support", "feedback contact report support"));
        FUNCTIONS = Collections.unmodifiableList(functions);

        List<DatasetEntry> datasets = new ArrayList<>();
        for (Map.Entry<String, Map<String, String>> item : MappingLoader.load().entrySet()) {
            Map<String, String> values = item.getValue();
            datasets.add(new DatasetEntry(item.getKey(), values.get("GSE"), values.get("GSM"), values.get("species")));
        }
        datasets.sort(Comparator.comparing(dataset -> dataset.said));
        DATASETS = Collections.unmodifiableList(datasets);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String query = request.getParameter("q");
        if (query != null && query.length() > 256) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Search query is too long");
            return;
        }
        String contextPath = request.getContextPath();
        List<SearchResult> results = search(query == null ? "" : query, contextPath == null ? "" : contextPath);

        response.setCharacterEncoding("UTF-8");
        response.setContentType("application/json");
        response.setHeader("Cache-Control", "no-store");
        GSON.toJson(results, response.getWriter());
    }

    static List<SearchResult> search(String rawQuery, String contextPath) {
        String query = normalize(rawQuery);
        String section = detectSection(query);
        String identifier = extractIdentifier(rawQuery);
        List<SearchResult> results = new ArrayList<>();

        if (identifier != null) {
            for (DatasetEntry dataset : DATASETS) {
                if (dataset.matches(identifier)) {
                    results.add(dataset.toResult(contextPath, section));
                    if (results.size() == MAX_RESULTS) return results;
                }
            }
        }

        List<ScoredFunction> matches = new ArrayList<>();
        if (query.isEmpty()) {
            for (int i = 0; i < Math.min(6, FUNCTIONS.size()); i++) {
                matches.add(new ScoredFunction(FUNCTIONS.get(i), 1));
            }
        } else {
            for (FunctionEntry function : FUNCTIONS) {
                int score = function.score(query);
                if (score > 0) matches.add(new ScoredFunction(function, score));
            }
            matches.sort(Comparator.comparingInt((ScoredFunction match) -> match.score).reversed());
        }

        for (ScoredFunction match : matches) {
            results.add(match.function.toResult(contextPath));
            if (results.size() == MAX_RESULTS) break;
        }
        return results;
    }

    private static String extractIdentifier(String query) {
        Matcher matcher = DATASET_ID.matcher(query == null ? "" : query);
        return matcher.find() ? matcher.group().toUpperCase(Locale.ROOT) : null;
    }

    private static String detectSection(String query) {
        if (containsAny(query, " ccc ", "communication", "cell-cell", "cellphone", "cell phone", "ligand", "receptor", "cpdb")) return "CellPhoneDBAnalysis";
        if (containsAny(query, " deg ", "differential expression", "marker")) return "DEGResults";
        if (containsAny(query, "proportion", "composition", "abundance")) return "CellProportion";
        if (containsAny(query, "clustering", "cluster", "umap")) return "CellClustering";
        if (containsAny(query, "gene set", "scoring", "signature", "module score")) return "GeneSetScoring";
        if (containsAny(query, "enrichment", "pathway", "gsea", " ora ", "ontology")) return "EnrichmentAnalysis";
        if (containsAny(query, "psospotter", "biomarker panel", "ortholog", "uploaded h5ad")) return "PsoSpotter";
        return "ExperimentInformation";
    }

    private static boolean containsAny(String query, String... terms) {
        String padded = " " + query + " ";
        for (String term : terms) {
            if (term.startsWith(" ") || term.endsWith(" ")) {
                if (padded.contains(term)) return true;
            } else if (query.contains(term)) {
                return true;
            }
        }
        return false;
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim().toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");
    }

    private static String withContext(String contextPath, String path) {
        String base = contextPath == null ? "" : contextPath;
        return base + "/" + path;
    }

    static final class SearchResult {
        final String title;
        final String description;
        final String url;
        final String category;

        SearchResult(String title, String description, String url, String category) {
            this.title = title;
            this.description = description;
            this.url = url;
            this.category = category;
        }
    }

    private static final class DatasetEntry {
        final String said;
        final String gse;
        final String gsm;
        final String species;

        DatasetEntry(String said, String gse, String gsm, String species) {
            this.said = said == null ? "" : said.toUpperCase(Locale.ROOT);
            this.gse = gse == null ? "" : gse.toUpperCase(Locale.ROOT);
            this.gsm = gsm == null ? "" : gsm.toUpperCase(Locale.ROOT);
            this.species = species == null ? "" : species;
        }

        boolean matches(String identifier) {
            return said.equals(identifier) || gsm.equals(identifier) || gse.equals(identifier);
        }

        SearchResult toResult(String contextPath, String section) {
            Map<String, String> sectionNames = new LinkedHashMap<>();
            sectionNames.put("ExperimentInformation", "Dataset overview");
            sectionNames.put("CellProportion", "Cell proportions");
            sectionNames.put("CellClustering", "Cell clustering");
            sectionNames.put("DEGResults", "Differential expression");
            sectionNames.put("GeneSetScoring", "Gene set scoring");
            sectionNames.put("CellPhoneDBAnalysis", "Cell-cell communication inference");
            sectionNames.put("EnrichmentAnalysis", "Enrichment analysis");
            sectionNames.put("PsoSpotter", "psoSpotter");
            String sectionName = sectionNames.getOrDefault(section, "Dataset overview");
            String title = gsm + " — " + sectionName;
            String description = said + " · " + gse + (species.isEmpty() ? "" : " · " + species);
            String url = withContext(contextPath, "details.jsp?said=" + said + "#" + section);
            return new SearchResult(title, description, url, "Dataset");
        }
    }

    private static final class FunctionEntry {
        final String title;
        final String description;
        final String path;
        final String category;
        final String keywords;

        FunctionEntry(String title, String description, String path, String category, String keywords) {
            this.title = title;
            this.description = description;
            this.path = path;
            this.category = category;
            this.keywords = normalize(title + " " + keywords);
        }

        int score(String query) {
            if (keywords.equals(query)) return 100;
            String normalizedTitle = normalize(title);
            if (normalizedTitle.startsWith(query)) return 80;
            if (normalizedTitle.contains(query)) return 70;
            if (keywords.contains(query)) return 60;
            int score = 0;
            for (String token : query.split(" ")) {
                if (token.length() > 1 && keywords.contains(token)) score += 10;
            }
            return score;
        }

        SearchResult toResult(String contextPath) {
            return new SearchResult(title, description, withContext(contextPath, path), category);
        }
    }

    private static final class ScoredFunction {
        final FunctionEntry function;
        final int score;

        ScoredFunction(FunctionEntry function, int score) {
            this.function = function;
            this.score = score;
        }
    }
}
