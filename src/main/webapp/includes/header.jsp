<%-- Canonical site header. Keep navigation changes here so every JSP stays in sync. --%>
<%
    String scsaidPath = request.getRequestURI();
    String scsaidContext = request.getContextPath();
    String scsaidRelativePath = scsaidPath.substring(Math.min(scsaidContext.length(), scsaidPath.length()));
    boolean scsaidHome = scsaidRelativePath.equals("/") || scsaidRelativePath.endsWith("/index.jsp");
    boolean scsaidBrowse = scsaidRelativePath.endsWith("/browse.jsp")
            || scsaidRelativePath.endsWith("/details.jsp")
            || scsaidRelativePath.endsWith("/visualization.jsp");
    boolean scsaidSearch = scsaidRelativePath.endsWith("/gene-search.jsp")
            || scsaidRelativePath.startsWith("/gene-details");
    boolean scsaidExpression = scsaidRelativePath.endsWith("/featureplot.jsp");
    boolean scsaidCompare = scsaidRelativePath.endsWith("/compare.jsp");
    boolean scsaidNavigate = scsaidSearch || scsaidCompare;
    boolean scsaidDownload = scsaidRelativePath.endsWith("/download.jsp");
    boolean scsaidHelp = scsaidRelativePath.startsWith("/help");
    boolean scsaidCite = scsaidRelativePath.endsWith("/cite.jsp");
    boolean scsaidWhatsNew = scsaidRelativePath.endsWith("/whats-new.jsp");
    boolean scsaidAbout = scsaidCite || scsaidWhatsNew;
    boolean scsaidFeedback = scsaidRelativePath.startsWith("/feedback")
            || scsaidRelativePath.startsWith("/contact");
%>
<a class="skip-link" href="#main-content">Skip to main content</a>
<header class="site-header">
    <div class="container">
        <a href="index.jsp" class="site-logo" aria-label="scSAID home">scSAID</a>

        <nav class="main-nav" id="site-navigation" aria-label="Primary navigation">
            <div class="nav-drawer__header">
                <span class="nav-drawer__title">Menu</span>
                <button class="nav-drawer__close" type="button" aria-label="Close navigation menu">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <a href="index.jsp" class="main-nav__link<%= scsaidHome ? " main-nav__link--active" : "" %>"<%= scsaidHome ? " aria-current=\"page\"" : "" %>>Home</a>
            <a href="browse.jsp" class="main-nav__link<%= scsaidBrowse ? " main-nav__link--active" : "" %>"<%= scsaidBrowse ? " aria-current=\"page\"" : "" %>>Browse</a>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidNavigate ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="navigate-menu">Navigate</button>
                <div class="main-nav__dropdown main-nav__dropdown--navigate" id="navigate-menu" role="menu" aria-label="Navigate">
                    <a href="gene-search.jsp" class="main-nav__dropdown-link<%= scsaidSearch ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidSearch ? " aria-current=\"page\"" : "" %>>Search DEGs</a>
                    <a href="compare.jsp" class="main-nav__dropdown-link<%= scsaidCompare ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidCompare ? " aria-current=\"page\"" : "" %>>Compare conditions</a>
                </div>
            </div>
            <a href="featureplot.jsp" class="main-nav__link<%= scsaidExpression ? " main-nav__link--active" : "" %>"<%= scsaidExpression ? " aria-current=\"page\"" : "" %>>Expression</a>
            <a href="download.jsp" class="main-nav__link<%= scsaidDownload ? " main-nav__link--active" : "" %>"<%= scsaidDownload ? " aria-current=\"page\"" : "" %>>Download</a>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidHelp ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="help-menu">Help</button>
                <div class="main-nav__dropdown main-nav__dropdown--help" id="help-menu" role="menu" aria-label="Help topics">
                    <a href="help?topic=faq" class="main-nav__dropdown-link" role="menuitem">FAQ</a>
                    <a href="help?topic=methods" class="main-nav__dropdown-link" role="menuitem">Methods</a>
                    <a href="help?topic=markers" class="main-nav__dropdown-link" role="menuitem">Markers</a>
                    <a href="help?topic=pipeline" class="main-nav__dropdown-link" role="menuitem">Pipeline</a>
                    <a href="help?topic=usage" class="main-nav__dropdown-link" role="menuitem">Usage</a>
                </div>
            </div>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidAbout ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="about-menu">About</button>
                <div class="main-nav__dropdown main-nav__dropdown--about" id="about-menu" role="menu" aria-label="About">
                    <a href="cite.jsp" class="main-nav__dropdown-link<%= scsaidCite ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidCite ? " aria-current=\"page\"" : "" %>>How to Cite</a>
                    <a href="whats-new.jsp" class="main-nav__dropdown-link<%= scsaidWhatsNew ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidWhatsNew ? " aria-current=\"page\"" : "" %>>What’s New</a>
                </div>
            </div>
            <a href="feedback" class="main-nav__link<%= scsaidFeedback ? " main-nav__link--active" : "" %>"<%= scsaidFeedback ? " aria-current=\"page\"" : "" %>>Feedback</a>
        </nav>

        <div class="header-actions">
            <form class="site-search" role="search" action="<%= scsaidContext %>/site-search" method="get" autocomplete="off">
                <label class="site-search__label" for="site-search-input">Search site functions and datasets</label>
                <div class="site-search__control">
                    <svg class="site-search__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true" focusable="false">
                        <circle cx="11" cy="11" r="7"></circle>
                        <path d="m20 20-4-4"></path>
                    </svg>
                    <input id="site-search-input" class="site-search__input" type="search" name="q" placeholder="Search functions or datasets" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="site-search-results" aria-describedby="site-search-hint">
                    <button class="site-search__submit" type="submit" aria-label="Open first search result">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true" focusable="false">
                            <path d="m9 18 6-6-6-6"></path>
                        </svg>
                    </button>
                </div>
                <span id="site-search-hint" class="site-search__label">Search by function, SAID, GSM, or GSE accession</span>
                <div class="site-search__panel" hidden>
                    <p class="site-search__status" role="status" aria-live="polite"></p>
                    <ul class="site-search__results" id="site-search-results" role="listbox"></ul>
                </div>
            </form>
            <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="site-navigation" aria-label="Open navigation menu">
                <span class="nav-toggle__line" aria-hidden="true"></span>
                <span class="nav-toggle__line" aria-hidden="true"></span>
                <span class="nav-toggle__line" aria-hidden="true"></span>
            </button>
        </div>
    </div>
</header>
<button class="nav-backdrop" type="button" aria-label="Close navigation menu" tabindex="-1"></button>
<script src="JS/site-header.js?v=20260702e" defer></script>
<script src="JS/analysis-help.js?v=20260702a" defer></script>
