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
    <title>scSAID — Single-Cell Skin & Appendages Integrated Database</title>

    <!-- SEO: descriptive meta tags -->
    <meta name="description" content="scSAID: a curated database of 252 single-cell RNA-seq datasets covering human and mouse skin and appendages (1.2M+ cells). Browse integrated UMAP atlases, per-dataset differential expression, cell-cell communication (CellPhoneDB), gene set scoring, pathway enrichment, and gene feature plots across the full atlas.">
    <meta name="keywords" content="scSAID, SkinDB, single-cell RNA-seq, scRNA-seq database, skin atlas, integrated cell atlas, keratinocyte atlas, hair follicle, dermatology bioinformatics, mouse skin, human skin, CellPhoneDB, cell-cell communication, psoriasis, atopic dermatitis, skin scRNAseq, skin sc-RNAseq">
    <meta name="author" content="ZJU-UoE Joint Institute, Zhejiang University">
    <meta name="robots" content="index,follow,max-image-preview:large">
    <link rel="canonical" href="https://skin-scsaid.com/">

    <!-- Open Graph (LinkedIn, Twitter link preview, WeChat preview) -->
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="scSAID">
    <meta property="og:title" content="scSAID — Single-Cell Skin & Appendages Integrated Database">
    <meta property="og:description" content="Integrated scRNA-seq atlas of human and mouse skin with 1.2M+ cells across 252 curated datasets.">
    <meta property="og:url" content="https://skin-scsaid.com/">
    <meta property="og:image" content="https://skin-scsaid.com/images/og-preview.png">
    <meta property="og:locale" content="en_US">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="scSAID — Single-Cell Skin Atlas Database">
    <meta name="twitter:description" content="Integrated scRNA-seq atlas of human and mouse skin (1.2M+ cells, 252 datasets).">
    <meta name="twitter:image" content="https://skin-scsaid.com/images/og-preview.png">

    <!-- JSON-LD Dataset schema for Google Dataset Search indexing -->
    <script type="application/ld+json">
    {
      "@context": "https://schema.org/",
      "@type": "Dataset",
      "name": "scSAID — Single-Cell Skin & Appendages Integrated Database",
      "alternateName": ["scSAID", "SkinDB", "skin single-cell atlas"],
      "description": "A curated resource of 252 single-cell RNA-seq datasets covering human and mouse skin and appendages (1.2M+ cells). Provides integrated UMAP atlases, per-dataset differentially expressed genes, cell-cell communication analysis (CellPhoneDB), gene set scoring (AUCell / ssGSEA / GSVA / UCell / scanpy), pathway enrichment, and interactive gene expression feature plots.",
      "url": "https://skin-scsaid.com/",
      "identifier": "https://skin-scsaid.com/",
      "keywords": [
        "single-cell RNA-seq",
        "scRNA-seq",
        "skin atlas",
        "skin scRNA-seq",
        "keratinocyte",
        "hair follicle",
        "dermatology",
        "mouse skin",
        "human skin",
        "CellPhoneDB",
        "cell-cell communication",
        "gene expression atlas",
        "scSAID",
        "SkinDB",
        "integrated atlas"
      ],
      "sameAs": ["https://github.com/TuTandOvO/SCSAID"],
      "license": "https://creativecommons.org/licenses/by/4.0/",
      "isAccessibleForFree": true,
      "creator": {
        "@type": "Organization",
        "name": "ZJU–UoE Joint Institute, Zhejiang University",
        "url": "https://zje.zju.edu.cn/"
      },
      "publisher": {
        "@type": "Organization",
        "name": "Zhejiang University–University of Edinburgh Joint Institute",
        "url": "https://zje.zju.edu.cn/"
      },
      "includedInDataCatalog": {
        "@type": "DataCatalog",
        "name": "scSAID"
      },
      "measurementTechnique": [
        "single-cell RNA sequencing",
        "scRNA-seq",
        "10x Genomics Chromium",
        "Smart-seq2"
      ],
      "variableMeasured": [
        "gene expression",
        "cell type annotation",
        "cell-cell ligand-receptor interactions",
        "differential expression",
        "pathway enrichment scores"
      ],
      "temporalCoverage": "2018/..",
      "spatialCoverage": {
        "@type": "Place",
        "name": "Human and mouse skin and appendages"
      }
    }
    </script>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css">
    <link rel="stylesheet" href="CSS/header.css">

    <!-- Under Construction Modal -->
    <link rel="stylesheet" href="CSS/construction-modal-simple.css">

    <!-- Composition Charts -->
    <link rel="stylesheet" href="CSS/composition-charts.css">

    <!-- ECharts -->
    <script src="https://cdn.jsdelivr.net/npm/echarts@5.5.1/dist/echarts.min.js"></script>

    <style>
        /* ==========================================================================
           Homepage Specific Styles
           ========================================================================== */

        /* Header styles are shared globally in CSS/header.css */

        /* Hero Section */
        .hero {
            position: relative;
            min-height: 85vh;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            background: var(--bg-dark);
            margin-top: var(--header-height);
        }

        .hero__background {
            position: absolute;
            inset: 0;
            z-index: 0;
        }

        .hero__background img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            opacity: 0.35;
        }

        .hero__overlay {
            position: absolute;
            inset: 0;
            background: var(--bg-dark);
            opacity: 0.6;
        }

        .hero__content {
            position: relative;
            z-index: 1;
            text-align: center;
            max-width: 900px;
            padding: var(--space-xl);
        }

        .hero__eyebrow {
            display: inline-block;
            padding: var(--space-sm) var(--space-lg);
            margin-bottom: var(--space-lg);
            font-size: 0.8rem;
            font-weight: 600;
            letter-spacing: 0.15em;
            text-transform: uppercase;
            color: var(--color-accent);
            border: 1px solid var(--color-accent);
            border-radius: var(--radius-full);
            opacity: 0;
            animation: fadeInUp 0.8s ease 0.2s forwards;
        }

        .hero__title {
            font-family: var(--font-display);
            font-size: clamp(3.5rem, 8vw, 7rem);
            font-weight: 400;
            color: var(--text-inverse);
            letter-spacing: -0.03em;
            line-height: 1;
            margin-bottom: var(--space-lg);
            opacity: 0;
            animation: fadeInUp 0.8s ease 0.4s forwards;
        }

        .hero__title span {
            display: block;
            font-size: 0.35em;
            font-family: var(--font-body);
            font-weight: 300;
            letter-spacing: 0.05em;
            margin-top: var(--space-md);
            color: rgba(255, 255, 255, 0.7);
        }

        .hero__description {
            font-size: 1.25rem;
            color: rgba(255, 255, 255, 0.7);
            max-width: 600px;
            margin: 0 auto var(--space-2xl);
            opacity: 0;
            animation: fadeInUp 0.8s ease 0.6s forwards;
        }

        .hero__actions {
            display: flex;
            gap: var(--space-md);
            justify-content: center;
            flex-wrap: wrap;
            opacity: 0;
            animation: fadeInUp 0.8s ease 0.8s forwards;
        }

        .hero__btn {
            padding: var(--space-md) var(--space-2xl);
            font-size: 0.9rem;
        }

        .hero__scroll-indicator {
            position: absolute;
            bottom: var(--space-2xl);
            left: 50%;
            transform: translateX(-50%);
            display: flex;
            flex-direction: column;
            align-items: center;
            color: rgba(255, 255, 255, 0.5);
            font-size: 0.75rem;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            opacity: 0;
            animation: fadeIn 1s ease 1.2s forwards;
        }

        .hero__scroll-indicator::after {
            content: '';
            width: 1px;
            height: 40px;
            background: rgba(255, 255, 255, 0.3);
            margin-top: var(--space-sm);
            animation: scrollBounce 2s ease infinite;
        }

        @keyframes scrollBounce {
            0%, 100% { transform: translateY(0); opacity: 1; }
            50% { transform: translateY(10px); opacity: 0.5; }
        }

        /* Quick Navigation Section */
        .quick-nav {
            padding: var(--space-4xl) 0;
            background: var(--bg-body);
        }

        .quick-nav__grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: var(--space-lg);
            max-width: 900px;
            margin: 0 auto;
        }

        .quick-nav__item {
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: var(--space-2xl) var(--space-lg);
            background: var(--bg-surface);
            border: 1px solid var(--border-light);
            border-radius: var(--radius-lg);
            text-decoration: none;
            transition: all var(--transition-base);
        }

        /* .quick-nav__item:hover {
            border-color: var(--color-secondary);
            transform: translateY(-6px);
            box-shadow: var(--shadow-lg);
        }

        .quick-nav__icon {
            width: 48px;
            height: 48px;
            margin-bottom: var(--space-md);
            display: flex;
            align-items: center;
            justify-content: center;
            background: var(--bg-muted);
            border-radius: var(--radius-md);
            color: var(--color-secondary);
            transition: all var(--transition-base);
        }

        /* .quick-nav__item:hover .quick-nav__icon {
            background: var(--color-secondary);
            color: var(--text-inverse);
        } */

        .quick-nav__label {
            font-family: var(--font-display);
            font-size: 1.1rem;
            font-weight: 500;
            color: var(--text-primary);
        }

        /* Data Overview Section */
        .overview {
            padding: var(--space-4xl) 0;
            background: var(--bg-surface);
        }

        .overview__grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: var(--space-3xl);
            align-items: start;
        }

        .overview__images {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: var(--space-lg);
        }

        .overview__image-card {
            background: var(--bg-surface);
            border-radius: var(--radius-lg);
            overflow: hidden;
            border: 1px solid var(--border-light);
            transition: all var(--transition-base);
        }

        /* .overview__image-card:hover {
            transform: translateY(-4px);
            box-shadow: var(--shadow-lg);
            border-color: var(--color-secondary);
        } */

        .overview__image-card:first-child {
            grid-column: span 2;
        }

        .overview__image-card img {
            width: 100%;
            height: 200px;
            object-fit: cover;
            display: block;
        }

        .overview__image-card:first-child img {
            height: 280px;
        }

        .overview__image-caption {
            padding: var(--space-lg);
        }

        .overview__image-title {
            font-family: var(--font-display);
            font-size: 1.1rem;
            font-weight: 600;
            color: var(--text-primary);
            margin-bottom: var(--space-xs);
        }

        .overview__image-desc {
            font-size: 0.85rem;
            color: var(--text-muted);
            margin: 0;
        }

        .overview__content {
            padding: var(--space-xl) 0;
        }

        .overview__section-label {
            display: inline-block;
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 0.15em;
            text-transform: uppercase;
            color: var(--color-secondary);
            margin-bottom: var(--space-md);
        }

        .overview__heading {
            font-family: var(--font-display);
            font-size: 2.5rem;
            font-weight: 500;
            color: var(--text-primary);
            margin-bottom: var(--space-xl);
            line-height: 1.2;
        }

        .overview__text {
            font-size: 1.05rem;
            line-height: 1.8;
            color: var(--text-secondary);
            margin-bottom: var(--space-lg);
        }

        .overview__text strong {
            color: var(--color-secondary);
            font-weight: 600;
        }

        /* Statistics Section */
        .stats {
            padding: var(--space-4xl) 0;
            background: var(--bg-dark);
        }

        .stats__grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: var(--space-xl);
        }

        .stats__item {
            text-align: center;
            padding: var(--space-xl);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: var(--radius-lg);
            transition: all var(--transition-base);
        }

        /* .stats__item:hover {
            border-color: var(--color-secondary);
            background: rgba(255, 255, 255, 0.03);
        } */

        .stats__number {
            font-family: var(--font-display);
            font-size: 3rem;
            font-weight: 500;
            color: var(--color-secondary);
            line-height: 1;
            margin-bottom: var(--space-sm);
        }

        .stats__label {
            font-size: 0.9rem;
            font-weight: 500;
            color: rgba(255, 255, 255, 0.6);
            text-transform: uppercase;
            letter-spacing: 0.1em;
        }

        /* Footer */
        .site-footer {
            background: var(--bg-dark);
            border-top: 1px solid rgba(255, 255, 255, 0.1);
            padding: var(--space-3xl) 0;
        }

        .site-footer__content {
            text-align: center;
        }

        .site-footer__logo {
            font-family: var(--font-display);
            font-size: 1.5rem;
            font-weight: 500;
            color: var(--color-accent);
            margin-bottom: var(--space-md);
        }

        .site-footer__text {
            font-size: 0.9rem;
            color: rgba(255, 255, 255, 0.5);
            margin-bottom: var(--space-sm);
        }

        .site-footer__links {
            display: flex;
            gap: var(--space-lg);
            justify-content: center;
            margin-top: var(--space-lg);
        }

        .site-footer__link {
            font-size: 0.85rem;
            color: rgba(255, 255, 255, 0.5);
            transition: color var(--transition-fast);
        }

        /* .site-footer__link:hover {
            color: var(--color-secondary);
        } */

        .site-footer__counter {
            display: inline-flex;
            align-items: center;
            gap: var(--space-md);
            margin-top: var(--space-xl);
            padding: var(--space-md) var(--space-xl);
            background: rgba(255, 255, 255, 0.05);
            border-radius: var(--radius-full);
            font-size: 0.85rem;
            color: rgba(255, 255, 255, 0.6);
        }

        .site-footer__counter-divider {
            width: 1px;
            height: 16px;
            background: rgba(255, 255, 255, 0.2);
        }

        /* Responsive */
        @media (max-width: 1024px) {
            .overview__grid {
                grid-template-columns: 1fr;
            }

            .stats__grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 768px) {
            .quick-nav__grid {
                grid-template-columns: repeat(2, 1fr);
            }

            .overview__images {
                grid-template-columns: 1fr;
            }

            .overview__image-card:first-child {
                grid-column: span 1;
            }

        }

        @media (max-width: 480px) {
            .stats__grid {
                grid-template-columns: 1fr;
            }

            .hero__title {
                font-size: 3rem;
            }
        }
    </style>
