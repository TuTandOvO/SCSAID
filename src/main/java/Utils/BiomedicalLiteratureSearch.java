package Utils;

import com.google.gson.*;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.*;

/** Small, citation-bearing biomedical search bridge used by DeepSeek tools. */
public class BiomedicalLiteratureSearch {
    private static final int CONNECT_TIMEOUT_MS = 12_000;
    private static final int READ_TIMEOUT_MS = 25_000;
    private static final int MAX_RESULTS = 6;
    private final Gson gson = new Gson();
    private final String europePmcUrl;
    private final String crossrefUrl;

    public BiomedicalLiteratureSearch() {
        this(
                "https://www.ebi.ac.uk/europepmc/webservices/rest/search",
                "https://api.crossref.org/works"
        );
    }

    BiomedicalLiteratureSearch(String europePmcUrl) {
        this(europePmcUrl, "https://api.crossref.org/works");
    }

    BiomedicalLiteratureSearch(String europePmcUrl, String crossrefUrl) {
        this.europePmcUrl = europePmcUrl;
        this.crossrefUrl = crossrefUrl;
    }

    public SearchResult search(String query) throws IOException {
        String clean = query == null ? "" : query.replaceAll("[\\p{Cntrl}]+", " ").trim();
        if (clean.length() < 2 || clean.length() > 300) {
            throw new IllegalArgumentException("Literature search query must contain 2–300 characters.");
        }
        String endpoint = europePmcUrl + "?query=" + URLEncoder.encode(clean, StandardCharsets.UTF_8.name())
                + "&format=json&resultType=core&pageSize=" + MAX_RESULTS;
        JsonObject response;
        try {
            response = getJson(endpoint);
        } catch (IOException ignored) {
            response = new JsonObject();
        }
        JsonArray raw = response.has("resultList")
                ? response.getAsJsonObject("resultList").getAsJsonArray("result") : new JsonArray();
        JsonArray toolResults = new JsonArray();
        JsonArray sources = new JsonArray();
        Set<String> seen = new HashSet<>();
        for (JsonElement element : raw) {
            JsonObject item = element.getAsJsonObject();
            JsonObject normalized = new JsonObject();
            copy(item, normalized, "title");
            copy(item, normalized, "authorString");
            copy(item, normalized, "journalTitle");
            copy(item, normalized, "pubYear");
            copy(item, normalized, "pmid");
            copy(item, normalized, "doi");
            copy(item, normalized, "abstractText");
            String pmid = string(item, "pmid");
            String doi = string(item, "doi");
            String url = !pmid.isEmpty() ? "https://pubmed.ncbi.nlm.nih.gov/" + pmid + "/"
                    : (!doi.isEmpty() ? "https://doi.org/" + doi : "");
            normalized.addProperty("url", url);
            toolResults.add(normalized);
            sources.add(source(string(item, "title"), "Europe PMC / PubMed", pmid, doi, url));
            seen.add(!doi.isEmpty() ? doi.toLowerCase(Locale.ROOT) : url);
        }

        if (toolResults.size() < MAX_RESULTS) {
            try {
                JsonObject crossref = getJson(
                        crossrefUrl + "?query.bibliographic="
                                + URLEncoder.encode(clean, StandardCharsets.UTF_8.name())
                                + "&rows=" + (MAX_RESULTS - toolResults.size())
                );
                JsonArray items = crossref.has("message")
                        ? crossref.getAsJsonObject("message").getAsJsonArray("items") : new JsonArray();
                for (JsonElement element : items) {
                    JsonObject item = element.getAsJsonObject();
                    String doi = string(item, "DOI");
                    String url = !doi.isEmpty() ? "https://doi.org/" + doi : string(item, "URL");
                    String identity = !doi.isEmpty() ? doi.toLowerCase(Locale.ROOT) : url;
                    if (identity.isEmpty() || !seen.add(identity)) continue;
                    String title = firstArrayString(item, "title");
                    JsonObject normalized = new JsonObject();
                    normalized.addProperty("title", title);
                    normalized.addProperty("journalTitle", firstArrayString(item, "container-title"));
                    normalized.addProperty("doi", doi);
                    normalized.addProperty("url", url);
                    if (item.has("abstract")) {
                        normalized.addProperty(
                                "abstractText",
                                item.get("abstract").getAsString().replaceAll("<[^>]+>", " ")
                        );
                    }
                    toolResults.add(normalized);
                    sources.add(source(title, "Crossref", "", doi, url));
                }
            } catch (IOException ignored) {
                // Europe PMC results remain usable if Crossref is temporarily down.
            }
        }
        JsonObject toolPayload = new JsonObject();
        toolPayload.addProperty("query", clean);
        toolPayload.addProperty("status",
                toolResults.size() == 0 ? "search_unavailable_or_no_results" : "results_returned");
        toolPayload.add("results", toolResults);
        return new SearchResult(gson.toJson(toolPayload), sources);
    }

    private JsonObject getJson(String endpoint) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) new URL(endpoint).openConnection();
        connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
        connection.setReadTimeout(READ_TIMEOUT_MS);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("User-Agent", "scSAID/1.0 (mailto:admin@skin-scsaid.com)");
        int status = connection.getResponseCode();
        if (status < 200 || status >= 300) {
            connection.disconnect();
            throw new IOException("Biomedical literature search is temporarily unavailable.");
        }
        try (Reader reader = new InputStreamReader(connection.getInputStream(), StandardCharsets.UTF_8)) {
            return JsonParser.parseReader(reader).getAsJsonObject();
        } finally {
            connection.disconnect();
        }
    }

    private JsonObject source(String title, String database, String pmid, String doi, String url) {
        JsonObject source = new JsonObject();
        source.addProperty("title", title);
        source.addProperty("source", database);
        source.addProperty("pmid", pmid);
        source.addProperty("doi", doi);
        source.addProperty("url", url);
        source.addProperty("provider", "deepseek");
        source.addProperty("retrievedAt", LocalDate.now().toString());
        return source;
    }

    private static String firstArrayString(JsonObject object, String key) {
        if (!object.has(key) || !object.get(key).isJsonArray()
                || object.getAsJsonArray(key).size() == 0) return "";
        JsonElement value = object.getAsJsonArray(key).get(0);
        return value.isJsonPrimitive() ? value.getAsString() : "";
    }

    private static void copy(JsonObject from, JsonObject to, String key) {
        if (from.has(key) && !from.get(key).isJsonNull()) to.add(key, from.get(key).deepCopy());
    }

    private static String string(JsonObject object, String key) {
        return object.has(key) && !object.get(key).isJsonNull() ? object.get(key).getAsString() : "";
    }

    public static final class SearchResult {
        public final String toolJson;
        public final JsonArray sources;

        SearchResult(String toolJson, JsonArray sources) {
            this.toolJson = toolJson;
            this.sources = sources;
        }
    }
}
