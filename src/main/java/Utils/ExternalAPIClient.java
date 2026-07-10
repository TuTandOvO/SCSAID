package Utils;

import Entity.GeneInfo;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Utility class for fetching gene information from external APIs
 * Implements caching to reduce API calls
 */
public class ExternalAPIClient {
    private static final String CACHE_DIR = "gene_cache";
    private static final int CACHE_TTL_DAYS = 7;
    private static final String ENSEMBL_BASE_URL = "https://rest.ensembl.org";
    private static final String MYGENE_BASE_URL = "https://mygene.info/v3";

    static {
        // Create cache directory if it doesn't exist
        try {
            Path cachePath = Paths.get(CACHE_DIR);
            if (!Files.exists(cachePath)) {
                Files.createDirectories(cachePath);
            }
        } catch (IOException e) {
            System.err.println("Failed to create cache directory: " + e.getMessage());
        }
    }

    /**
     * Restrict cache-key components to a safe character set so a crafted gene
     * name (e.g. containing "/" or "..") cannot escape the cache directory.
     */
    private static String sanitizeKey(String value) {
        if (value == null) {
            return "unknown";
        }
        String cleaned = value.replaceAll("[^A-Za-z0-9_.-]", "_");
        if (cleaned.isEmpty()) {
            return "unknown";
        }
        return cleaned.length() > 64 ? cleaned.substring(0, 64) : cleaned;
    }

    /**
     * Fetch gene information with caching
     */
    public static GeneInfo fetchGeneInfo(String geneName, String species) {
        // Check cache first
        GeneInfo cached = getCachedGeneInfo(geneName, species);
        if (cached != null) {
            return cached;
        }

        // Fetch from API
        GeneInfo geneInfo = fetchFromAPI(geneName, species);

        // Cache the result
        if (geneInfo != null) {
            cacheGeneInfo(geneName, species, geneInfo);
        }

        return geneInfo;
    }

    /**
     * Fetch gene information from Ensembl REST API
     */
    private static GeneInfo fetchFromAPI(String geneName, String species) {
        try {
            // Convert species name
            String speciesParam = species.equalsIgnoreCase("mouse") ? "mus_musculus" : "homo_sapiens";

            // URL encode gene name
            String encodedGene = URLEncoder.encode(geneName, StandardCharsets.UTF_8.toString());
            String urlString = ENSEMBL_BASE_URL + "/lookup/symbol/" + speciesParam + "/" + encodedGene;

            URL url = new URL(urlString);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(5000);

            int responseCode = conn.getResponseCode();
            if (responseCode == 200) {
                BufferedReader in = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                StringBuilder response = new StringBuilder();
                String line;
                while ((line = in.readLine()) != null) {
                    response.append(line);
                }
                in.close();

                return parseEnsemblResponse(response.toString(), geneName);
            } else if (responseCode == 404) {
                // Gene not found in Ensembl, try MyGene.info
                return fetchFromMyGene(geneName, species);
            }
        } catch (Exception e) {
            System.err.println("Error fetching gene info from Ensembl: " + e.getMessage());
            // Fallback to MyGene.info
            return fetchFromMyGene(geneName, species);
        }

        return createBasicGeneInfo(geneName);
    }

    /**
     * Fallback to MyGene.info API
     */
    private static GeneInfo fetchFromMyGene(String geneName, String species) {
        try {
            String speciesParam = species.equalsIgnoreCase("mouse") ? "mouse" : "human";
            String encodedGene = URLEncoder.encode(geneName, StandardCharsets.UTF_8.toString());
            String urlString = MYGENE_BASE_URL + "/query?q=symbol:" + encodedGene +
                              "&species=" + speciesParam + "&fields=ensembl,entrezgene,summary,genomic_pos";

            URL url = new URL(urlString);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(5000);

            int responseCode = conn.getResponseCode();
            if (responseCode == 200) {
                BufferedReader in = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                StringBuilder response = new StringBuilder();
                String line;
                while ((line = in.readLine()) != null) {
                    response.append(line);
                }
                in.close();

                return parseMyGeneResponse(response.toString(), geneName);
            }
        } catch (Exception e) {
            System.err.println("Error fetching gene info from MyGene: " + e.getMessage());
        }

        return createBasicGeneInfo(geneName);
    }