</head>
<body>

<!-- Header -->
<header class="site-header">
    <div class="container">
        <a href="index.jsp" class="site-logo">scSAID</a>

        <nav class="main-nav">
            <a href="index.jsp" class="main-nav__link main-nav__link--active">Home</a>
            <a href="browse.jsp" class="main-nav__link">Browse</a>
            <a href="featureplot.jsp" class="main-nav__link">Search</a>
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

<!-- Hero Section -->
<section class="hero">
    <div class="hero__background">
        <img src="images/campus.jpg" alt="">
        <div class="hero__overlay"></div>
    </div>

    <div class="hero__content">
        <span class="hero__eyebrow">Skin Single-Cell Transcriptomic Super Atlas</span>
        <h1 class="hero__title">
            scSAID
            <span>Single-Cell <strong>S</strong>kin & <strong>A</strong>ppendages <strong>I</strong>ntegrated <strong>D</strong>atabase</span>
        </h1>
        <p class="hero__description">
            Explore the comprehensive cellular map of human and mouse skin through our curated single-cell transcriptomics repository.
        </p>
        <div class="hero__actions">
            <a href="browse.jsp" class="btn btn--primary hero__btn">Browse Datasets</a>
            <a href="featureplot.jsp" class="btn btn--outline hero__btn" style="border-color: rgba(255,255,255,0.3); color: white;">Search Genes</a>
        </div>
    </div>
