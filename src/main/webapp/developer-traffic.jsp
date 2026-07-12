<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex, nofollow, noarchive">
    <title>Private country analytics · scSAID</title>
    <link rel="stylesheet" href="CSS/global.css?v=20260712a">
    <link rel="stylesheet" href="CSS/developer-traffic.css?v=20260712a">
</head>
<body class="developer-analytics-page">
<main class="developer-analytics" aria-labelledby="analyticsTitle">
    <p class="developer-analytics__eyebrow">Private developer view</p>
    <h1 id="analyticsTitle">Visitor country analytics</h1>
    <p class="developer-analytics__intro">Country-level aggregates from counted page visits. The application uses a local GeoLite database transiently and does not retain or display individual IP addresses.</p>
    <p class="developer-analytics__privacy">This page is intentionally absent from public navigation and requires server-configured developer credentials.</p>

    <div class="developer-analytics__metrics" aria-live="polite">
        <section class="developer-analytics__metric"><span>All-time country-attributed visits</span><strong id="allTimeTotal">—</strong></section>
        <section class="developer-analytics__metric"><span>Last 30 days</span><strong id="recentTotal">—</strong></section>
    </div>

    <section class="developer-analytics__panel" aria-labelledby="recentTitle">
        <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Recent</p><h2 id="recentTitle">Countries in the last 30 days</h2></div><span id="recentRange" class="developer-analytics__range"></span></div>
        <div class="developer-analytics__table-wrap"><table><thead><tr><th>Country</th><th>Code</th><th>Visits</th></tr></thead><tbody id="recentRows"><tr><td colspan="3">Loading private analytics…</td></tr></tbody></table></div>
    </section>

    <section class="developer-analytics__panel" aria-labelledby="allTimeTitle">
        <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Aggregate</p><h2 id="allTimeTitle">Countries since collection began</h2></div></div>
        <div class="developer-analytics__table-wrap"><table><thead><tr><th>Country</th><th>Code</th><th>Visits</th></tr></thead><tbody id="allTimeRows"><tr><td colspan="3">Loading private analytics…</td></tr></tbody></table></div>
    </section>
    <p id="analyticsStatus" class="developer-analytics__status" aria-live="polite"></p>
</main>
<script src="JS/country-traffic.js?v=20260712a"></script>
</body>
</html>
