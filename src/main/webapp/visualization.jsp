<%@ page contentType="text/html;charset=UTF-8" language="java" %>
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
    <title>Interactive Visualization - scSAID</title>
    <link rel="stylesheet" href="CSS/design-system.css?v=20260624">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/visualization.css?v=20260624">
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
                <a href="browse.jsp" class="main-nav__link main-nav__link--active">Browse</a>
                <a href="gene-search.jsp" class="main-nav__link">Search</a>
                <a href="featureplot.jsp" class="main-nav__link">Expression</a>
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

    <main class="visualization-container">
        <%
            String datasetId = (String) request.getAttribute("datasetId");
            String vizUrl = (String) request.getAttribute("vizUrl");
            Integer vizPort = (Integer) request.getAttribute("vizPort");
        %>

        <!-- Page Header -->
        <section class="viz-page-header">
            <div class="breadcrumb">
                <a href="browse.jsp">Browse</a>
                <span class="separator">›</span>
                <a href="details?said=<%= datasetId %>"><%= datasetId %></a>
                <span class="separator">›</span>
                <span class="current">Interactive Visualization</span>
            </div>

            <h1 class="page-title">Interactive Visualization Suite</h1>
            <p class="page-description">
                Explore dataset <strong><%= datasetId %></strong> with advanced interactive visualizations
            </p>
        </section>

        <!-- Status Banner -->
        <div id="status-banner" class="status-banner">
            <div class="status-content">
                <div class="spinner"></div>
                <span id="status-text">Initializing visualization server...</span>
            </div>
        </div>

        <!-- Visualization Frame Container -->
        <section class="viz-frame-section">
            <div class="viz-toolbar">
                <div class="toolbar-left">
                    <button id="refresh-btn" class="toolbar-btn" title="Refresh">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M23 4v6h-6M1 20v-6h6"/>
                            <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/>
                        </svg>
                        Refresh
                    </button>

                    <button id="fullscreen-btn" class="toolbar-btn" title="Fullscreen">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M8 3H5a2 2 0 00-2 2v3m18 0V5a2 2 0 00-2-2h-3m0 18h3a2 2 0 002-2v-3M3 16v3a2 2 0 002 2h3"/>
                        </svg>
                        Fullscreen
                    </button>
                </div>

                <div class="toolbar-right">
                    <a href="details?said=<%= datasetId %>" class="toolbar-btn">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M19 12H5M12 19l-7-7 7-7"/>
                        </svg>
                        Back to Details
                    </a>
                </div>
            </div>

            <div class="viz-frame-wrapper" id="viz-frame-wrapper">
                <iframe
                    id="viz-frame"
                    src="<%= vizUrl %>"
                    frameborder="0"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowfullscreen>
                </iframe>
            </div>
        </section>

        <!-- Instructions Panel -->
        <section class="instructions-panel">
            <h2>Visualization Tools Available</h2>
            <div class="tools-grid">
                <div class="tool-card">
                    <div class="tool-icon">🌐</div>
                    <h3>3D UMAP</h3>
                    <p>Explore your data in 3D space with interactive rotation and zoom controls</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🧭</div>
                    <h3>3D tSNE</h3>
                    <p>Alternative dimensionality reduction for exploring complex manifolds in 3D</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">⚫</div>
                    <h3>Dot Plot</h3>
                    <p>Visualize gene expression levels and percentage of expressing cells across groups</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🎻</div>
                    <h3>Violin Plot</h3>
                    <p>Display gene expression distributions with box plots and density curves</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🎼</div>
                    <h3>Split Violin</h3>
                    <p>Compare two subgroups within each group using mirrored violin plots</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🧵</div>
                    <h3>Stacked Violin</h3>
                    <p>Stack gene expression distributions for multiple genes in a compact view</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🔥</div>
                    <h3>Heatmap</h3>
                    <p>Show hierarchical clustering and average expression patterns across cell types</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🗺️</div>
                    <h3>Feature Plot</h3>
                    <p>Overlay gene expression on UMAP coordinates to identify spatial patterns</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">📊</div>
                    <h3>Gene Expression</h3>
                    <p>Compare mean expression levels of selected genes across different groups</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🔀</div>
                    <h3>Sankey</h3>
                    <p>Visualize cell type proportions across datasets or metadata categories</p>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">📈</div>
                    <h3>Correlation</h3>
                    <p>Explore pairwise gene expression relationships with interactive scatter plots</p>
                </div>
            </div>
        </section>

        <!-- Tips Section -->
        <section class="tips-section">
            <h2>Tips for Using the Visualization Suite</h2>
            <ul class="tips-list">
                <li><strong>Color by:</strong> Change the coloring scheme to highlight different aspects of your data (cell type, cluster, sample, etc.)</li>
                <li><strong>Gene Selection:</strong> Use the gene dropdown to search and select genes of interest for dot plots, violin plots, and heatmaps</li>
                <li><strong>Point Size & Opacity:</strong> Adjust these settings for better visualization of dense or sparse regions</li>
                <li><strong>Export:</strong> Save your visualizations as PNG or SVG for publications</li>
                <li><strong>3D Navigation:</strong> Click and drag to rotate, scroll to zoom, shift+drag to pan</li>
                <li><strong>Hover Info:</strong> Hover over data points to see detailed information</li>
            </ul>
        </section>
    </main>

    <!-- Footer -->
    <footer class="main-footer">
        <div class="footer-content">
            <p>&copy; 2024 scSAID - Single-Cell Skin & Appendages Integrated Database</p>
            <p>Zhejiang University · ZJE</p>
        </div>
    </footer>

    <script src="lib/jquery-3.7.1.min.js"></script>
    <script>
        $(document).ready(function() {
            const datasetId = '<%= datasetId %>';
            const vizUrl = '<%= vizUrl %>';
            let checkInterval;
            let checkAttempts = 0;
            const maxAttempts = 30;

            // Check server status
            function checkServerStatus() {
                $.ajax({
                    url: 'visualization',
                    type: 'POST',
                    data: { action: 'status', dataset: datasetId },
                    success: function(response) {
                        if (response.running) {
                            $('#status-text').text('Visualization server is running');
                            setTimeout(function() {
                                $('#status-banner').fadeOut();
                            }, 2000);
                            clearInterval(checkInterval);
                        } else {
                            checkAttempts++;
                            if (checkAttempts >= maxAttempts) {
                                $('#status-text').text('Failed to start visualization server. Please refresh the page.');
                                $('#status-banner').addClass('error');
                                clearInterval(checkInterval);
                            }
                        }
                    },
                    error: function() {
                        checkAttempts++;
                        if (checkAttempts >= maxAttempts) {
                            $('#status-text').text('Error checking server status');
                            $('#status-banner').addClass('error');
                            clearInterval(checkInterval);
                        }
                    }
                });
            }

            // Start checking status
            checkInterval = setInterval(checkServerStatus, 1000);
            checkServerStatus();

            // Refresh button
            $('#refresh-btn').on('click', function() {
                $('#viz-frame').attr('src', $('#viz-frame').attr('src'));
            });

            // Fullscreen button
            $('#fullscreen-btn').on('click', function() {
                const elem = document.getElementById('viz-frame-wrapper');
                if (elem.requestFullscreen) {
                    elem.requestFullscreen();
                } else if (elem.webkitRequestFullscreen) {
                    elem.webkitRequestFullscreen();
                } else if (elem.msRequestFullscreen) {
                    elem.msRequestFullscreen();
                }
            });

            // Handle iframe load
            $('#viz-frame').on('load', function() {
                console.log('Visualization loaded');
            });
        });
    </script>


<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
