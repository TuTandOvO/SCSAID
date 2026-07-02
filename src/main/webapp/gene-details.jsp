<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="Entity.GeneInfo" %>
<%@ page import="java.util.Map" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <!-- Favicons / PWA icons -->
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png">
    <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png">
    <link rel="icon" type="image/png" sizes="512x512" href="/images/favicon-512.png">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png">
    <link rel="manifest" href="/site.webmanifest">
    <meta name="theme-color" content="#333333">
    <title>Gene: <%= request.getAttribute("geneName") %> - scSAID</title>
    <link rel="stylesheet" href="CSS/design-system.css?v=20260702c">
    <link rel="stylesheet" href="CSS/header.css?v=20260702o">
    <link rel="stylesheet" href="CSS/gene-details.css?v=20260701h">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">
</head>
<body>
    <%@ include file="includes/header.jsp" %>

    <main class="gene-details-container" id="main-content" tabindex="-1">
        <%
            String geneName = (String) request.getAttribute("geneName");
            GeneInfo geneInfo = (GeneInfo) request.getAttribute("geneInfo");
            Map<String, String> externalLinks = (Map<String, String>) request.getAttribute("externalLinks");
            String species = (String) request.getAttribute("species");
        %>

        <!-- Gene Header -->
        <section class="gene-header">
            <div class="gene-title-section">
                <h1 class="gene-name"><%= geneName %></h1>
                <span class="species-badge"><%= species.substring(0, 1).toUpperCase() + species.substring(1) %></span>
                <% if (geneInfo.getEnsemblId() != null && !geneInfo.getEnsemblId().isEmpty()) { %>
                    <span class="gene-id"><%= geneInfo.getEnsemblId() %></span>
                <% } %>
            </div>

            <% if (geneInfo.getDescription() != null && !geneInfo.getDescription().isEmpty()) { %>
            <div class="gene-description">
                <p><%= geneInfo.getDescription() %></p>
            </div>
            <% } %>
        </section>

        <!-- External Database Links -->
        <section class="external-links-section">
            <h2>External Database Links</h2>
            <div class="links-grid">
                <% for (Map.Entry<String, String> entry : externalLinks.entrySet()) { %>
                    <a href="<%= entry.getValue() %>" target="_blank" rel="noopener noreferrer" class="link-card">
                        <div class="link-icon">
                            <%= getIconForDatabase(entry.getKey()) %>
                        </div>
                        <div class="link-info">
                            <span class="link-name"><%= entry.getKey() %></span>
                            <span class="link-arrow">→</span>
                        </div>
                    </a>
                <% } %>
            </div>
        </section>

        <!-- Gene Information -->
        <section class="gene-info-section">
            <h2>Gene Information</h2>
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-label">Gene Symbol</div>
                    <div class="info-value"><%= geneName %></div>
                </div>

                <% if (geneInfo.getEnsemblId() != null && !geneInfo.getEnsemblId().isEmpty()) { %>
                <div class="info-card">
                    <div class="info-label">Ensembl ID</div>
                    <div class="info-value"><%= geneInfo.getEnsemblId() %></div>
                </div>
                <% } %>

                <% if (geneInfo.getEntrezId() != null && !geneInfo.getEntrezId().isEmpty()) { %>
                <div class="info-card">
                    <div class="info-label">Entrez Gene ID</div>
                    <div class="info-value"><%= geneInfo.getEntrezId() %></div>
                </div>
                <% } %>

                <% if (geneInfo.getChromosome() != null && !geneInfo.getChromosome().isEmpty()) { %>
                <div class="info-card">
                    <div class="info-label">Chromosome</div>
                    <div class="info-value"><%= geneInfo.getChromosome() %></div>
                </div>
                <% } %>

                <% if (geneInfo.getLocation() != null && !geneInfo.getLocation().isEmpty()) { %>
                <div class="info-card">
                    <div class="info-label">Genomic Location</div>
                    <div class="info-value mono"><%= geneInfo.getLocation() %></div>
                </div>
                <% } %>

                <% if (geneInfo.getBiotype() != null && !geneInfo.getBiotype().isEmpty()) { %>
                <div class="info-card">
                    <div class="info-label">Biotype</div>
                    <div class="info-value"><%= geneInfo.getBiotype() %></div>
                </div>
                <% } %>

                <% if (geneInfo.getStrand() != null && !geneInfo.getStrand().isEmpty()) { %>
                <div class="info-card">
                    <div class="info-label">Strand</div>
                    <div class="info-value"><%= geneInfo.getStrand() %></div>
                </div>
                <% } %>

                <div class="info-card">
                    <div class="info-label">Species</div>
                    <div class="info-value"><%= species.substring(0, 1).toUpperCase() + species.substring(1) %></div>
                </div>
            </div>
        </section>

        <!-- Expression Across Datasets -->
        <section class="expression-section">
            <h2>Expression Across scSAID Datasets</h2>
            <div class="expression-info">
                <p>Search for <strong><%= geneName %></strong> expression across all datasets in the scSAID database.</p>
                <a href="gene-search.jsp?gene=<%= geneName %>" class="btn-primary">Search Expression in scSAID</a>
            </div>
        </section>

        <!-- Quick Actions -->
        <section class="quick-actions">
            <h2>Quick Actions</h2>
            <div class="actions-grid">
                <button onclick="copyGeneSymbol()" class="action-btn">
                    <span class="action-icon">📋</span>
                    <span>Copy Gene Symbol</span>
                </button>
                <button onclick="shareGene()" class="action-btn">
                    <span class="action-icon">🔗</span>
                    <span>Share Link</span>
                </button>
                <button onclick="window.print()" class="action-btn">
                    <span class="action-icon">🖨️</span>
                    <span>Print</span>
                </button>
            </div>
        </section>
    </main>

    <!-- Footer -->
    <footer class="main-footer">
        <div class="footer-content">
            <p>&copy; 2024 scSAID - Single-Cell Skin & Appendages Integrated Database</p>
            <p>Zhejiang University · ZJE</p>
        </div>
    </footer>

    <script>
        function copyGeneSymbol() {
            const geneName = '<%= geneName %>';
            navigator.clipboard.writeText(geneName).then(() => {
                alert('Gene symbol copied: ' + geneName);
            });
        }

        function shareGene() {
            const url = window.location.href;
            navigator.clipboard.writeText(url).then(() => {
                alert('Link copied to clipboard!');
            });
        }
    </script>


<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>

<%!
    private String getIconForDatabase(String dbName) {
        switch (dbName) {
            case "NCBI Gene":
                return "🧬";
            case "GeneCards":
                return "📇";
            case "Ensembl":
                return "🔬";
            case "Protein Atlas":
                return "🔭";
            case "GTEx Portal":
                return "📊";
            case "UniProt":
                return "🧪";
            case "STRING":
                return "🕸️";
            case "KEGG":
                return "🗺️";
            case "Reactome":
                return "⚡";
            case "PubMed":
                return "📚";
            default:
                return "🔗";
        }
    }
%>
