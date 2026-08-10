<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex, nofollow, noarchive">
    <title>Private visitor analytics · scSAID</title>
    <link rel="stylesheet" href="lib/leaflet/leaflet.css?v=1.9.4">
    <link rel="stylesheet" href="CSS/design-system.css?v=20260714a">
    <link rel="stylesheet" href="CSS/developer-traffic.css?v=20260810b">
</head>
<body class="developer-analytics-page">
<main class="developer-analytics" aria-labelledby="analyticsTitle">
    <header class="developer-analytics__hero">
        <div class="developer-analytics__hero-meta">
            <span class="developer-analytics__brand">scSAID</span>
            <span class="developer-analytics__protected"><i aria-hidden="true"></i> Private developer view</span>
        </div>
        <h1 id="analyticsTitle">Visitor traffic</h1>
        <p class="developer-analytics__intro">Live site activity, recurrence, content use, and approximate city/region geography. IP geolocation is not a street, household, or building location.</p>
        <p class="developer-analytics__privacy">Counted visit events, first-party visitor IDs, protected address records, and recurrence history are retained for site administration.</p>
    </header>

    <section class="developer-analytics__metrics" aria-label="Visitor summary" aria-live="polite">
        <dl class="developer-analytics__metric"><dt>All-time visits</dt><dd id="allTimeVisits">—</dd><small>counted browser-days</small></dl>
        <dl class="developer-analytics__metric"><dt>Unique visitors</dt><dd id="uniqueVisitors">—</dd><small>first-party visitor IDs</small></dl>
        <dl class="developer-analytics__metric"><dt>Returning visitors</dt><dd id="returningVisitors">—</dd><small id="returningDetail">— repeat visits</small></dl>
        <dl class="developer-analytics__metric"><dt>Last 30 days</dt><dd id="recentVisits">—</dd><small id="recentDetail">— unique visitors</small></dl>
    </section>

    <section class="developer-analytics__panel developer-analytics__map-panel" aria-labelledby="mapTitle">
        <div class="developer-analytics__panel-head">
            <div><h2 id="mapTitle">Visit map</h2><p>Hover a marker for its regional aggregate and latest approximate GeoIP evidence.</p></div>
            <div class="developer-analytics__controls" role="group" aria-label="Map period">
                <button type="button" class="developer-analytics__chip is-active" data-map-scope="all">All time</button>
                <button type="button" class="developer-analytics__chip" data-map-scope="recent">30 days</button>
                <button type="button" class="developer-analytics__chip" data-map-scope="returning">Returning</button>
            </div>
        </div>
        <div class="developer-analytics__map-wrap" aria-labelledby="mapTitle mapCaption">
            <div id="visitMap" class="developer-analytics__map" role="application" aria-label="Regional visit map"></div>
        </div>
        <footer class="developer-analytics__map-footer">
            <div class="developer-analytics__map-legend" aria-label="Marker legend">
                <span><i class="developer-analytics__dot-key" aria-hidden="true"></i> lower returning share</span>
                <span><i class="developer-analytics__dot-key developer-analytics__dot-key--return" aria-hidden="true"></i> higher returning share</span>
            </div>
            <p id="mapCaption">Marker size represents visits; color represents returning share. China, the United States, and the United Kingdom use regional boundaries where available.</p>
            <p id="mapStatus" class="developer-analytics__map-status" aria-live="polite"></p>
        </footer>
    </section>

    <div class="developer-analytics__chart-grid">
        <section class="developer-analytics__panel" aria-labelledby="dailyTitle">
            <div class="developer-analytics__panel-head"><div><h2 id="dailyTitle">Visits by day</h2><p>Counted activity over the last 30 days.</p></div><span>UTC buckets</span></div>
            <div class="developer-analytics__chart-wrap"><svg id="dailyChart" class="developer-analytics__chart" viewBox="0 0 640 230" role="img" aria-label="Daily counted visits in the last 30 days"></svg></div>
        </section>
        <section class="developer-analytics__panel" aria-labelledby="hourlyTitle">
            <div class="developer-analytics__panel-head"><div><h2 id="hourlyTitle">Visits by hour</h2><p>Rolling activity across the last 24 hours.</p></div><span>UTC buckets</span></div>
            <div class="developer-analytics__chart-wrap"><svg id="hourlyChart" class="developer-analytics__chart" viewBox="0 0 640 230" role="img" aria-label="Hourly counted visits in the last 24 hours"></svg></div>
        </section>
    </div>

    <div class="developer-analytics__table-grid">
        <section class="developer-analytics__panel" aria-labelledby="pagesTitle">
            <div class="developer-analytics__panel-head"><div><h2 id="pagesTitle">Most visited pages</h2><p>Counted content-page activity.</p></div><span>All time</span></div>
            <div class="developer-analytics__table-wrap"><table><thead><tr><th>Page</th><th>Visits</th></tr></thead><tbody id="pageRows"><tr><td colspan="2">Loading protected analytics…</td></tr></tbody></table></div>
        </section>
        <section class="developer-analytics__panel" aria-labelledby="recentPagesTitle">
            <div class="developer-analytics__panel-head"><div><h2 id="recentPagesTitle">Recent page activity</h2><p>Popular content in the current period.</p></div><span>Last 30 days</span></div>
            <div class="developer-analytics__table-wrap"><table><thead><tr><th>Page</th><th>Visits</th></tr></thead><tbody id="recentPageRows"><tr><td colspan="2">Loading protected analytics…</td></tr></tbody></table></div>
        </section>
    </div>

    <section class="developer-analytics__panel developer-analytics__ledger-panel" aria-labelledby="eventLedgerTitle">
        <div class="developer-analytics__panel-head developer-analytics__ledger-head">
            <div>
                <h2 id="eventLedgerTitle">Visit event ledger</h2>
                <p>Every retained field for each counted visit, newest first. Locations are approximate GeoIP estimates; times use your current time zone.</p>
            </div>
            <form id="eventSearchForm" class="developer-analytics__event-search" role="search">
                <label class="sr-only" for="eventSearchInput">Filter visit events</label>
                <input id="eventSearchInput" type="search" maxlength="120"
                       placeholder="Filter any recorded field" autocomplete="off">
                <button type="submit">Filter</button>
                <button id="eventSearchClear" type="button">Clear</button>
            </form>
        </div>
        <div class="developer-analytics__table-wrap">
            <table class="developer-analytics__event-table">
                <thead><tr>
                    <th scope="col">Time</th><th scope="col">Visit</th><th scope="col">Visitor ID</th>
                    <th scope="col">IP address</th><th scope="col">Approximate location</th>
                    <th scope="col">Accuracy</th><th scope="col">Registered network</th>
                    <th scope="col">Client</th><th scope="col">Language</th>
                    <th scope="col">UA fingerprint</th><th scope="col">Page</th>
                </tr></thead>
                <tbody id="eventRows"><tr><td colspan="11">Loading the protected visit ledger…</td></tr></tbody>
            </table>
        </div>
        <footer class="developer-analytics__ledger-footer">
            <p id="eventLedgerStatus" aria-live="polite">Loading retained events…</p>
            <div class="developer-analytics__pager" aria-label="Visit ledger pages">
                <button id="eventPrevious" type="button" disabled>Previous</button>
                <span id="eventPageLabel">—</span>
                <button id="eventNext" type="button" disabled>Next</button>
            </div>
        </footer>
    </section>

    <section class="developer-analytics__panel developer-analytics__visitor-panel" aria-labelledby="visitorTitle">
        <div class="developer-analytics__panel-head">
            <div><h2 id="visitorTitle">Returning visitor history</h2><p>Select a visitor to inspect each numbered return.</p></div>
            <span id="visitorTimeZone">Local time</span>
        </div>
        <div class="developer-analytics__table-wrap">
            <table class="developer-analytics__visitor-table">
                <thead><tr><th scope="col">Visitor</th><th scope="col">Location</th><th scope="col">Client</th><th scope="col">Visits</th><th scope="col">First seen</th><th scope="col">Last seen</th><th scope="col">Last page</th><th scope="col"><span class="sr-only">History</span></th></tr></thead>
                <tbody id="visitorRows"><tr><td colspan="8">Loading protected visitor history…</td></tr></tbody>
            </table>
        </div>
    </section>

    <div class="developer-analytics__table-grid">
        <section class="developer-analytics__panel" aria-labelledby="recentTitle">
            <div class="developer-analytics__panel-head"><div><h2 id="recentTitle">Countries by visits</h2><p>Mapped country-level totals.</p></div><span id="recentRange"></span></div>
            <div class="developer-analytics__table-wrap"><table><thead><tr><th>Country</th><th>Code</th><th>Visits</th></tr></thead><tbody id="recentRows"><tr><td colspan="3">Loading private analytics…</td></tr></tbody></table></div>
        </section>
        <section class="developer-analytics__panel" aria-labelledby="allTimeTitle">
            <div class="developer-analytics__panel-head"><div><h2 id="allTimeTitle">Country history</h2><p>Mapped visits since collection began.</p></div><span>All time</span></div>
            <div class="developer-analytics__table-wrap"><table><thead><tr><th>Country</th><th>Code</th><th>Visits</th></tr></thead><tbody id="allTimeRows"><tr><td colspan="3">Loading private analytics…</td></tr></tbody></table></div>
        </section>
    </div>
    <p id="analyticsStatus" class="developer-analytics__status" aria-live="polite"></p>
</main>
<script src="lib/leaflet/leaflet.js?v=1.9.4"></script>
<script src="lib/topojson-client.min.js?v=3.1.0"></script>
<script src="JS/country-traffic.js?v=20260810b"></script>
</body>
</html>
