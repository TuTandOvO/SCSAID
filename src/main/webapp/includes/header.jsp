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
                <path fill-rule="evenodd" d="M12 2.5 2 10.6v10.9h8v-6h4v6h8V10.6L12 2.5Zm0 3.15 7 5.67v7.18h-2v-6H7v6H5v-7.18l7-5.67Z"></path>
            </symbol>
            <symbol id="nav-icon-browse" viewBox="0 0 24 24">
                <path d="M21 5.25c0 1.8-4.03 3.25-9 3.25S3 7.05 3 5.25 7.03 2 12 2s9 1.45 9 3.25Z"></path>
                <path d="M3 8.55v3.7c0 1.8 4.03 3.25 9 3.25s9-1.45 9-3.25v-3.7C18.93 10.08 15.48 11 12 11s-6.93-.92-9-2.45Z"></path>
                <path d="M3 15.55v3.2C3 20.55 7.03 22 12 22s9-1.45 9-3.25v-3.2C18.93 17.08 15.48 18 12 18s-6.93-.92-9-2.45Z"></path>
            </symbol>
            <symbol id="nav-icon-navigate" viewBox="0 0 24 24">
                <path fill-rule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 3a7 7 0 1 1 0 14 7 7 0 0 1 0-14Z"></path>
                <path d="m17.25 6.75-3.4 7.1-7.1 3.4 3.4-7.1 7.1-3.4Z"></path>
            </symbol>
            <symbol id="nav-icon-expression" viewBox="0 0 24 24">
                <path d="M3 3h3v16h15v3H3V3Z"></path>
                <path d="M8 13h3v4H8v-4ZM13 9h3v8h-3V9ZM18 5h3v12h-3V5Z"></path>
            </symbol>
            <symbol id="nav-icon-download" viewBox="0 0 24 24">
                <path d="M10 2h4v9h4l-6 6-6-6h4V2ZM3 18h5v2h8v-2h5v4H3v-4Z"></path>
            </symbol>
            <symbol id="nav-icon-help" viewBox="0 0 24 24">
                <path fill-rule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 3a7 7 0 1 1 0 14 7 7 0 0 1 0-14Z"></path>
                <path d="M9.2 9a2.8 2.8 0 1 1 4.08 2.5c-.8.42-1.08.8-1.08 1.55v.55h-2v-.75c0-1.35.55-2.15 1.85-2.82.48-.25.75-.62.75-1.03a.8.8 0 0 0-1.6 0h-2ZM10.2 15.3h2v2h-2v-2Z"></path>
            </symbol>
            <symbol id="nav-icon-about" viewBox="0 0 24 24">
                <path fill-rule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 3a7 7 0 1 1 0 14 7 7 0 0 1 0-14Z"></path>
                <path d="M10.5 10h3v7h-3v-7ZM10.5 6.75h3v2.5h-3v-2.5Z"></path>
            </symbol>
            <symbol id="nav-icon-feedback" viewBox="0 0 24 24">
                <path fill-rule="evenodd" d="M4 3h16a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3h-7.7L6 23v-4H4a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3Zm3 5h10v2H7V8Zm0 4h7v2H7v-2Z"></path>
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
