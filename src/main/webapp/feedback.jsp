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
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css?v=20260702p">
    <link rel="stylesheet" href="CSS/header.css?v=20260703d">

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
            padding-top: var(--header-height);
        }

        .page-header {
            background: var(--color-primary);
            padding: clamp(3rem, 9vh, 4.5rem) 0;
            text-align: center;
        }

        .page-header__content {
            max-width: 800px;
            margin: 0 auto;
            padding: 0 clamp(1rem, 4vw, 2rem);
        }

        .page-header__eyebrow {
            display: inline-block;
            font-size: 0.75rem;
            font-weight: 300;
            letter-spacing: 0.15em;
            text-transform: uppercase;
            color: var(--color-accent);
            margin-bottom: 1.5rem;
        }

        .page-header__title {
            font-family: var(--font-display);
            font-size: clamp(2.5rem, 5vw, 3.5rem);
            font-weight: 300;
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
            padding: 3rem clamp(1rem, 4vw, 2rem) 4rem;
        }

        .feedback-card {
            background: var(--bg-surface);
            border-radius: 16px;
            box-shadow: var(--shadow-md);
            padding: 2rem;
        }

        .feedback-iframe {
            width: 100%;
            height: clamp(42rem, calc(100dvh - 7rem), 68.75rem);
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
            max-width: 100%;
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
                height: clamp(42rem, calc(100dvh - 6rem), 68.75rem);
            }
        }

        @media (max-width: 420px) {
            .feedback-content { padding: 1rem 0.5rem 2rem; }
            .feedback-card { padding: 0.75rem; border-radius: 12px; }
            .feedback-gate { padding: 2rem 0; overflow-x: auto; }
            .feedback-fallback .btn { white-space: normal; }
        }
    </style>
</head>
<body>

<%@ include file="includes/header.jsp" %>

<main class="feedback-page" id="main-content" tabindex="-1">
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


<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