</section>

<!-- Quick Navigation -->
<section class="quick-nav">
    <div class="container">
        <div class="quick-nav__grid">
            <a href="browse.jsp" class="quick-nav__item">
                <div class="quick-nav__icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="3" y="3" width="7" height="7"></rect>
                        <rect x="14" y="3" width="7" height="7"></rect>
                        <rect x="14" y="14" width="7" height="7"></rect>
                        <rect x="3" y="14" width="7" height="7"></rect>
                    </svg>
                </div>
                <span class="quick-nav__label">Browse</span>
            </a>
            <a href="featureplot.jsp" class="quick-nav__item">
                <div class="quick-nav__icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="11" cy="11" r="8"></circle>
                        <path d="m21 21-4.3-4.3"></path>
                    </svg>
                </div>
                <span class="quick-nav__label">Search</span>
            </a>
            <a href="help?topic=faq" class="quick-nav__item">
                <div class="quick-nav__icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="10"></circle>
                        <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path>
                        <path d="M12 17h.01"></path>
                    </svg>
                </div>
                <span class="quick-nav__label">Help</span>
            </a>
            <a href="download.jsp" class="quick-nav__item">
                <div class="quick-nav__icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                        <polyline points="7,10 12,15 17,10"></polyline>
                        <line x1="12" y1="15" x2="12" y2="3"></line>
                    </svg>
                </div>
                <span class="quick-nav__label">Download</span>
            </a>
        </div>
    </div>
