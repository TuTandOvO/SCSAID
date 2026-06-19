<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%
    // Landing page that wraps the Integrated UMAP "gene expression" mode inside
    // a scSAID page shell (header + footer). The actual feature plot is served
    // by the Dash app at /integrated_umap/, so all we do here is:
    //   * read ?gene= from the URL
    //   * build an <iframe> pointing at /integrated_umap/?gene=<gene>
    //   * provide a search box that re-navigates with the new gene
    String geneParam = request.getParameter("gene");
    if (geneParam == null) geneParam = "";
    geneParam = geneParam.trim();

    // Escape for embedding in HTML / JS
    String geneHtml = geneParam.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;");
    String geneUrl  = java.net.URLEncoder.encode(geneParam, "UTF-8");

    response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
%>
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
    <title>Feature Plot - scSAID</title>
    <meta name="description" content="Interactive gene expression feature plots on the integrated human and mouse skin atlas. Enter any gene symbol to visualise its expression across ~400K human cells or ~800K mouse cells. Case-insensitive (COL1A1, Col1a1 both work).">
    <meta name="keywords" content="gene expression atlas, feature plot, UMAP gene, scRNA-seq gene expression, skin gene atlas, scSAID feature plot, keratinocyte marker, dermal gene">
    <meta name="robots" content="index,follow">
    <link rel="canonical" href="https://skin-scsaid.com/featureplot.jsp">
    <meta property="og:type" content="website">
    <meta property="og:title" content="Feature Plot — Gene Expression Atlas | scSAID">
    <meta property="og:description" content="Interactive gene featureplot on the integrated human and mouse skin scRNA-seq atlas.">
    <meta property="og:url" content="https://skin-scsaid.com/featureplot.jsp">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=Source+Sans+3:wght@400;500;600&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="CSS/design-system.css">
    <link rel="stylesheet" href="CSS/header.css">

    <style>
        body { background:#faf8f5; margin:0; font-family:'Montserrat', sans-serif; }
        .featureplot-page { min-height:100vh; padding-top:72px; }

        .featureplot-hero {
            background:#1a2332; padding:3.5rem 0 2.5rem; text-align:center;
        }
        .featureplot-hero__content {
            max-width:760px; margin:0 auto; padding:0 2rem;
        }
        .featureplot-hero__eyebrow {
            display:inline-block; font-size:0.75rem; font-weight:700;
            letter-spacing:0.15em; text-transform:uppercase;
            color:#d4a574; margin-bottom:1rem;
        }
        .featureplot-hero__title {
            font-family:'Cormorant Garamond', Georgia, serif;
            font-size:clamp(2rem, 4vw, 2.7rem); font-weight:500;
            color:#ffffff; margin:0 0 0.75rem;
        }
        .featureplot-hero__desc {
            font-size:1rem; color:rgba(255,255,255,0.7);
            margin:0 0 1.8rem; line-height:1.6;
        }
        .featureplot-search {
            display:flex; max-width:520px; margin:0 auto;
            background:#ffffff; border-radius:10px; overflow:hidden;
            box-shadow:0 6px 24px rgba(0,0,0,0.18);
        }
        .featureplot-search__input {
            flex:1; padding:1rem 1.2rem; font-family:'Montserrat', sans-serif;
            font-size:1rem; border:none; outline:none; background:transparent;
        }
        .featureplot-search__btn {
            padding:1rem 1.8rem; background:#e8927c; color:#ffffff;
            font-family:'Montserrat', sans-serif; font-size:0.95rem;
            font-weight:600; border:none; cursor:pointer;
            transition:background 0.2s ease;
        }
        .featureplot-search__btn:hover { background:#d47b64; }

        .featureplot-hint {
            font-size:0.82rem; color:rgba(255,255,255,0.6);
            margin-top:0.8rem;
        }

        .featureplot-frame-wrap {
            max-width:1400px; margin:0 auto; padding:1.5rem 1rem 4rem;
        }
        .featureplot-frame {
            width:100%; height:950px; border:1px solid #e5e0d8;
            border-radius:12px; background:#ffffff;
            box-shadow:0 4px 20px rgba(26,35,50,0.06);
        }

        .featureplot-empty {
            padding:3.5rem 1.5rem; text-align:center; color:#5a6473;
            background:#ffffff; border:1px dashed #e5e0d8;
            border-radius:12px; max-width:900px; margin:3rem auto;
        }
        .featureplot-empty h2 {
            font-family:'Cormorant Garamond', Georgia, serif;
            font-size:1.5rem; color:#1a2332; margin:0 0 0.5rem;
        }
    </style>
</head>
<body>

<!-- Header (identical to other pages) -->
<header class="site-header">
    <div class="container">
        <a href="index.jsp" class="site-logo">scSAID</a>
        <nav class="main-nav">
            <a href="index.jsp" class="main-nav__link">Home</a>
            <a href="browse.jsp" class="main-nav__link">Browse</a>
            <a href="featureplot.jsp" class="main-nav__link main-nav__link--active">Search</a>
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
                <svg class="github-icon" viewBox="0 0 24 24" fill="currentColor" width="22" height="22">
                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                </svg>
            </a>
            <a href="https://zje.zju.edu.cn/zje/main.htm" target="_blank" class="header-icon-link" title="ZJE - Zhejiang University">
                <img src="images/ZJE_Logo.png" alt="ZJE - Zhejiang University" class="university-logo">
            </a>
        </div>
    </div>
</header>

<div class="featureplot-page">
    <section class="featureplot-hero">
        <div class="featureplot-hero__content">
            <span class="featureplot-hero__eyebrow">Integrated Atlas · Gene Expression</span>
            <h1 class="featureplot-hero__title">Feature Plot</h1>
            <p class="featureplot-hero__desc">
                Enter a gene symbol to visualise its expression on the integrated
                human or mouse skin UMAP atlas. Case-insensitive — both HGNC
                (e.g. <em>COL1A1</em>) and MGI (e.g. <em>Col1a1</em>) names are accepted.
            </p>
            <form action="featureplot.jsp" method="get" class="featureplot-search" autocomplete="off">
                <input class="featureplot-search__input" type="text" name="gene"
                       placeholder="Gene symbol, e.g. COL1A1"
                       value="<%= geneHtml %>" autofocus required>
                <button class="featureplot-search__btn" type="submit">View</button>
            </form>
            <div class="featureplot-hint">
                Try&nbsp;
                <a href="featureplot.jsp?gene=COL1A1" style="color:#d4a574;">COL1A1</a>,&nbsp;
                <a href="featureplot.jsp?gene=KRT14" style="color:#d4a574;">KRT14</a>,&nbsp;
                <a href="featureplot.jsp?gene=Ptprc" style="color:#d4a574;">Ptprc</a>,&nbsp;
                <a href="featureplot.jsp?gene=Col1a1" style="color:#d4a574;">Col1a1</a>
            </div>
        </div>
    </section>

    <% if (geneParam.isEmpty()) { %>
        <div class="featureplot-empty">
            <h2>No gene selected</h2>
            <p>Enter a gene symbol above to render its expression atlas. Rendering typically takes 2–4 seconds.</p>
        </div>
    <% } else { %>
        <div class="featureplot-frame-wrap">
            <iframe class="featureplot-frame"
                    src="/integrated_umap/?gene=<%= geneUrl %>"
                    title="Feature plot for <%= geneHtml %>"
                    loading="eager">
            </iframe>
        </div>
    <% } %>
</div>

</body>
</html>
