<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <!-- Favicons / PWA icons -->
    <link rel="icon" type="image/x-icon" href="/favicon.ico?v=20260703a">
    <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png?v=20260703a">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png?v=20260703a">
    <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png?v=20260703a">
    <link rel="icon" type="image/png" sizes="512x512" href="/images/favicon-512.png?v=20260703a">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png?v=20260703a">
    <link rel="manifest" href="/site.webmanifest?v=20260703a">
    <meta name="theme-color" content="#333333">
    <title>Interactive Visualization - scSAID</title>
    <link rel="stylesheet" href="CSS/design-system.css?v=20260703q">
    <link rel="stylesheet" href="CSS/header.css?v=20260704b">
    <link rel="stylesheet" href="CSS/visualization.css?v=20260701h">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">
</head>
<body>
    <%@ include file="includes/header.jsp" %>

    <main class="visualization-container" id="main-content" tabindex="-1">
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

            <h1 class="page-title title-with-help">
                <button type="button" class="analysis-help" aria-label="About the visualization suite" aria-describedby="help-visualization-suite" aria-expanded="false" data-help-target="help-visualization-suite">Interactive Visualization Suite</button>
            </h1>
            <span id="help-visualization-suite" class="visually-hidden">Interactive dimensionality-reduction, expression, distribution, relationship, and composition views for dataset <%= datasetId %>.</span>
        </section>

        <!-- Status Banner -->
        <div id="status-banner" class="status-banner is-loading">
            <div class="status-content">
                <div class="spinner" aria-hidden="true"></div>
                <span id="status-text"></span>
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
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About 3D UMAP" aria-describedby="help-viz-umap3d" aria-expanded="false" data-help-target="help-viz-umap3d">3D UMAP</button></h3>
                    <span id="help-viz-umap3d" class="visually-hidden">Three-dimensional UMAP embedding with interactive rotation and zoom.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🧭</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About 3D tSNE" aria-describedby="help-viz-tsne3d" aria-expanded="false" data-help-target="help-viz-tsne3d">3D tSNE</button></h3>
                    <span id="help-viz-tsne3d" class="visually-hidden">Three-dimensional t-SNE embedding for nonlinear structure.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">⚫</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About dot plots" aria-describedby="help-viz-dotplot" aria-expanded="false" data-help-target="help-viz-dotplot">Dot Plot</button></h3>
                    <span id="help-viz-dotplot" class="visually-hidden">Gene-expression magnitude and fraction of expressing cells across groups.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🎻</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About violin plots" aria-describedby="help-viz-violin" aria-expanded="false" data-help-target="help-viz-violin">Violin Plot</button></h3>
                    <span id="help-viz-violin" class="visually-hidden">Gene-expression distributions with density and box summaries.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🎼</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About split violin plots" aria-describedby="help-viz-split-violin" aria-expanded="false" data-help-target="help-viz-split-violin">Split Violin</button></h3>
                    <span id="help-viz-split-violin" class="visually-hidden">Mirrored expression distributions for two subgroups within each group.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🧵</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About stacked violin plots" aria-describedby="help-viz-stacked-violin" aria-expanded="false" data-help-target="help-viz-stacked-violin">Stacked Violin</button></h3>
                    <span id="help-viz-stacked-violin" class="visually-hidden">Compact stacked expression distributions for multiple genes.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🔥</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About expression heatmaps" aria-describedby="help-viz-heatmap" aria-expanded="false" data-help-target="help-viz-heatmap">Heatmap</button></h3>
                    <span id="help-viz-heatmap" class="visually-hidden">Hierarchical clustering and average expression patterns across cell types.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🗺️</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About feature plots" aria-describedby="help-viz-feature" aria-expanded="false" data-help-target="help-viz-feature">Feature Plot</button></h3>
                    <span id="help-viz-feature" class="visually-hidden">Gene-expression intensity overlaid on UMAP coordinates.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">📊</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About gene-expression comparisons" aria-describedby="help-viz-expression" aria-expanded="false" data-help-target="help-viz-expression">Gene Expression</button></h3>
                    <span id="help-viz-expression" class="visually-hidden">Mean expression of selected genes compared across groups.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">🔀</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About Sankey plots" aria-describedby="help-viz-sankey" aria-expanded="false" data-help-target="help-viz-sankey">Sankey</button></h3>
                    <span id="help-viz-sankey" class="visually-hidden">Cell-type proportions and flows across datasets or metadata categories.</span>
                </div>

                <div class="tool-card">
                    <div class="tool-icon">📈</div>
                    <h3 class="title-with-help"><button type="button" class="analysis-help" aria-label="About correlation plots" aria-describedby="help-viz-correlation" aria-expanded="false" data-help-target="help-viz-correlation">Correlation</button></h3>
                    <span id="help-viz-correlation" class="visually-hidden">Pairwise gene-expression relationships in an interactive scatter plot.</span>
                </div>
            </div>
        </section>

        <!-- Tips Section -->
        <section class="tips-section">
            <h2 class="title-with-help">
                <button type="button" class="analysis-help" aria-label="About visualization controls" aria-describedby="help-viz-controls" aria-expanded="false" data-help-target="help-viz-controls">Visualization controls</button>
            </h2>
            <ul class="tips-list visually-hidden" id="help-viz-controls">
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
                            setTimeout(function() {
                                $('#status-banner').fadeOut();
                            }, 2000);
                            clearInterval(checkInterval);
                        } else {
                            checkAttempts++;
                            if (checkAttempts >= maxAttempts) {
                                $('#status-banner').removeClass('is-loading').find('.spinner').remove();
                                $('#status-text').text('Failed to start visualization server. Please refresh the page.');
                                $('#status-banner').addClass('error');
                                clearInterval(checkInterval);
                            }
                        }
                    },
                    error: function() {
                        checkAttempts++;
                        if (checkAttempts >= maxAttempts) {
                            $('#status-banner').removeClass('is-loading').find('.spinner').remove();
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