</section>

<!-- Statistics -->
<section class="stats">
    <div class="container">
        <div class="stats__grid">
            <div class="stats__item">
                <div class="stats__number">1.2M</div>
                <div class="stats__label">Total Cells</div>
            </div>
            <div class="stats__item">
                <div class="stats__number">252</div>
                <div class="stats__label">Samples</div>
            </div>
            <div class="stats__item">
                <div class="stats__number">49</div>
                <div class="stats__label">Studies</div>
            </div>
            <div class="stats__item">
                <div class="stats__number">2</div>
                <div class="stats__label">Species</div>
            </div>
        </div>
    </div>
</section>

<!-- Data Overview Section -->
<section class="overview">
    <div class="container">
        <div class="overview__grid">
            <div class="overview__content">
                <span class="overview__section-label">About the Database</span>
                <h2 class="overview__heading">Comprehensive scRNA-seq Repository for Skin Research</h2>
                <p class="overview__text">
                    Welcome to our comprehensive scRNA-seq database dedicated to skin and its appendages. This database contains data from over <strong>1.2 million</strong> cells derived from <strong>252</strong> samples across <strong>49</strong> independent studies, including both human and mouse datasets.
                </p>
                <p class="overview__text">
                    As one of the most extensive collections available to date, our database provides a platform for exploring the complex cellular landscapes and molecular mechanisms underlying skin biology and its associated structures.
                </p>
                <p class="overview__text">
                    The database includes detailed annotations for each sample, including species, gender, age, anatomical region, and experimental conditions. All data has been processed through a standardized pipeline to ensure consistency and comparability across studies.
                </p>
                <a href="browse.jsp" class="btn btn--primary">Explore Datasets</a>
            </div>
        </div>
    </div>
