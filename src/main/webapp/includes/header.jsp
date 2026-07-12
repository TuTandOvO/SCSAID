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
    boolean scsaidDegSearch = scsaidRelativePath.endsWith("/deg-search.jsp");
    boolean scsaidExpression = scsaidRelativePath.endsWith("/featureplot.jsp");
    boolean scsaidCompare = scsaidRelativePath.endsWith("/compare.jsp");
    boolean scsaidPsoSpotter = scsaidRelativePath.endsWith("/psospotter.jsp");
    boolean scsaidNavigate = scsaidSearch || scsaidDegSearch || scsaidCompare || scsaidExpression;
    scsaidNavigate = scsaidNavigate || scsaidPsoSpotter;
    boolean scsaidDownload = scsaidRelativePath.endsWith("/download.jsp");
    boolean scsaidHelp = scsaidRelativePath.startsWith("/help");
    boolean scsaidCite = scsaidRelativePath.endsWith("/cite.jsp");
    boolean scsaidWhatsNew = scsaidRelativePath.endsWith("/whats-new.jsp");
    boolean scsaidFeedback = scsaidRelativePath.startsWith("/feedback")
            || scsaidRelativePath.startsWith("/contact");
    boolean scsaidAbout = scsaidCite || scsaidWhatsNew || scsaidFeedback;
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
                    <a href="gene-search.jsp" class="main-nav__dropdown-link<%= scsaidSearch ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidSearch ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--search" aria-hidden="true"></span><span>Search Marker</span></a>
                    <a href="deg-search.jsp" class="main-nav__dropdown-link<%= scsaidDegSearch ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidDegSearch ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--deg" aria-hidden="true"></span><span>Search DEG</span></a>
                    <a href="compare.jsp" class="main-nav__dropdown-link<%= scsaidCompare ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidCompare ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--compare" aria-hidden="true"></span><span>Compare conditions</span></a>
                    <a href="featureplot.jsp" class="main-nav__dropdown-link<%= scsaidExpression ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidExpression ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--expression" aria-hidden="true"></span><span>Expression</span></a>
                    <a href="psospotter.jsp" class="main-nav__dropdown-link<%= scsaidPsoSpotter ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidPsoSpotter ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--psospotter" aria-hidden="true"></span><span>psoSpotter</span><span class="main-nav__badge">beta</span></a>
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
                    <a href="feedback" class="main-nav__dropdown-link<%= scsaidFeedback ? " main-nav__dropdown-link--active" : "" %>" role="menuitem"<%= scsaidFeedback ? " aria-current=\"page\"" : "" %>><span class="main-nav__dropdown-icon main-nav__dropdown-icon--feedback" aria-hidden="true"></span><span>Feedback</span></a>
                    <button type="button" class="main-nav__dropdown-link" role="menuitem" data-newsletter-open><span class="main-nav__dropdown-icon main-nav__dropdown-icon--newsletter" aria-hidden="true"></span><span>Subscribe to updates</span></button>
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
                    <input id="site-search-input" class="site-search__input" type="search" name="q" placeholder="Search anything" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="site-search-results" aria-describedby="site-search-hint">
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
        scSAID uses first-party cookies for secure sessions and visit counting, and local storage to remember interface preferences. MapMyVisitors visitor analytics is enabled and receives a visit request to provide the public visitor map and its owner dashboard. We do not use advertising or third-party tracking cookies.
    </p>
    <button class="storage-notice__dismiss" id="storage-notice-dismiss" type="button">Close</button>
</aside>
<link rel="stylesheet" href="CSS/newsletter-modal.css?v=20260704b">
<div class="nl-modal-overlay" id="newsletterModal" role="dialog" aria-modal="true" aria-labelledby="newsletterModalTitle" hidden>
    <div class="nl-modal" role="document">
        <button type="button" class="nl-modal__close" data-newsletter-close aria-label="Close subscribe dialog">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
        </button>

        <div data-newsletter-formview>
            <div class="nl-modal__header">
                <span class="nl-modal__icon" aria-hidden="true">
                    <svg viewBox="0 0 256 256" fill="currentColor"><path d="M224,48H32a8,8,0,0,0-8,8V192a16,16,0,0,0,16,16H216a16,16,0,0,0,16-16V56A8,8,0,0,0,224,48ZM98.71,128,40,181.81V74.19Zm11.84,10.85,12,11.05a8,8,0,0,0,10.82,0l12-11.05,58,53.15H52.53ZM157.29,128,216,74.18V181.82Z"/></svg>
                </span>
                <h2 class="nl-modal__title" id="newsletterModalTitle">Subscribe for updates</h2>
            </div>
            <div class="nl-modal__body">
                <p class="nl-modal__lead">Sign up for updates to the <strong>scSAID</strong> platform.</p>
                <p class="nl-modal__lead">We'll inform you periodically when a scSAID dataset or exciting new features are added.</p>
                <form id="newsletterForm" class="nl-form"
                      action="https://buttondown.com/api/emails/embed-subscribe/ethan-scsaid"
                      method="post" target="nl-buttondown-sink">
                    <div class="nl-form__field">
                        <label class="nl-form__label" for="nl-email">Email address</label>
                        <input class="nl-form__input" type="email" id="nl-email" name="email"
                               placeholder="you@example.com" autocomplete="email" required>
                    </div>
                    <input type="hidden" name="embed" value="1">
                    <button type="submit" class="nl-form__submit">Subscribe</button>
                </form>
                <p class="nl-modal__confirm-note">Please confirm your subscription from the email we sent, or you won’t receive future notifications.</p>
            </div>
        </div>

        <div class="nl-modal__body" data-newsletter-success hidden>
            <div class="nl-modal__success">
                <span class="nl-modal__success-icon" aria-hidden="true">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
                </span>
                <h2 class="nl-modal__success-title">Almost there!</h2>
                <p class="nl-modal__success-text">Thanks for subscribing. Please check your inbox for a confirmation email to complete your signup.</p>
                <button type="button" class="nl-form__submit" style="margin-top:1.25rem;" data-newsletter-close data-newsletter-done>Done</button>
            </div>
        </div>
    </div>
</div>
<iframe name="nl-buttondown-sink" title="Subscription handler" aria-hidden="true" tabindex="-1" style="position:absolute;width:0;height:0;border:0;left:-9999px;" src="about:blank"></iframe>
<script src="JS/site-preferences.js?v=20260703d"></script>
<script src="JS/site-header.js?v=20260702e" defer></script>
<script src="JS/newsletter-modal.js?v=20260704a" defer></script>
<script src="JS/analysis-help.js?v=20260702a" defer></script>
<script type="text/javascript" id="mapmyvisitors" src="//mapmyvisitors.com/map.js?d=FceBPIpTNKr7fyBoiQjL-qoD1MRcySwmXIUGnxPMY2c&cl=ffffff&w=a"></script>
