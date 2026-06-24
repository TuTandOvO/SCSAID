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

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String geneName = request.getParameter("gene");
        String species = request.getParameter("species");

        // Default to human if not specified
        if (species == null || species.isEmpty()) {
            species = "human";
        }

        if (geneName == null || geneName.isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Gene name is required");
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
                geneInfo.getEnsemblId()
            );

            // Set attributes for JSP
            request.setAttribute("geneName", geneName);
            request.setAttribute("geneInfo", geneInfo);
            request.setAttribute("externalLinks", externalLinks);
            request.setAttribute("species", species);

            // Forward to JSP
            request.getRequestDispatcher("gene-details.jsp").forward(request, response);

        } catch (Exception e) {
            e.printStackTrace();
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                             "Error fetching gene information: " + e.getMessage());
        }
    }

    /**
     * API endpoint to get gene info as JSON
     */
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String geneName = request.getParameter("gene");
        String species = request.getParameter("species");

        if (species == null || species.isEmpty()) {
            species = "human";
        }

        if (geneName == null || geneName.isEmpty()) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            response.getWriter().write("{\"error\": \"Gene name is required\"}");
            return;
        }

        try {
            // Fetch gene information
            GeneInfo geneInfo = ExternalAPIClient.fetchGeneInfo(geneName, species);
            Map<String, String> externalLinks = ExternalAPIClient.generateExternalLinks(
                geneName,
                geneInfo != null ? geneInfo.getEnsemblId() : null
            );

            // Create response object
            Map<String, Object> responseData = new HashMap<>();
            responseData.put("geneInfo", geneInfo);
            responseData.put("externalLinks", externalLinks);

            // Convert to JSON
            Gson gson = new Gson();
            String json = gson.toJson(responseData);

            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write(json);

        } catch (Exception e) {
            e.printStackTrace();
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            response.getWriter().write("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