</section>

<!-- Data Composition Section -->
<section class="composition">
    <div class="container">
        <div class="composition__header">
            <span class="composition__section-label">Data Composition</span>
            <h2 class="composition__heading">Explore the Database</h2>
            <p class="composition__subtitle">
                Interactive breakdown of cell counts across cell types, conditions, demographics, and batches.
            </p>
            <div class="composition__toggle">
                <button class="composition__toggle-btn composition__toggle-btn--active" data-species="human">Human</button>
                <button class="composition__toggle-btn" data-species="mouse">Mouse</button>
            </div>
        </div>

        <div class="composition__grid">
            <!-- Row 1 -->
            <div class="composition__chart-card composition__chart-card--gross">
                <h3 class="composition__chart-title">Cell Type Overview</h3>
                <p class="composition__chart-desc">Major cell type categories</p>
                <div class="composition__chart-container" id="chart-gross-map"></div>
            </div>
            <div class="composition__chart-card composition__chart-card--condition">
                <h3 class="composition__chart-title">Condition</h3>
                <p class="composition__chart-desc">Disease and experimental conditions</p>
                <div class="composition__chart-container" id="chart-condition"></div>
            </div>

            <!-- Row 2 -->
            <div class="composition__chart-card composition__chart-card--sex">
                <h3 class="composition__chart-title">Sex</h3>
                <p class="composition__chart-desc">Sample sex distribution</p>
                <div class="composition__chart-container" id="chart-sex"></div>
            </div>
            <div class="composition__chart-card composition__chart-card--age">
                <h3 class="composition__chart-title">Age</h3>
                <p class="composition__chart-desc">Age distribution of samples</p>
                <div class="composition__chart-container" id="chart-age"></div>
            </div>

            <!-- Skin Location -->
            <div class="composition__chart-card composition__chart-card--skin">
                <h3 class="composition__chart-title">Skin Location</h3>
                <p class="composition__chart-desc">Anatomical source locations</p>
                <div class="composition__chart-container" id="chart-skin-location"></div>
            </div>

            <!-- Fine Map -->
            <div class="composition__chart-card composition__chart-card--fine">
                <h3 class="composition__chart-title">Fine Cell Types</h3>
                <p class="composition__chart-desc">Detailed cell subtype classification — scroll to explore all types</p>
                <div class="composition__chart-container" id="chart-fine-map"></div>
            </div>

            <!-- Batch -->
            <div class="composition__chart-card composition__chart-card--batch">
                <h3 class="composition__chart-title">Top 25 Batches</h3>
                <p class="composition__chart-desc">Largest sample batches by cell count</p>
                <div class="composition__chart-container" id="chart-batch"></div>
            </div>
        </div>
    </div>
