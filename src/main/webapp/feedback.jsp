<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <!-- Favicons / PWA icons -->
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png">
    <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png">
    <link rel="icon" type="image/png" sizes="512x512" href="/images/favicon-512.png">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png">
    <link rel="manifest" href="/site.webmanifest">
    <meta name="theme-color" content="#1a2332">
    <title>Feedback &amp; Contact - scSAID</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/construction-modal-simple.css">

    <style>
        body { background-color: #faf8f5; }

        .feedback-page { min-height: 100vh; padding-top: 72px; }

        .page-header {
            background: #1a2332;
            padding: 4.5rem 0;
            text-align: center;
        }
        .page-header__content { max-width: 800px; margin: 0 auto; padding: 0 2rem; }
        .page-header__eyebrow {
            display: inline-block;
            font-size: 0.75rem; font-weight: 700; letter-spacing: 0.15em;
            text-transform: uppercase; color: #d4a574; margin-bottom: 1.5rem;
        }
        .page-header__title {
            font-family: 'Cormorant Garamond', Georgia, serif;
            font-size: clamp(2.5rem, 5vw, 3.5rem); font-weight: 500;
            color: #ffffff; margin: 0 0 1rem;
        }
        .page-header__description {
            font-size: 1.15rem; color: rgba(255,255,255,0.75);
            margin: 0; line-height: 1.7;
        }

        .feedback-content {
            max-width: 1100px;
            margin: 0 auto;
            padding: 3rem 2rem 4rem;
            display: grid;
            gap: 2rem;
        }

        .feedback-card {
            background: #ffffff;
            border-radius: 16px;
            box-shadow: 0 4px 12px rgba(26,35,50,0.08);
            padding: 2rem;
        }

        .card-eyebrow {
            font-size: 0.75rem; font-weight: 700; letter-spacing: 0.12em;
            text-transform: uppercase; color: #d4a574;
            margin: 0 0 0.35rem;
        }
        .card-title {
            font-family: 'Cormorant Garamond', Georgia, serif;
            font-size: 1.75rem; font-weight: 500; color: #1a2332;
            margin: 0 0 0.5rem;
        }
        .card-desc {
            margin: 0 0 1.25rem; color: #4b5563; line-height: 1.7;
        }

        .feedback-iframe {
            width: 100%; height: 1100px;
            border: 0; border-radius: 12px;
        }
        .feedback-fallback { margin-top: 1.25rem; text-align: center; }

        /* Contact section */
        .contact-section { margin-bottom: 1.75rem; }
        .contact-section:last-child { margin-bottom: 0; }
        .contact-section__title {
            font-size: 0.75rem; font-weight: 700; letter-spacing: 0.12em;
            text-transform: uppercase; color: #d4a574;
            margin: 0 0 0.5rem;
        }
        .contact-section__desc {
            margin: 0 0 1rem; line-height: 1.7; color: #4b5563;
        }
        .contact-person {
            display: flex; align-items: center; justify-content: space-between;
            gap: 1rem;
            padding: 0.875rem 1rem;
            border: 1px solid #e5e7eb;
            border-radius: 10px;
            margin-bottom: 0.625rem;
        }
        .contact-person:last-child { margin-bottom: 0; }
        .contact-person__info { display: flex; flex-direction: column; gap: 0.2rem; }
        .contact-person__name  { font-size: 0.9rem; font-weight: 600; color: #1a2332; }
        .contact-person__email {
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.8rem; color: #6b7280;
        }

        .btn-email {
            display: inline-flex; align-items: center; gap: 0.4rem;
            padding: 0.45rem 1rem;
            background: #1a2332; color: #ffffff;
            border: none; border-radius: 6px;
            font-size: 0.8rem; font-weight: 600; letter-spacing: 0.04em;
            cursor: pointer; text-decoration: none; white-space: nowrap;
            transition: background 0.15s;
        }
        .btn-email:hover { background: #2d3f58; color: #ffffff; text-decoration: none; }
        .btn-email svg { width: 14px; height: 14px; flex-shrink: 0; }

        .divider {
            border: none; border-top: 1px solid #e5e7eb;
            margin: 1.5rem 0;
        }

        @media (max-width: 768px) {
            .page-header { padding: 3.5rem 0; }
            .feedback-content { padding: 2.5rem 1.25rem 3rem; }
            .feedback-card { padding: 1.5rem; }
            .feedback-iframe { height: 1350px; }
        }
        @media (max-width: 600px) {
            .contact-person { flex-direction: column; align-items: flex-start; }
            .btn-email { width: 100%; justify-content: center; }
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
            <a href="featureplot.jsp" class="main-nav__link">Search</a>
            <a href="compare.jsp" class="main-nav__link">Compare</a>
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
        </nav>
        <div class="header-icons">
            <a href="https://github.com/TuTandOvO/SCSAID" target="_blank" class="header-icon-link" title="View on GitHub">
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
            <h1 class="page-header__title">Feedback &amp; Contact</h1>
            <p class="page-header__description">
                Share your thoughts through the form, or reach us directly for dataset,
                development, or publication questions.
            </p>
        </div>
    </div>

    <div class="feedback-content">

        <!-- Feedback form -->
        <section class="feedback-card">
            <p class="card-eyebrow">Feedback form</p>
            <h2 class="card-title">Tell us what you think</h2>
            <p class="card-desc">
                We read every response. Use the form below for feature requests, bug reports,
                or general comments. Prefer email? Scroll down for direct contacts.
            </p>

            <iframe
                    class="feedback-iframe"
                    title="Feedback form"
                    src="https://docs.google.com/forms/d/e/1FAIpQLSflIMVjxnvApZ7I0uUwPdvt9_C7self4p-a3K2NoC6T8YLgLg/viewform?embedded=true"
                    loading="lazy"
            ></iframe>

            <div class="feedback-fallback">
                <a
                        class="btn btn--outline"
                        href="https://docs.google.com/forms/d/e/1FAIpQLSflIMVjxnvApZ7I0uUwPdvt9_C7self4p-a3K2NoC6T8YLgLg/viewform?usp=dialog"
                        target="_blank"
                        rel="noopener noreferrer"
                >
                    Open the feedback form in a new tab
                </a>
            </div>
        </section>

        <!-- Direct contact -->
        <section class="feedback-card">
            <p class="card-eyebrow">Direct contact</p>
            <h2 class="card-title">Reach the team by email</h2>
            <p class="card-desc">
                For anything that doesn&rsquo;t fit the form &mdash; collaborations,
                dataset access, or publication inquiries &mdash; contact the relevant person below.
            </p>

            <!-- Website / development enquiries -->
            <div class="contact-section">
                <p class="contact-section__title">Website &amp; Development</p>
                <p class="contact-section__desc">
                    For website-associated matters, contact our active developers &mdash;
                    reach out to Yixiang or Ethan and cc Prof. Wang.
                </p>

                <div class="contact-person">
                    <div class="contact-person__info">
                        <span class="contact-person__name">Yixiang Ren</span>
                        <span class="contact-person__email">yixiangren99 [at] gmail [dot] com</span>
                    </div>
                    <a class="btn-email" href="mailto:yixiangren99@gmail.com?cc=ethanshen111@gmail.com,chaochenwang@intl.zju.edu.com">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                            <polyline points="22,6 12,13 2,6"/>
                        </svg>
                        Email
                    </a>
                </div>

                <div class="contact-person">
                    <div class="contact-person__info">
                        <span class="contact-person__name">Ethan Shen</span>
                        <span class="contact-person__email">ethanshen111 [at] gmail [dot] com</span>
                    </div>
                    <a class="btn-email" href="mailto:ethanshen111@gmail.com?cc=yixiangren99@gmail.com,chaochenwang@intl.zju.edu.com">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                            <polyline points="22,6 12,13 2,6"/>
                        </svg>
                        Email
                    </a>
                </div>
            </div>

            <hr class="divider">

            <!-- Publication enquiries -->
            <div class="contact-section">
                <p class="contact-section__title">Publication &amp; Correspondence</p>
                <p class="contact-section__desc">
                    For publication-related matters, contact our correspondence author directly.
                </p>

                <div class="contact-person">
                    <div class="contact-person__info">
                        <span class="contact-person__name">Prof. Chaocheng Wang</span>
                        <span class="contact-person__email">chaochenwang [at] intl [dot] zju [dot] edu [dot] com</span>
                    </div>
                    <a class="btn-email" href="mailto:chaochenwang@intl.zju.edu.com">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                            <polyline points="22,6 12,13 2,6"/>
                        </svg>
                        Email
                    </a>
                </div>
            </div>

        </section>

    </div>
</main>

<script src="JS/construction-modal-simple.js"></script>
</body>
</html>
