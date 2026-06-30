<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%
    String turnstileSiteKey = (String) request.getAttribute("turnstileSiteKey");
    if (turnstileSiteKey == null) turnstileSiteKey = "";
    boolean gateEnabled = !turnstileSiteKey.isEmpty();
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Feedback - scSAID</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css?v=20260624">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/construction-modal-simple.css">

    <% if (gateEnabled) { %>
    <!-- Cloudflare Turnstile (gates the feedback form against over-submission) -->
    <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
    <% } %>

    <style>
        body {
            background-color: var(--bg-body);
        }

        .feedback-page {
            min-height: 100vh;
            padding-top: 72px;
        }

        .page-header {
            background: var(--color-primary);
            padding: 4.5rem 0;
            text-align: center;
        }

        .page-header__content {
            max-width: 800px;
            margin: 0 auto;
            padding: 0 2rem;
        }

        .page-header__eyebrow {
            display: inline-block;
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 0.15em;
            text-transform: uppercase;
            color: var(--color-accent);
            margin-bottom: 1.5rem;
        }

        .page-header__title {
            font-family: var(--font-display);
            font-size: clamp(2.5rem, 5vw, 3.5rem);
            font-weight: 500;
            color: var(--text-inverse);
            margin: 0 0 1rem;
        }

        .page-header__description {
            font-size: 1.15rem;
            color: rgba(255, 255, 255, 0.75);
            margin: 0;
            line-height: 1.7;
        }

        .feedback-content {
            max-width: 1200px;
            margin: 0 auto;
            padding: 3rem 2rem 4rem;
        }

        .feedback-card {
            background: var(--bg-surface);
            border-radius: 16px;
            box-shadow: var(--shadow-md);
            padding: 2rem;
        }

        .feedback-iframe {
            width: 100%;
            height: 1100px;
            border: 0;
            border-radius: 12px;
        }

        .feedback-fallback {
            margin-top: 1.5rem;
            text-align: center;
        }

        .feedback-gate {
            text-align: center;
            padding: 3rem 1rem;
        }

        .feedback-gate__title {
            font-family: var(--font-display);
            font-size: 1.75rem;
            color: var(--text-primary);
            margin: 0 0 0.5rem;
        }

        .feedback-gate__hint {
            color: var(--text-secondary);
            margin: 0 0 1.5rem;
            font-size: 0.95rem;
        }

        .cf-turnstile {
            display: inline-block;
        }

        .feedback-gate__error {
            color: var(--color-danger);
            margin-top: 1rem;
            min-height: 1.2em;
            font-size: 0.9rem;
        }

        .is-hidden {
            display: none !important;
        }

        @media (max-width: 768px) {
            .page-header {
                padding: 3.5rem 0;
            }

            .feedback-content {
                padding: 2.5rem 1.25rem 3rem;
            }

            .feedback-card {
                padding: 1.25rem;
            }

            .feedback-iframe {
                height: 1350px;
            }
        }
    </style>
</head>
<body>

<!-- Header -->
<header class="site-header">
    <div class="container">
        <a href="index.jsp" class="site-logo">scSAID</a>
        <nav class="main-nav">
            <a href="index.jsp" class="main-nav__link">Home</a>
            <a href="browse.jsp" class="main-nav__link">Browse</a>
            <a href="gene-search.jsp" class="main-nav__link">Search</a>
            <a href="featureplot.jsp" class="main-nav__link">Expression</a>
            <a href="download.jsp" class="main-nav__link">Download</a>
            <div class="main-nav__item">
                <a href="help?topic=faq" class="main-nav__link">Help</a>
                <div class="main-nav__dropdown">
                    <a href="help?topic=faq" class="main-nav__dropdown-link">FAQ</a>
                    <a href="help?topic=methods" class="main-nav__dropdown-link">Methods</a>
                    <a href="help?topic=markers" class="main-nav__dropdown-link">Markers</a>
                    <a href="help?topic=pipeline" class="main-nav__dropdown-link">Pipeline</a>
                    <a href="help?topic=usage" class="main-nav__dropdown-link">Usage</a>
                </div>
            </div>
            <a href="feedback" class="main-nav__link main-nav__link--active">Feedback</a>
            <a href="contact" class="main-nav__link">Contact</a>
        </nav>
        <div class="header-icons">
            <a href="https://github.com/Dostoyevsky7/SkinDB_web" target="_blank" class="header-icon-link" title="View on GitHub">
                <svg class="github-icon" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                </svg>
            </a>
            <a href="https://zje.zju.edu.cn/zje/main.htm" target="_blank" class="header-icon-link" title="ZJE - Zhejiang University">
                <img src="images/ZJE_Logo.png" alt="ZJE - Zhejiang University" class="university-logo">
            </a>
        </div>
    </div>