</section>

<!-- Footer -->
<footer class="site-footer">
    <div class="container">
        <div class="site-footer__content">
            <div class="site-footer__logo">scSAID</div>
            <p class="site-footer__text">Single-Cell Skin & Appendages Integrated Database</p>
            <p class="site-footer__text">Zhejiang University</p>

            <div class="site-footer__links">
                <a href="mailto:info@scsaid.org" class="site-footer__link">Contact</a>
                <a href="#" class="site-footer__link">Privacy Policy</a>
                <a href="#" class="site-footer__link">Terms of Use</a>
            </div>

            <div class="site-footer__counter">
                <%
                    Object totalObj = application.getAttribute("totalCount");
                    Object dailyObj = application.getAttribute("dailyCount");
                    int totalCountValue = (totalObj instanceof java.util.concurrent.atomic.AtomicInteger)
                            ? ((java.util.concurrent.atomic.AtomicInteger) totalObj).get()
                            : 0;
                    int dailyCountValue = (dailyObj instanceof java.util.concurrent.atomic.AtomicInteger)
                            ? ((java.util.concurrent.atomic.AtomicInteger) dailyObj).get()
                            : 0;
                %>
                <span>Total Visits: <%= totalCountValue %></span>
                <span class="site-footer__counter-divider"></span>
                <span>Today: <%= dailyCountValue %></span>
            </div>
        </div>
    </div>
</footer>

<!-- Under Construction Modal Script -->
<script src="JS/construction-modal-simple.js"></script>

<!-- Composition Charts -->
<script src="JS/cell-count-data.js"></script>
<script src="JS/composition-charts.js"></script>
<script>
    document.addEventListener('DOMContentLoaded', function () {
        if (typeof CompositionCharts !== 'undefined') {
            CompositionCharts.init();
        }
    });
</script>


<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
