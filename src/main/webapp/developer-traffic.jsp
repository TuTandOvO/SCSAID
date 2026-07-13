<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex, nofollow, noarchive">
    <title>Private visitor analytics · scSAID</title>
    <link rel="stylesheet" href="CSS/global.css?v=20260713a">
    <link rel="stylesheet" href="CSS/developer-traffic.css?v=20260713a">
</head>
<body class="developer-analytics-page">
<main class="developer-analytics" aria-labelledby="analyticsTitle">
    <header class="developer-analytics__hero">
        <p class="developer-analytics__eyebrow">Private developer view</p>
        <h1 id="analyticsTitle">Visitor analytics</h1>
        <p class="developer-analytics__intro">A live, protected view of counted scSAID visits. Address-level data is never public; the map uses country-level placement rather than precise visitor locations.</p>
        <p class="developer-analytics__privacy">Counted visit events, protected address aggregates, and recurrence history are retained indefinitely for site administration.</p>
    </header>

    <section class="developer-analytics__metrics" aria-label="All-time visitor metrics" aria-live="polite">
        <article class="developer-analytics__metric"><span>All-time visits</span><strong id="allTimeVisits">—</strong><small>counted browser-days</small></article>
        <article class="developer-analytics__metric"><span>Unique visitors</span><strong id="uniqueVisitors">—</strong><small>protected address groups</small></article>
        <article class="developer-analytics__metric"><span>Returning visitors</span><strong id="returningVisitors">—</strong><small id="returningDetail">— repeat visits</small></article>
        <article class="developer-analytics__metric"><span>Last 30 days</span><strong id="recentVisits">—</strong><small id="recentDetail">— unique visitors</small></article>
    </section>

    <section class="developer-analytics__panel developer-analytics__map-panel" aria-labelledby="mapTitle">
        <div class="developer-analytics__panel-head">
            <div><p class="developer-analytics__eyebrow">Geography</p><h2 id="mapTitle">Visit map</h2></div>
            <div class="developer-analytics__controls" role="group" aria-label="Map period">
                <button type="button" class="developer-analytics__chip is-active" data-map-scope="all">All time</button>
                <button type="button" class="developer-analytics__chip" data-map-scope="recent">30 days</button>
            </div>
        </div>
        <div class="developer-analytics__map-layout">
            <div class="developer-analytics__map-wrap">
                <svg id="visitMap" class="developer-analytics__map" viewBox="0 0 1000 500" role="img" aria-labelledby="mapTitle mapCaption">
                    <title>Country-level placement of counted visits</title>
                    <g class="developer-analytics__graticule">
                        <path d="M0 125H1000M0 250H1000M0 375H1000M250 0V500M500 0V500M750 0V500" />
                    </g>
                    <g class="developer-analytics__continents" aria-hidden="true">
                        <path d="M68 87l54-39 84 8 40 47-9 52-38 29-25 64-53 1-35-42-32-56 8-37z" />
                        <path d="M219 254l41 16 25 55-10 78-35 57-28-61 5-75z" />
                        <path d="M418 86l85-35 98 17 57 42-29 37-72 11-24 52-74-6-34-43z" />
                        <path d="M492 210l58 15 34 65-22 101-44 51-33-65 8-65z" />
                        <path d="M657 80l73-23 96 31 88 9 47 47-51 40-57-7-57 39-51-31-49-41-42-8z" />
                        <path d="M783 318l70-17 86 37 9 56-65 34-78-39z" />
                    </g>
                    <g id="mapDots" class="developer-analytics__map-dots"></g>
                </svg>
            </div>
            <aside class="developer-analytics__map-detail" id="mapDetail" aria-live="polite">
                <span class="developer-analytics__map-key"><i class="developer-analytics__dot-key"></i> first counted visit</span>
                <span class="developer-analytics__map-key"><i class="developer-analytics__dot-key developer-analytics__dot-key--return"></i> returning visit</span>
                <p id="mapCaption">Each dot is one counted visit, placed with small deterministic jitter around its country. Hover or select a dot for its protected visit record.</p>
            </aside>
        </div>
    </section>

    <div class="developer-analytics__chart-grid">
        <section class="developer-analytics__panel" aria-labelledby="dailyTitle">
            <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Trend</p><h2 id="dailyTitle">Visits by day</h2></div><span>Last 30 days · UTC</span></div>
            <div class="developer-analytics__chart-wrap"><svg id="dailyChart" class="developer-analytics__chart" viewBox="0 0 640 230" role="img" aria-label="Daily counted visits in the last 30 days"></svg></div>
        </section>
        <section class="developer-analytics__panel" aria-labelledby="hourlyTitle">
            <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Live timing</p><h2 id="hourlyTitle">Visits by hour</h2></div><span>Rolling 24 hours · UTC</span></div>
            <div class="developer-analytics__chart-wrap"><svg id="hourlyChart" class="developer-analytics__chart" viewBox="0 0 640 230" role="img" aria-label="Hourly counted visits in the last 24 hours"></svg></div>
        </section>
    </div>

    <div class="developer-analytics__table-grid">
        <section class="developer-analytics__panel" aria-labelledby="pagesTitle">
            <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Content</p><h2 id="pagesTitle">Most visited pages</h2></div><span>All time</span></div>
            <div class="developer-analytics__table-wrap"><table><thead><tr><th>Page</th><th>Visits</th></tr></thead><tbody id="pageRows"><tr><td colspan="2">Loading protected analytics…</td></tr></tbody></table></div>
        </section>
        <section class="developer-analytics__panel" aria-labelledby="recentPagesTitle">
            <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Recent</p><h2 id="recentPagesTitle">Most visited pages</h2></div><span>Last 30 days</span></div>
            <div class="developer-analytics__table-wrap"><table><thead><tr><th>Page</th><th>Visits</th></tr></thead><tbody id="recentPageRows"><tr><td colspan="2">Loading protected analytics…</td></tr></tbody></table></div>
        </section>
    </div>

    <section class="developer-analytics__panel" aria-labelledby="visitorTitle">
        <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Recurrence</p><h2 id="visitorTitle">Returning visitor history</h2></div><span>All time · protected addresses</span></div>
        <div class="developer-analytics__table-wrap"><table><thead><tr><th>IP address</th><th>Country</th><th>Visits</th><th>First seen (UTC)</th><th>Last seen (UTC)</th><th>Last page</th></tr></thead><tbody id="visitorRows"><tr><td colspan="6">Loading protected visitor history…</td></tr></tbody></table></div>
    </section>

    <div class="developer-analytics__table-grid">
        <section class="developer-analytics__panel" aria-labelledby="recentTitle">
            <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Geography</p><h2 id="recentTitle">Countries by visits</h2></div><span id="recentRange"></span></div>
            <div class="developer-analytics__table-wrap"><table><thead><tr><th>Country</th><th>Code</th><th>Visits</th></tr></thead><tbody id="recentRows"><tr><td colspan="3">Loading private analytics…</td></tr></tbody></table></div>
        </section>
        <section class="developer-analytics__panel" aria-labelledby="allTimeTitle">
            <div class="developer-analytics__panel-head"><div><p class="developer-analytics__eyebrow">Aggregate</p><h2 id="allTimeTitle">Countries by visits</h2></div><span>All time</span></div>
            <div class="developer-analytics__table-wrap"><table><thead><tr><th>Country</th><th>Code</th><th>Visits</th></tr></thead><tbody id="allTimeRows"><tr><td colspan="3">Loading private analytics…</td></tr></tbody></table></div>
        </section>
    </div>
    <p id="analyticsStatus" class="developer-analytics__status" aria-live="polite"></p>
</main>
<script src="JS/country-traffic.js?v=20260713a"></script>
</body>
</html>
