<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy - scSAID</title>
    <meta name="description" content="How scSAID uses first-party cookies and local browser storage.">
    <link rel="icon" type="image/x-icon" href="/favicon.ico?v=20260703a">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="CSS/design-system.css?v=20260703q">
    <link rel="stylesheet" href="CSS/header.css?v=20260704a">
    <link rel="stylesheet" href="CSS/privacy.css?v=20260703d">
</head>
<body>
<%@ include file="includes/header.jsp" %>

<main class="privacy-page" id="main-content" tabindex="-1">
    <h1>Privacy and browser storage</h1>
    <p class="privacy-page__intro">
        scSAID uses a small amount of first-party browser storage to operate reliably and remember interface preferences. It does not use advertising cookies or third-party tracking cookies.
    </p>

    <section class="privacy-section" aria-labelledby="stored-data-title">
        <h2 id="stored-data-title">What is stored</h2>
        <div class="privacy-table-wrap">
            <table class="privacy-table">
                <thead><tr><th>Storage</th><th>Purpose</th><th>Retention</th></tr></thead>
                <tbody>
                    <tr><td>Session cookie</td><td>Maintains secure server session state when a feature requires it.</td><td>Browser session</td></tr>
                    <tr><td><code>count_cookie</code></td><td>Prevents the same browser being counted repeatedly in the daily visit total.</td><td>Up to one year</td></tr>
                    <tr><td>Local preferences</td><td>Remembers preferred species and whether pseudogenes should be hidden.</td><td>Until cleared in the browser</td></tr>
                    <tr><td>Notice acknowledgement</td><td>Prevents this storage notice appearing on every page visit.</td><td>Until cleared in the browser</td></tr>
                </tbody>
            </table>
        </div>
    </section>

    <section class="privacy-section" aria-labelledby="not-stored-title">
        <h2 id="not-stored-title">What is not stored for tracking</h2>
        <p>scSAID does not use browser storage for advertising, cross-site profiling, or third-party behavioural analytics. Gene searches and analysis results are not placed in preference storage.</p>
    </section>

    <section class="privacy-section" aria-labelledby="ai-processing-title">
        <h2 id="ai-processing-title">Optional AI interpretation</h2>
        <p>The beta AI Interpretation panel is inactive until you open it and accept its inline privacy statement. If you submit a request, your provider API key passes over HTTPS to scSAID, is used transiently to authorize that single OpenAI or DeepSeek call, and is not saved in a database, session, cookie, browser storage, cache, or application log.</p>
        <p>The analysis results you select, this dataset’s metadata, and available publication abstract and study context are sent to the chosen provider. Their processing and retention are governed by your provider account and the provider’s terms. The returned interpretation is kept only in the current page and is lost when the page is refreshed.</p>
    </section>

    <section class="privacy-section" aria-labelledby="controls-title">
        <h2 id="controls-title">Your controls</h2>
        <p>You can clear scSAID’s saved interface preferences here. Essential session behavior and the visit counter cookie are managed through your browser’s cookie controls.</p>
        <button class="privacy-reset" type="button" data-reset-preferences aria-describedby="privacy-reset-status">Clear saved preferences</button>
        <p class="privacy-reset-status" id="privacy-reset-status" role="status" aria-live="polite"></p>
    </section>

    <section class="privacy-section" aria-labelledby="contact-title">
        <h2 id="contact-title">Contact</h2>
        <p>Questions about this notice can be sent through the <a href="feedback">feedback page</a>.</p>
    </section>
</main>
</body>
</html>
