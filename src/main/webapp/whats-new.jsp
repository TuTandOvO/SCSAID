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
    <link rel="stylesheet" href="CSS/design-system.css?v=20260703q">
    <link rel="stylesheet" href="CSS/header.css?v=20260704a">
    <link rel="stylesheet" href="CSS/about-pages.css?v=20260703a">
</head>
<body>
    <%@ include file="includes/header.jsp" %>
    <main class="about-page" id="main-content" tabindex="-1" aria-label="What&apos;s New">
        <header class="about-page__header">
            <h1>What’s New in scSAID</h1>
            <p class="about-page__intro">Release notes for new datasets, analyses, interface improvements, and reproducibility changes.</p>
        </header>

        <div class="template-note">Template: duplicate a dated section for each release and replace the bracketed text.</div>

        <section class="release" aria-labelledby="release-latest-title">
            <h2 class="release__date" id="release-latest-title">[Month Year]</h2>
            <article class="release-entry">
                <h3>[New analysis or dataset]</h3>
                <p class="template-placeholder">[Describe what was added, where users can find it, and the scientific question it supports.]</p>
            </article>
            <article class="release-entry">
                <h3>[Interface or workflow improvement]</h3>
                <p class="template-placeholder">[Describe the changed workflow and what users should do differently.]</p>
            </article>
            <article class="release-entry">
                <h3>[Data or method version update]</h3>
                <p class="template-placeholder">[Record the affected resource versions, whether results changed, and how to reproduce older results.]</p>
            </article>
        </section>

        <section class="release" aria-labelledby="release-previous-title">
            <h2 class="release__date" id="release-previous-title">[Previous Month Year]</h2>
            <article class="release-entry">
                <h3>[Update title]</h3>
                <p class="template-placeholder">[Concise description of the release, with links to the affected page or documentation where appropriate.]</p>
            </article>
        </section>
    </main>
</body>
</html>