    /**
     * Parse Ensembl API response
     */
    private static GeneInfo parseEnsemblResponse(String jsonResponse, String geneName) {
        try {
            JsonObject json = JsonParser.parseString(jsonResponse).getAsJsonObject();

            GeneInfo info = new GeneInfo(geneName);

            if (json.has("id")) {
                info.setEnsemblId(json.get("id").getAsString());
            }

            if (json.has("description")) {
                info.setDescription(json.get("description").getAsString());
            }

            if (json.has("seq_region_name")) {
                info.setChromosome(json.get("seq_region_name").getAsString());
            }

            if (json.has("start") && json.has("end")) {
                long start = json.get("start").getAsLong();
                long end = json.get("end").getAsLong();
                info.setStart(start);
                info.setEnd(end);
                info.setLocation(info.getChromosome() + ":" + start + "-" + end);
            }

            if (json.has("biotype")) {
                info.setBiotype(json.get("biotype").getAsString());
            }

            if (json.has("strand")) {
                int strand = json.get("strand").getAsInt();
                info.setStrand(strand == 1 ? "+" : "-");
            }

            return info;
        } catch (Exception e) {
            System.err.println("Error parsing Ensembl response: " + e.getMessage());
            return createBasicGeneInfo(geneName);
        }
    }

    /**
     * Parse MyGene.info API response
     */
    private static GeneInfo parseMyGeneResponse(String jsonResponse, String geneName) {
        try {
            JsonObject json = JsonParser.parseString(jsonResponse).getAsJsonObject();

            if (!json.has("hits") || json.get("hits").getAsJsonArray().size() == 0) {
                return createBasicGeneInfo(geneName);
            }

            JsonObject hit = json.get("hits").getAsJsonArray().get(0).getAsJsonObject();
            GeneInfo info = new GeneInfo(geneName);

            if (hit.has("ensembl")) {
                JsonObject ensembl = hit.get("ensembl").getAsJsonObject();
                if (ensembl.has("gene")) {
                    info.setEnsemblId(ensembl.get("gene").getAsString());
                }
            }

            if (hit.has("entrezgene")) {
                info.setEntrezId(hit.get("entrezgene").getAsString());
            }

            if (hit.has("summary")) {
                info.setDescription(hit.get("summary").getAsString());
            }

            if (hit.has("genomic_pos")) {
                JsonObject pos = hit.get("genomic_pos").getAsJsonObject();
                if (pos.has("chr")) {
                    info.setChromosome(pos.get("chr").getAsString());
                }
                if (pos.has("start") && pos.has("end")) {
                    long start = pos.get("start").getAsLong();
                    long end = pos.get("end").getAsLong();
                    info.setStart(start);
                    info.setEnd(end);
                    info.setLocation(info.getChromosome() + ":" + start + "-" + end);
                }
            }

            return info;
        } catch (Exception e) {
            System.err.println("Error parsing MyGene response: " + e.getMessage());
            return createBasicGeneInfo(geneName);
        }
    }

    /**
     * Create basic gene info when API calls fail
     */
    private static GeneInfo createBasicGeneInfo(String geneName) {
        GeneInfo info = new GeneInfo(geneName);
        info.setDescription("Information not available");
        return info;
    }

    /**
     * Generate external database links
     */
    public static Map<String, String> generateExternalLinks(String geneName, String ensemblId) {
        return generateExternalLinks(geneName, ensemblId, "human");
    }

