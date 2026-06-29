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
    <title>Page Not Found — scSAID</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/404.css">
</head>
<body>

<div class="error-page">

    <!-- Header -->
    <header class="site-header">
        <div class="container">
            <a href="index.jsp" class="site-logo">scSAID</a>

            <nav class="main-nav">
                <a href="index.jsp" class="main-nav__link">Home</a>
                <a href="browse.jsp" class="main-nav__link">Browse</a>
                <a href="gene-search.jsp" class="main-nav__link">Search</a>
                <a href="featureplot.jsp" class="main-nav__link">Feature Plot</a>
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

    <!-- Main Content -->
    <main class="error-page__body" role="main">
        <div class="error-page__inner">

            <!-- Illustration: Abstract UMAP scatter with a "lost" cell -->
            <div class="error-illustration" aria-hidden="true">
                <svg class="error-illustration__svg" viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg">

                    <!-- Background grid -->
                    <line class="scatter-grid" x1="40" y1="40" x2="40" y2="360"/>
                    <line class="scatter-grid" x1="40" y1="360" x2="360" y2="360"/>
                    <line class="scatter-grid" x1="100" y1="355" x2="100" y2="365"/>
                    <line class="scatter-grid" x1="160" y1="355" x2="160" y2="365"/>
                    <line class="scatter-grid" x1="220" y1="355" x2="220" y2="365"/>
                    <line class="scatter-grid" x1="280" y1="355" x2="280" y2="365"/>
                    <line class="scatter-grid" x1="340" y1="355" x2="340" y2="365"/>
                    <line class="scatter-grid" x1="35" y1="300" x2="45" y2="300"/>
                    <line class="scatter-grid" x1="35" y1="240" x2="45" y2="240"/>
                    <line class="scatter-grid" x1="35" y1="180" x2="45" y2="180"/>
                    <line class="scatter-grid" x1="35" y1="120" x2="45" y2="120"/>
                    <line class="scatter-grid" x1="35" y1="60" x2="45" y2="60"/>

                    <!-- Axis labels -->
                    <text class="axis-label" x="190" y="392" text-anchor="middle">UMAP 1</text>
                    <text class="axis-label" x="16" y="200" text-anchor="middle" transform="rotate(-90 16 200)">UMAP 2</text>

                    <!-- Main cell cluster (dense group, lower-right area) -->
                    <!-- Large cells -->
                    <circle class="cell-cluster" cx="210" cy="230" r="8"/>
                    <circle class="cell-cluster" cx="235" cy="245" r="7"/>
                    <circle class="cell-cluster--deep" cx="220" cy="260" r="9"/>
                    <circle class="cell-cluster" cx="250" cy="225" r="6"/>
                    <circle class="cell-cluster--muted" cx="195" cy="250" r="7"/>
                    <circle class="cell-cluster" cx="240" cy="270" r="8"/>
                    <circle class="cell-cluster--deep" cx="260" cy="255" r="6"/>
                    <circle class="cell-cluster--muted" cx="225" cy="210" r="5"/>
                    <circle class="cell-cluster" cx="270" cy="240" r="7"/>
                    <circle class="cell-cluster--muted" cx="200" cy="270" r="6"/>

                    <!-- Medium cells -->
                    <circle class="cell-cluster" cx="215" cy="285" r="5"/>
                    <circle class="cell-cluster--deep" cx="255" cy="210" r="5"/>
                    <circle class="cell-cluster--muted" cx="230" cy="290" r="4"/>
                    <circle class="cell-cluster" cx="280" cy="260" r="5"/>
                    <circle class="cell-cluster--muted" cx="190" cy="235" r="4"/>
                    <circle class="cell-cluster--deep" cx="265" cy="280" r="4"/>
                    <circle class="cell-cluster" cx="245" cy="200" r="4"/>
                    <circle class="cell-cluster--muted" cx="285" cy="230" r="4"/>

                    <!-- Small scatter cells -->
                    <circle class="cell-cluster" cx="178" cy="260" r="3"/>
                    <circle class="cell-cluster--muted" cx="290" cy="275" r="3"/>
                    <circle class="cell-cluster--deep" cx="205" cy="295" r="3"/>
                    <circle class="cell-cluster" cx="275" cy="215" r="3"/>
                    <circle class="cell-cluster--muted" cx="250" cy="305" r="3"/>
                    <circle class="cell-cluster--deep" cx="295" cy="250" r="3"/>
                    <circle class="cell-cluster" cx="185" cy="215" r="3"/>
                    <circle class="cell-cluster--muted" cx="300" cy="265" r="2.5"/>
                    <circle class="cell-cluster--deep" cx="170" cy="245" r="2.5"/>
                    <circle class="cell-cluster" cx="260" cy="195" r="2.5"/>

                    <!-- Secondary smaller cluster (upper area) -->
                    <circle class="cell-cluster--muted" cx="160" cy="160" r="5"/>
                    <circle class="cell-cluster" cx="175" cy="150" r="4"/>
                    <circle class="cell-cluster--deep" cx="150" cy="145" r="4"/>
                    <circle class="cell-cluster--muted" cx="168" cy="172" r="3"/>
                    <circle class="cell-cluster" cx="140" cy="158" r="3"/>
                    <circle class="cell-cluster--deep" cx="182" cy="165" r="3"/>
                    <circle class="cell-cluster--muted" cx="155" cy="135" r="2.5"/>
                    <circle class="cell-cluster" cx="145" cy="170" r="2.5"/>

                    <!-- Sparse outlier cells (scattered) -->
                    <circle class="cell-cluster--muted" cx="120" cy="200" r="3"/>
                    <circle class="cell-cluster" cx="310" cy="180" r="3"/>
                    <circle class="cell-cluster--muted" cx="130" cy="300" r="2.5"/>
                    <circle class="cell-cluster--deep" cx="320" cy="310" r="2.5"/>
                    <circle class="cell-cluster--muted" cx="110" cy="130" r="2"/>
                    <circle class="cell-cluster" cx="330" cy="150" r="2"/>

                    <!-- Dashed trail from cluster toward the lost cell -->
                    <path class="connection-line" d="M210 230 C180 180, 130 120, 90 75"/>

                    <!-- THE LOST CELL — isolated, top-left -->
                    <circle class="cell-lost-ring" cx="80" cy="68" r="18"/>
                    <circle class="cell-lost" cx="80" cy="68" r="10"/>

                    <!-- Annotation pointing to the lost cell -->
                    <line class="annotation-line" x1="105" y1="55" x2="145" y2="42"/>
                    <text class="annotation-text" x="148" y="38">PAGE NOT FOUND</text>
                    <text class="annotation-text" x="148" y="52" style="font-weight: 400; font-size: 9px;">This cell has left the cluster</text>

                </svg>
            </div>

            <!-- Text Content -->
            <div class="error-content">
                <span class="error-content__eyebrow">Error 404</span>
                <div class="error-content__code">404</div>
                <hr class="error-content__rule">
                <h1 class="error-content__title">This page could not be found</h1>
                <p class="error-content__description">
                    The page you are looking for may have been moved, removed, or
                    never existed in our database. Like a cell outside the cluster,
                    this URL does not map to any known location in scSAID.
                </p>

                <!-- Navigation Options -->
                <nav class="error-nav" aria-label="Suggested pages">
                    <a href="browse.jsp" class="error-nav__link">
                        <div class="error-nav__icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <rect x="3" y="3" width="7" height="7"></rect>
                                <rect x="14" y="3" width="7" height="7"></rect>
                                <rect x="14" y="14" width="7" height="7"></rect>
                                <rect x="3" y="14" width="7" height="7"></rect>
                            </svg>
                        </div>
                        <div class="error-nav__text">
                            <span class="error-nav__label">Browse</span>
                            <span class="error-nav__hint">Explore all datasets</span>
                        </div>
                    </a>
                    <a href="gene-search.jsp" class="error-nav__link">
                        <div class="error-nav__icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <circle cx="11" cy="11" r="8"></circle>
                                <path d="m21 21-4.3-4.3"></path>
                            </svg>
                        </div>
                        <div class="error-nav__text">
                            <span class="error-nav__label">Search</span>
                            <span class="error-nav__hint">Find specific data</span>
                        </div>
                    </a>
                    <a href="gene-search.jsp" class="error-nav__link">
                        <div class="error-nav__icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"></path>
                                <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"></path>
                            </svg>
                        </div>
                        <div class="error-nav__text">
                            <span class="error-nav__label">Gene Search</span>
                            <span class="error-nav__hint">Look up genes</span>
                        </div>
                    </a>
                    <a href="download.jsp" class="error-nav__link">
                        <div class="error-nav__icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                                <polyline points="7,10 12,15 17,10"></polyline>
                                <line x1="12" y1="15" x2="12" y2="3"></line>
                            </svg>
                        </div>
                        <div class="error-nav__text">
                            <span class="error-nav__label">Download</span>
                            <span class="error-nav__hint">Get the data</span>
                        </div>
                    </a>
                </nav>

                <div class="error-home-btn">
                    <a href="index.jsp" class="btn btn--primary">Return to Homepage</a>
                </div>
            </div>

        </div>
    </main>

    <!-- Footer -->
    <footer class="error-footer">
        <div class="container">
            <div class="error-footer__logo">scSAID</div>
            <p class="error-footer__text">Single-Cell Skin & Appendages Integrated Database</p>
        </div>
    </footer>

</div>

</body>
</html>
