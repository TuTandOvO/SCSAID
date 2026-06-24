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
    <meta name="theme-color" content="#1a2332">
    <title>Gene: <%= request.getAttribute("geneName") %> - scSAID</title>
    <link rel="stylesheet" href="CSS/design-system.css?v=20260624">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/gene-details.css?v=20260624">
    <link rel="stylesheet" href="CSS/construction-modal-simple.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@300;400;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
</head>
<body>
    <!-- Header -->
    <header class="site-header">
        <div class="container">
            <a href="index.jsp" class="site-logo">scSAID</a>
            <nav class="main-nav">
                <a href="index.jsp" class="main-nav__link">Home</a>
                <a href="browse.jsp" class="main-nav__link">Browse</a>
                <a href="gene-search.jsp" class="main-nav__link main-nav__link--active">Search</a>
                <a href="compare.jsp" class="main-nav__link">Compare</a>
            <a href="download.jsp" class="main-nav__link">Download</a>
                <div class="main-nav__item">
                    <a href="help?topic=faq" class="main-nav__link">Help</a>
                    <div class="main-nav__dropdown">
                        <a href="help?topic=faq" class="main-nav__dropdown-link">FAQ</a>
                        <a href="help?topic=methods" class="main-nav__dropdown-link">Methods</a>
                        <a href="help?topic=markers" class="main-nav__dropdown-link">Markers</a>
                        <a href="help?topic=pipeline" class="main-nav__dropdown-link">Pipeline</a>
                        <a href="help?topic=usage" class="main-nav__dropdown-link">Usage</a>
                    </div>
                </div>
                <a href="feedback" class="main-nav__link">Feedback</a>
            </nav>
            <div class="header-icons">
                <a href="https://github.com/TuTandOvO/SCSAID" target="_blank" class="header-icon-link" title="View on GitHub">
                    <svg class="github-icon" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                    </svg>
                </a>
                <a href="https://zje.zju.edu.cn/zje/main.htm" target="_blank" class="header-icon-link" title="ZJE - Zhejiang University">
                    <img src="images/ZJE_Logo.png" alt="ZJE - Zhejiang University" class="university-logo">
                </a>
            </div>
        </div>
    </header>

    <main class="gene-details-container">
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

    <!-- Under Construction Modal Script -->
    <script src="JS/construction-modal-simple.js"></script>
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
