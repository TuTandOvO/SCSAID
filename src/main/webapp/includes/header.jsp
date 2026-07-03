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
    boolean scsaidNavigate = scsaidSearch || scsaidCompare || scsaidExpression;
    boolean scsaidDownload = scsaidRelativePath.endsWith("/download.jsp");
    boolean scsaidHelp = scsaidRelativePath.startsWith("/help");
    boolean scsaidCite = scsaidRelativePath.endsWith("/cite.jsp");
    boolean scsaidWhatsNew = scsaidRelativePath.endsWith("/whats-new.jsp");
    boolean scsaidPrivacy = scsaidRelativePath.endsWith("/privacy.jsp");
    boolean scsaidFeedback = scsaidRelativePath.startsWith("/feedback")
            || scsaidRelativePath.startsWith("/contact");
    boolean scsaidAbout = scsaidCite || scsaidWhatsNew || scsaidPrivacy || scsaidFeedback;
    String scsaidHelpTopic = request.getParameter("topic");
    boolean scsaidHelpFaq = scsaidHelp && (scsaidHelpTopic == null || "faq".equals(scsaidHelpTopic));
    boolean scsaidHelpMethods = scsaidHelp && "methods".equals(scsaidHelpTopic);
    boolean scsaidHelpMarkers = scsaidHelp && "markers".equals(scsaidHelpTopic);
    boolean scsaidHelpPipeline = scsaidHelp && "pipeline".equals(scsaidHelpTopic);
    boolean scsaidHelpUsage = scsaidHelp && "usage".equals(scsaidHelpTopic);
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
            <% if (!scsaidHome) { %>
            <a href="index.jsp" class="main-nav__link"><span class="main-nav__icon main-nav__icon--home" aria-hidden="true"></span><span>Home</span></a>
            <% } %>
            <a href="browse.jsp" class="main-nav__link<%= scsaidBrowse ? " main-nav__link--active" : "" %>"<%= scsaidBrowse ? " aria-current=\"page\"" : "" %>><span class="main-nav__icon main-nav__icon--browse" aria-hidden="true"></span><span>Browse</span></a>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidNavigate ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="navigate-menu"><span class="main-nav__label"><span class="main-nav__icon main-nav__icon--navigate" aria-hidden="true"></span><span>Navigate</span></span></button>
                <div class="main-nav__dropdown main-nav__dropdown--navigate" id="navigate-menu" role="menu" aria-label="Navigate">
                    <a href="gene-search.jsp" class="main-nav__dropdown-link<%= scsaidSearch ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidSearch ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--search" aria-hidden="true"></span><span>Search DEGs</span></a>
                    <a href="compare.jsp" class="main-nav__dropdown-link<%= scsaidCompare ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidCompare ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--compare" aria-hidden="true"></span><span>Compare conditions</span></a>
                    <a href="featureplot.jsp" class="main-nav__dropdown-link<%= scsaidExpression ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidExpression ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--expression" aria-hidden="true"></span><span>Expression</span></a>
                </div>
            </div>
            <a href="download.jsp" class="main-nav__link<%= scsaidDownload ? " main-nav__link--active" : "" %>"<%= scsaidDownload ? " aria-current=\"page\"" : "" %>><span class="main-nav__icon main-nav__icon--download" aria-hidden="true"></span><span>Download</span></a>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidHelp ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="help-menu"><span class="main-nav__label"><span class="main-nav__icon main-nav__icon--help" aria-hidden="true"></span><span>Help</span></span></button>
                <div class="main-nav__dropdown main-nav__dropdown--help" id="help-menu" role="menu" aria-label="Help topics">
                    <a href="help?topic=faq" class="main-nav__dropdown-link<%= scsaidHelpFaq ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidHelpFaq ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--faq" aria-hidden="true"></span><span>FAQ</span></a>
                    <a href="help?topic=methods" class="main-nav__dropdown-link<%= scsaidHelpMethods ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidHelpMethods ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--methods" aria-hidden="true"></span><span>Methods</span></a>
                    <a href="help?topic=markers" class="main-nav__dropdown-link<%= scsaidHelpMarkers ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidHelpMarkers ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--markers" aria-hidden="true"></span><span>Markers</span></a>
                    <a href="help?topic=pipeline" class="main-nav__dropdown-link<%= scsaidHelpPipeline ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidHelpPipeline ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--pipeline" aria-hidden="true"></span><span>Pipeline</span></a>
                    <a href="help?topic=usage" class="main-nav__dropdown-link<%= scsaidHelpUsage ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidHelpUsage ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--usage" aria-hidden="true"></span><span>Usage</span></a>
                </div>
            </div>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidAbout ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="about-menu"><span class="main-nav__label"><span class="main-nav__icon main-nav__icon--about" aria-hidden="true"></span><span>About</span></span></button>
                <div class="main-nav__dropdown main-nav__dropdown--about" id="about-menu" role="menu" aria-label="About">
                    <a href="cite.jsp" class="main-nav__dropdown-link<%= scsaidCite ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidCite ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--cite" aria-hidden="true"></span><span>How to Cite</span></a>
                    <a href="whats-new.jsp" class="main-nav__dropdown-link<%= scsaidWhatsNew ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidWhatsNew ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--news" aria-hidden="true"></span><span>What’s New</span></a>
                    <a href="privacy.jsp" class="main-nav__dropdown-link<%= scsaidPrivacy ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidPrivacy ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--privacy" aria-hidden="true"></span><span>Privacy</span></a>
                    <a href="feedback" class="main-nav__dropdown-link<%= scsaidFeedback ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidFeedback ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--feedback" aria-hidden="true"></span><span>Feedback</span></a>
                </div>
            </div>
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
<aside class="storage-notice" id="storage-notice" aria-label="Privacy notice" hidden>
    <p class="storage-notice__text">
        scSAID uses first-party cookies for secure sessions and visit counting, and local storage to remember interface preferences. We do not use advertising or third-party tracking cookies.
        <a href="privacy.jsp">Privacy details</a>
    </p>
    <button class="storage-notice__dismiss" id="storage-notice-dismiss" type="button">Close</button>
</aside>
<script src="JS/site-preferences.js?v=20260703c"></script>
<script src="JS/site-header.js?v=20260702e" defer></script>
<script src="JS/analysis-help.js?v=20260702a" defer></script>