</header>

<main class="feedback-page">
    <div class="page-header">
        <div class="page-header__content">
            <span class="page-header__eyebrow">Community</span>
            <h1 class="page-header__title">Feedback</h1>
            <p class="page-header__description">
                Tell us what you think. Your feedback helps us improve.
            </p>
        </div>
    </div>

    <div class="feedback-content">
        <div class="feedback-card">
            <% if (gateEnabled) { %>
            <!-- Verification gate: the form is revealed only after Turnstile passes -->
            <div id="feedbackGate" class="feedback-gate">
                <h2 class="feedback-gate__title">Quick check before you continue</h2>
                <p class="feedback-gate__hint">Please confirm you're human to open the feedback form.</p>
                <div class="cf-turnstile"
                     data-sitekey="<%= turnstileSiteKey %>"
                     data-callback="onTurnstileSuccess"
                     data-error-callback="onTurnstileError"
                     data-expired-callback="onTurnstileExpired"></div>
                <div id="feedbackGateError" class="feedback-gate__error"></div>
            </div>
            <% } %>

            <iframe
                    id="feedbackIframe"
                    class="feedback-iframe<%= gateEnabled ? " is-hidden" : "" %>"
                    title="Feedback form"
                    data-src="https://docs.google.com/forms/d/e/1FAIpQLSflIMVjxnvApZ7I0uUwPdvt9_C7self4p-a3K2NoC6T8YLgLg/viewform?embedded=true"
                    <% if (!gateEnabled) { %>src="https://docs.google.com/forms/d/e/1FAIpQLSflIMVjxnvApZ7I0uUwPdvt9_C7self4p-a3K2NoC6T8YLgLg/viewform?embedded=true"<% } %>
                    loading="lazy"
            ></iframe>

            <div class="feedback-fallback<%= gateEnabled ? " is-hidden" : "" %>" id="feedbackFallback">
                <a
                        class="btn btn--outline"
                        href="https://docs.google.com/forms/d/e/1FAIpQLSflIMVjxnvApZ7I0uUwPdvt9_C7self4p-a3K2NoC6T8YLgLg/viewform?usp=dialog"
                        target="_blank"
                        rel="noopener noreferrer"
                >
                    Open the feedback form in a new tab
                </a>
            </div>
        </div>
    </div>
</main>

<% if (gateEnabled) { %>
<script>
    (function () {
        function revealForm() {
            var iframe = document.getElementById('feedbackIframe');
            if (iframe && !iframe.src) {
                iframe.src = iframe.getAttribute('data-src');
            }
            iframe && iframe.classList.remove('is-hidden');
            var gate = document.getElementById('feedbackGate');
            gate && gate.classList.add('is-hidden');
            var fallback = document.getElementById('feedbackFallback');
            fallback && fallback.classList.remove('is-hidden');
        }

        function showError(msg) {
            var el = document.getElementById('feedbackGateError');
            if (el) el.textContent = msg;
        }

        window.onTurnstileSuccess = function (token) {
            showError('');
            var body = 'cf-turnstile-response=' + encodeURIComponent(token);
            fetch('feedback', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: body
            }).then(function (r) {
                return r.json().catch(function () { return { ok: false }; });
            }).then(function (data) {
                if (data && data.ok) {
                    revealForm();
                } else if (data && data.error === 'rate_limited') {
                    showError('Too many attempts. Please wait a minute and try again.');
                } else {
                    showError('Verification failed. Please try again.');
                    if (window.turnstile) window.turnstile.reset();
                }
            }).catch(function () {
                showError('Network error during verification. Please try again.');
            });
        };

        window.onTurnstileError = function () {
            showError('Could not load the verification widget. Please refresh the page.');
        };

        window.onTurnstileExpired = function () {
            showError('Verification expired. Please complete the check again.');
        };
    })();
</script>
<% } %>

<script src="JS/construction-modal-simple.js"></script>

<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
