<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex,follow">
    <title>How to Cite - scSAID</title>
    <meta name="description" content="Citation guidance and method references for scSAID.">
    <link rel="icon" type="image/x-icon" href="/favicon.ico?v=20260703a">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png?v=20260703a">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png?v=20260703a">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="CSS/design-system.css?v=20260710c">
    <link rel="stylesheet" href="CSS/header.css?v=20260712a">
    <link rel="stylesheet" href="CSS/about-pages.css?v=20260703a">
</head>
<body>
    <%@ include file="includes/header.jsp" %>
    <main class="about-page" id="main-content" tabindex="-1" aria-label="How to Cite">
        <header class="about-page__header">
            <h1>How to Cite scSAID</h1>
            <p class="about-page__intro">Citation information for the atlas and the analysis methods used in a study.</p>
        </header>

        <section class="about-section" aria-labelledby="cite-scsaid-title">
            <h2 id="cite-scsaid-title">Citing scSAID</h2>
            <p>If scSAID contributed data, analysis, or visualizations to your research, please cite:</p>
            <p>Ren, Y., Shen, Y., Jin, L., Huang, Y., Deng, Y., Xiao, Y., &amp; Wang, C. (2026). scSAID: A comprehensive cross-species single-cell skin atlas reveals species-specific responses to psoriasis. bioRxiv. https://doi.org/[DOI]</p>
            <p>Citations help document use of the resource and support its continued maintenance.</p>
        </section>

        <section class="about-section" aria-labelledby="additional-references-title">
            <h2 id="additional-references-title">Additional references</h2>
            <p>When reporting a specific analysis, also cite the corresponding method or source dataset.</p>
            <ul>
                <li><strong>Source datasets:</strong> <span class="template-placeholder">[Add the GEO study and primary publication used in the analysis.]</span></li>
                <li><strong>Analysis methods:</strong> <span class="template-placeholder">[Add references for CellPhoneDB, SCORPION, AUCell, UCell, GSVA, GSEA, DESeq2, or other methods used.]</span></li>
                <li><strong>External resources:</strong> <span class="template-placeholder">[Add references for MSigDB, STRING, CollecTRI, or other databases used.]</span></li>
            </ul>
        </section>
    </main>
</body>
</html>
