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

        <svg class="site-icon-sprite" aria-hidden="true" focusable="false">
            <symbol id="nav-icon-home" viewBox="0 0 24 24">
                <path d="M3.5 10.5 12 3.75l8.5 6.75"></path>
                <path d="M5.5 9.25V20h13V9.25M9.5 20v-6h5v6"></path>
            </symbol>
            <symbol id="nav-icon-browse" viewBox="0 0 24 24">
                <ellipse cx="12" cy="5.5" rx="7.5" ry="2.75"></ellipse>
                <path d="M4.5 5.5v6c0 1.52 3.36 2.75 7.5 2.75s7.5-1.23 7.5-2.75v-6"></path>
                <path d="M4.5 11.5v6c0 1.52 3.36 2.75 7.5 2.75s7.5-1.23 7.5-2.75v-6"></path>
            </symbol>
            <symbol id="nav-icon-navigate" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="8.75"></circle>
                <path d="m15.75 8.25-2.1 5.4-5.4 2.1 2.1-5.4 5.4-2.1Z"></path>
            </symbol>
            <symbol id="nav-icon-expression" viewBox="0 0 24 24">
                <path d="M4 19.5h16M4.5 19V5"></path>
                <path d="m6.5 15 3.25-4 3 2.5 4.75-6"></path>
                <circle cx="6.5" cy="15" r="1"></circle>
                <circle cx="9.75" cy="11" r="1"></circle>
                <circle cx="12.75" cy="13.5" r="1"></circle>
                <circle cx="17.5" cy="7.5" r="1"></circle>
            </symbol>
            <symbol id="nav-icon-download" viewBox="0 0 24 24">
                <path d="M12 3.5v11"></path>
                <path d="m8 10.5 4 4 4-4"></path>
                <path d="M4.5 16.5V20h15v-3.5"></path>
            </symbol>
            <symbol id="nav-icon-help" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="8.75"></circle>
                <path d="M9.75 9a2.35 2.35 0 1 1 3.42 2.1c-.82.42-1.17.87-1.17 1.65v.5"></path>
                <circle cx="12" cy="16.75" r=".75" fill="currentColor" stroke="none"></circle>
            </symbol>
            <symbol id="nav-icon-about" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="8.75"></circle>
                <path d="M12 10.75v6"></path>
                <circle cx="12" cy="7.25" r=".75" fill="currentColor" stroke="none"></circle>
            </symbol>
            <symbol id="nav-icon-feedback" viewBox="0 0 24 24">
                <path d="M5 5.25h14a2 2 0 0 1 2 2v8.5a2 2 0 0 1-2 2h-7.5L7 21v-3.25H5a2 2 0 0 1-2-2v-8.5a2 2 0 0 1 2-2Z"></path>
                <path d="M7.5 9.25h9M7.5 13h6"></path>
            </symbol>
        </svg>

        <nav class="main-nav" id="site-navigation" aria-label="Primary navigation">
            <div class="nav-drawer__header">
                <span class="nav-drawer__title">Menu</span>
                <button class="nav-drawer__close" type="button" aria-label="Close navigation menu">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <a href="index.jsp" class="main-nav__link<%= scsaidHome ? " main-nav__link--active" : "" %>"<%= scsaidHome ? " aria-current=\"page\"" : "" %>><svg class="main-nav__icon" aria-hidden="true"><use href="#nav-icon-home"></use></svg><span>Home</span></a>
            <a href="browse.jsp" class="main-nav__link<%= scsaidBrowse ? " main-nav__link--active" : "" %>"<%= scsaidBrowse ? " aria-current=\"page\"" : "" %>><svg class="main-nav__icon" aria-hidden="true"><use href="#nav-icon-browse"></use></svg><span>Browse</span></a>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidNavigate ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="navigate-menu"><span class="main-nav__label"><svg class="main-nav__icon" aria-hidden="true"><use href="#nav-icon-navigate"></use></svg><span>Navigate</span></span></button>
                <div class="main-nav__dropdown main-nav__dropdown--navigate" id="navigate-menu" role="menu" aria-label="Navigate">
                    <a href="gene-search.jsp" class="main-nav__dropdown-link<%= scsaidSearch ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidSearch ? " aria-current=\"page\"" : "" %>>Search DEGs</a>
                    <a href="compare.jsp" class="main-nav__dropdown-link<%= scsaidCompare ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidCompare ? " aria-current=\"page\"" : "" %>>Compare conditions</a>
                </div>
            </div>
            <a href="featureplot.jsp" class="main-nav__link<%= scsaidExpression ? " main-nav__link--active" : "" %>"<%= scsaidExpression ? " aria-current=\"page\"" : "" %>><svg class="main-nav__icon" aria-hidden="true"><use href="#nav-icon-expression"></use></svg><span>Expression</span></a>
            <a href="download.jsp" class="main-nav__link<%= scsaidDownload ? " main-nav__link--active" : "" %>"<%= scsaidDownload ? " aria-current=\"page\"" : "" %>><svg class="main-nav__icon" aria-hidden="true"><use href="#nav-icon-download"></use></svg><span>Download</span></a>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidHelp ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="help-menu"><span class="main-nav__label"><svg class="main-nav__icon" aria-hidden="true"><use href="#nav-icon-help"></use></svg><span>Help</span></span></button>
                <div class="main-nav__dropdown main-nav__dropdown--help" id="help-menu" role="menu" aria-label="Help topics">
                    <a href="help?topic=faq" class="main-nav__dropdown-link" role="menuitem">FAQ</a>
                    <a href="help?topic=methods" class="main-nav__dropdown-link" role="menuitem">Methods</a>
                    <a href="help?topic=markers" class="main-nav__dropdown-link" role="menuitem">Markers</a>
                    <a href="help?topic=pipeline" class="main-nav__dropdown-link" role="menuitem">Pipeline</a>
                    <a href="help?topic=usage" class="main-nav__dropdown-link" role="menuitem">Usage</a>
                </div>
            </div>
            <div class="main-nav__item">
                <button type="button" class="main-nav__link main-nav__menu-toggle<%= scsaidAbout ? " main-nav__link--active" : "" %>" aria-haspopup="true" aria-expanded="false" aria-controls="about-menu"><span class="main-nav__label"><svg class="main-nav__icon" aria-hidden="true"><use href="#nav-icon-about"></use></svg><span>About</span></span></button>
                <div class="main-nav__dropdown main-nav__dropdown--about" id="about-menu" role="menu" aria-label="About">
                    <a href="cite.jsp" class="main-nav__dropdown-link<%= scsaidCite ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidCite ? " aria-current=\"page\"" : "" %>>How to Cite</a>
                    <a href="whats-new.jsp" class="main-nav__dropdown-link<%= scsaidWhatsNew ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidWhatsNew ? " aria-current=\"page\"" : "" %>>What’s New</a>
                </div>
            </div>
            <a href="feedback" class="main-nav__link<%= scsaidFeedback ? " main-nav__link--active" : "" %>"<%= scsaidFeedback ? " aria-current=\"page\"" : "" %>><svg class="main-nav__icon" aria-hidden="true"><use href="#nav-icon-feedback"></use></svg><span>Feedback</span></a>
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
