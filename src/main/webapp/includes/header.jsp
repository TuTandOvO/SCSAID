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
    boolean scsaidDownload = scsaidRelativePath.endsWith("/download.jsp");
    boolean scsaidHelp = scsaidRelativePath.startsWith("/help");
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
            <a href="gene-search.jsp" class="main-nav__link<%= scsaidSearch ? " main-nav__link--active" : "" %>"<%= scsaidSearch ? " aria-current=\"page\"" : "" %>>Search</a>
            <a href="featureplot.jsp" class="main-nav__link<%= scsaidExpression ? " main-nav__link--active" : "" %>"<%= scsaidExpression ? " aria-current=\"page\"" : "" %>>Expression</a>
            <a href="compare.jsp" class="main-nav__link<%= scsaidCompare ? " main-nav__link--active" : "" %>"<%= scsaidCompare ? " aria-current=\"page\"" : "" %>>Compare</a>
            <a href="download.jsp" class="main-nav__link<%= scsaidDownload ? " main-nav__link--active" : "" %>"<%= scsaidDownload ? " aria-current=\"page\"" : "" %>>Download</a>
            <div class="main-nav__item">
                <a href="help?topic=faq" class="main-nav__link<%= scsaidHelp ? " main-nav__link--active" : "" %>"<%= scsaidHelp ? " aria-current=\"page\"" : "" %>>Help</a>
                <div class="main-nav__dropdown" aria-label="Help topics">
                    <a href="help?topic=faq" class="main-nav__dropdown-link">FAQ</a>
                    <a href="help?topic=methods" class="main-nav__dropdown-link">Methods</a>
                    <a href="help?topic=markers" class="main-nav__dropdown-link">Markers</a>
                    <a href="help?topic=pipeline" class="main-nav__dropdown-link">Pipeline</a>
                    <a href="help?topic=usage" class="main-nav__dropdown-link">Usage</a>
                </div>
            </div>
            <a href="feedback" class="main-nav__link<%= scsaidFeedback ? " main-nav__link--active" : "" %>"<%= scsaidFeedback ? " aria-current=\"page\"" : "" %>>Feedback</a>
        </nav>

        <div class="header-actions">
            <div class="header-icons" aria-label="External links">
                <a href="https://github.com/TuTandOvO/SCSAID" target="_blank" rel="noopener noreferrer" class="header-icon-link" aria-label="View scSAID on GitHub">
                    <svg class="github-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false">
                        <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                    </svg>
                </a>
                <a href="https://zje.zju.edu.cn/zje/main.htm" target="_blank" rel="noopener noreferrer" class="header-icon-link" aria-label="Zhejiang University International Campus">
                    <img src="images/ZJE_Logo.png" alt="" class="university-logo" width="31" height="24">
                </a>
            </div>
            <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="site-navigation" aria-label="Open navigation menu">
                <span class="nav-toggle__line" aria-hidden="true"></span>
                <span class="nav-toggle__line" aria-hidden="true"></span>
                <span class="nav-toggle__line" aria-hidden="true"></span>
            </button>
        </div>
    </div>
</header>
<button class="nav-backdrop" type="button" aria-label="Close navigation menu" tabindex="-1"></button>
<script src="JS/site-header.js?v=20260701" defer></script>
