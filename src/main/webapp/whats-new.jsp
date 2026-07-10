<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex,follow">
    <title>What's New - scSAID</title>
    <meta name="description" content="Release notes and updates for scSAID.">
    <link rel="icon" type="image/x-icon" href="/favicon.ico?v=20260703a">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png?v=20260703a">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png?v=20260703a">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="CSS/design-system.css?v=20260710c">
    <link rel="stylesheet" href="CSS/header.css?v=20260710c">
    <link rel="stylesheet" href="CSS/about-pages.css?v=20260703a">
</head>
<body>
    <%@ include file="includes/header.jsp" %>
    <main class="about-page" id="main-content" tabindex="-1" aria-label="What&apos;s New">
        <header class="about-page__header">
            <h1>What’s New in scSAID</h1>
            <p class="about-page__intro">Release notes for new datasets, analyses, interface improvements, and reproducibility changes.</p>
        </header>

        <section class="release" aria-labelledby="release-latest-title">
            <h2 class="release__date" id="release-latest-title">July 2026</h2>
            <article class="release-entry">
                <h3>LLM Interpretation panel <span class="main-nav__badge">beta</span></h3>
                <p>A new LLM Interpretation card is available on dataset detail pages. Users can select scSAID-generated analysis outputs, combine them with dataset metadata and linked publication context, and request an expert-style interpretation from a supported provider using their own API key.</p>
                <p>The provider key is used only for the submitted request and is not stored in server sessions, cookies, browser storage, database tables, caches, or application logs. The panel currently supports OpenAI, DeepSeek, Claude, and Gemini.</p>
            </article>
            <article class="release-entry">
                <h3>Regulon and regulatory-network interpretation <span class="main-nav__badge">beta</span></h3>
                <p>The regulatory-network workflow has been expanded around regulon-level interpretation. The detail-page network view now emphasizes compact regulator/target exploration, including top transcription-factor summaries and targetome context for selected datasets.</p>
            </article>
            <article class="release-entry">
                <h3>Navigation and analysis-page polish</h3>
                <p>Header navigation, shared segmented toggles, marker search, condition DEG search, and result tables were aligned to the same compact scSAID/HumanBase-inspired interface language for clearer cross-page workflows.</p>
            </article>
        </section>
    </main>
</body>
</html>
