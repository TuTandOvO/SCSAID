package Servlet;

import Entity.GeneInfo;
import Utils.ExternalAPIClient;
import com.google.gson.Gson;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * Servlet for handling gene details page requests
 * Fetches gene information from external APIs and displays gene details with external links
 */
@WebServlet("/gene-details")
public class GeneDetailsServlet extends HttpServlet {
    private static final Gson GSON = new Gson();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String geneName = normalizeGene(request.getParameter("gene"));
        String species = normalizeSpecies(request.getParameter("species"));
        if (geneName == null || species == null) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "A valid gene and species are required");
            return;
        }

        try {
            // Fetch gene information
            GeneInfo geneInfo = ExternalAPIClient.fetchGeneInfo(geneName, species);

            if (geneInfo == null) {
                geneInfo = new GeneInfo(geneName);
                geneInfo.setDescription("Gene information not available");
            }

            // Generate external links
            Map<String, String> externalLinks = ExternalAPIClient.generateExternalLinks(
                geneName,
                geneInfo.getEnsemblId(),
                species
            );

            // Set attributes for JSP
            request.setAttribute("geneName", geneName);
            request.setAttribute("geneInfo", geneInfo);
            request.setAttribute("externalLinks", externalLinks);
            request.setAttribute("species", species);

            // Forward to JSP
            request.getRequestDispatcher("gene-details.jsp").forward(request, response);

        } catch (Exception e) {
            getServletContext().log("Gene information lookup failed", e);
            response.sendError(HttpServletResponse.SC_BAD_GATEWAY, "Gene information is temporarily unavailable");
        }
    }

    /**
     * API endpoint to get gene info as JSON
     */
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String geneName = normalizeGene(request.getParameter("gene"));
        String species = normalizeSpecies(request.getParameter("species"));
        if (geneName == null || species == null) {
            sendJsonError(response, HttpServletResponse.SC_BAD_REQUEST, "A valid gene and species are required");
            return;
        }

        try {
            // Fetch gene information
            GeneInfo geneInfo = ExternalAPIClient.fetchGeneInfo(geneName, species);
            Map<String, String> externalLinks = ExternalAPIClient.generateExternalLinks(
                geneName,
                geneInfo != null ? geneInfo.getEnsemblId() : null,
                species
            );

            // Create response object
            Map<String, Object> responseData = new HashMap<>();
            responseData.put("geneInfo", geneInfo);
            responseData.put("externalLinks", externalLinks);

            // Convert to JSON
            String json = GSON.toJson(responseData);

            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write(json);

        } catch (Exception e) {
            getServletContext().log("Gene information API lookup failed", e);
            sendJsonError(response, HttpServletResponse.SC_BAD_GATEWAY,
                    "Gene information is temporarily unavailable");
        }
    }

    private static String normalizeGene(String value) {
        if (value == null) return null;
        String gene = value.trim();
        return gene.matches("[A-Za-z0-9._-]{1,64}") ? gene : null;
    }

    private static String normalizeSpecies(String value) {
        if (value == null || value.trim().isEmpty()) return "human";
        String species = value.trim().toLowerCase();
        return "human".equals(species) || "mouse".equals(species) ? species : null;
    }

    private static void sendJsonError(HttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.setHeader("Cache-Control", "no-store");
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        response.getWriter().write(GSON.toJson(error));
    }
}