    public static Map<String, String> generateExternalLinks(String geneName, String ensemblId, String species) {
        Map<String, String> links = new LinkedHashMap<>();

        try {
            String encodedGene = URLEncoder.encode(geneName, StandardCharsets.UTF_8.toString()).replace("+", "%20");
            String encodedEnsembl = ensemblId != null
                    ? URLEncoder.encode(ensemblId, StandardCharsets.UTF_8.toString()).replace("+", "%20")
                    : "";
            boolean mouse = species != null && species.equalsIgnoreCase("mouse");
            String ensemblSpecies = mouse ? "Mus_musculus" : "Homo_sapiens";
            String stringSpecies = mouse ? "10090" : "9606";

            links.put("NCBI Gene", "https://www.ncbi.nlm.nih.gov/gene/?term=" + encodedGene);
            if (mouse) {
                links.put("MGI", "https://www.informatics.jax.org/searchtool/Search.do?query=" + encodedGene);
            } else {
                links.put("HGNC", "https://www.genenames.org/tools/search/#!/?query=" + encodedGene);
                links.put("GeneCards", "https://www.genecards.org/cgi-bin/carddisp.pl?gene=" + encodedGene);
            }
            links.put("Ensembl", ensemblId != null && !ensemblId.isEmpty() ?
                     "https://www.ensembl.org/" + ensemblSpecies + "/Gene/Summary?g=" + encodedEnsembl :
                     "https://www.ensembl.org/Multi/Search/Results?q=" + encodedGene);
            links.put("Protein Atlas", "https://www.proteinatlas.org/search/" + encodedGene);
            links.put("GTEx Portal", "https://gtexportal.org/home/gene/" + encodedGene);
            links.put("UniProt", "https://www.uniprot.org/uniprot/?query=" + encodedGene);
            links.put("STRING", "https://string-db.org/cgi/network?identifier=" + encodedGene + "&species=" + stringSpecies);
            links.put("KEGG", "https://www.genome.jp/dbget-bin/www_bfind_sub?mode=bfind&max_hit=1000&dbkey=genes&keywords=" + encodedGene);
            links.put("Reactome", "https://reactome.org/content/query?q=" + encodedGene);
            links.put("PubMed", "https://pubmed.ncbi.nlm.nih.gov/?term=" + encodedGene);
        } catch (Exception e) {
            System.err.println("Error generating links: " + e.getMessage());
        }

        return links;
    }

    /**
     * Get cached gene info if available and not expired
     */
    private static GeneInfo getCachedGeneInfo(String geneName, String species) {
        try {
            String cacheKey = sanitizeKey(geneName) + "_" + sanitizeKey(species);
            Path cacheFile = Paths.get(CACHE_DIR, cacheKey + ".cache");
            Path timestampFile = Paths.get(CACHE_DIR, cacheKey + ".timestamp");

            if (Files.exists(cacheFile) && Files.exists(timestampFile)) {
                // Check if cache is expired
                String timestamp = new String(Files.readAllBytes(timestampFile));
                LocalDateTime cachedTime = LocalDateTime.parse(timestamp);
                long daysSinceCached = ChronoUnit.DAYS.between(cachedTime, LocalDateTime.now());

                if (daysSinceCached < CACHE_TTL_DAYS) {
                    // Read cached data
                    String json = new String(Files.readAllBytes(cacheFile));
                    return parseEnsemblResponse(json, geneName);
                }
            }
        } catch (Exception e) {
            System.err.println("Error reading cache: " + e.getMessage());
        }

        return null;
    }

    /**
     * Cache gene info to file
     */
    private static void cacheGeneInfo(String geneName, String species, GeneInfo geneInfo) {
        try {
            String cacheKey = sanitizeKey(geneName) + "_" + sanitizeKey(species);
            Path cacheFile = Paths.get(CACHE_DIR, cacheKey + ".cache");
            Path timestampFile = Paths.get(CACHE_DIR, cacheKey + ".timestamp");

            // Convert GeneInfo to JSON
            JsonObject json = new JsonObject();
            json.addProperty("id", geneInfo.getEnsemblId());
            json.addProperty("description", geneInfo.getDescription());
            json.addProperty("seq_region_name", geneInfo.getChromosome());
            json.addProperty("start", geneInfo.getStart());
            json.addProperty("end", geneInfo.getEnd());
            json.addProperty("biotype", geneInfo.getBiotype());

            Files.write(cacheFile, json.toString().getBytes());
            Files.write(timestampFile, LocalDateTime.now().toString().getBytes());
        } catch (Exception e) {
            System.err.println("Error writing cache: " + e.getMessage());
        }
    }
}
