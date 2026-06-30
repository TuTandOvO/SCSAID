<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
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
    <title>Help - scSAID</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/help.css">
    <link rel="stylesheet" href="CSS/construction-modal-simple.css">
</head>
<body>
<%
    Map<String, String> topics = new LinkedHashMap<>();
    topics.put("faq", "FAQ");
    topics.put("methods", "Methods");
    topics.put("markers", "Markers");
    topics.put("pipeline", "Pipeline");
    topics.put("usage", "Usage");

    String topic = request.getParameter("topic");
    if (topic == null || !topics.containsKey(topic)) {
        topic = "faq";
    }
    String topicTitle = topics.get(topic);
%>

<!-- Header -->
<header class="site-header">
    <div class="container">
        <a href="index.jsp" class="site-logo">scSAID</a>
        <nav class="main-nav">
            <a href="index.jsp" class="main-nav__link">Home</a>
            <a href="browse.jsp" class="main-nav__link">Browse</a>
            <a href="gene-search.jsp" class="main-nav__link">Search</a>
            <a href="featureplot.jsp" class="main-nav__link">Expression</a>
            <a href="compare.jsp" class="main-nav__link">Compare</a>
            <a href="download.jsp" class="main-nav__link">Download</a>
            <div class="main-nav__item">
                <a href="help?topic=faq" class="main-nav__link main-nav__link--active">Help</a>
                <div class="main-nav__dropdown">
                    <a href="help?topic=faq" class="main-nav__dropdown-link">FAQ</a>
                    <a href="help?topic=methods" class="main-nav__dropdown-link">Methods</a>
                    <a href="help?topic=markers" class="main-nav__dropdown-link">Markers</a>
                    <a href="help?topic=pipeline" class="main-nav__dropdown-link">Pipeline</a>
                    <a href="help?topic=usage" class="main-nav__dropdown-link">Usage</a>
                </div>
            </div>
            <a href="feedback" class="main-nav__link">Feedback</a>
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

<main class="help-page">
    <div class="page-header">
        <div class="page-header__content">
            <span class="page-header__eyebrow">Help Center</span>
            <h1 class="page-header__title"><%= topicTitle %></h1>
            <p class="page-header__description">
                Find guidance for exploring scSAID datasets, analyses, and exports.
            </p>
        </div>
    </div>

    <section class="help-content-section">
        <div class="help-layout">
            <aside class="help-sidebar">
                <div class="help-sidebar__heading">Topics</div>
                <nav class="help-sidebar__topics">
                    <% for (Map.Entry<String, String> entry : topics.entrySet()) {
                        boolean isActive = entry.getKey().equals(topic);
                    %>
                    <div class="help-sidebar__topic-group">
                        <a href="help?topic=<%= entry.getKey() %>" class="help-sidebar__topic<%= isActive ? " help-sidebar__topic--active" : "" %>">
                            <%= entry.getValue() %>
                        </a>
                        <% if (isActive) { %>
                        <div class="help-sidebar__subheadings" id="toc-subheadings"></div>
                        <% } %>
                    </div>
                    <% } %>
                </nav>
            </aside>

            <article class="help-content" id="help-content">
                <p class="help-content__loading">Loading help content...</p>
            </article>
        </div>
    </section>
</main>

<script src="https://cdn.jsdelivr.net/npm/marked@12.0.0/marked.min.js"></script>
<script>
    const activeTopic = "<%= topic %>";
    const contentEl = document.getElementById("help-content");
    const tocEl = document.getElementById("toc-subheadings");

    const slugCounts = {};

    const slugify = (value) => {
        return value
            .toLowerCase()
            .trim()
            .replace(/[^a-z0-9\s-]/g, "")
            .replace(/\s+/g, "-")
            .replace(/-+/g, "-");
    };

    const slugifyUnique = (value) => {
        const base = slugify(value);
        if (!slugCounts[base]) {
            slugCounts[base] = 0;
            return base;
        }
        slugCounts[base] += 1;
        return `${base}-${slugCounts[base]}`;
    };

    const renderer = new marked.Renderer();
    renderer.heading = (text, level, raw, slugger) => {
        let depth = level;
        let headingText = text;
        if (typeof text === "object" && text !== null) {
            headingText = text.text || "";
            depth = text.depth || level;
        }
        const id = slugifyUnique(headingText);
        return `<h${depth} id="${id}">${headingText}</h${depth}>`;
    };

    marked.setOptions({
        mangle: false,
        headerIds: false
    });

    marked.use({ renderer });

    const buildSubTOC = () => {
        if (!tocEl) {
            return;
        }
        tocEl.innerHTML = "";
        const headings = contentEl.querySelectorAll("h2");
        if (!headings.length) {
            const empty = document.createElement("span");
            empty.className = "help-sidebar__empty";
            empty.textContent = "No sub-sections on this page.";
            tocEl.appendChild(empty);
            return;
        }
        headings.forEach((heading, index) => {
            if (!heading.id) {
                heading.id = slugifyUnique(heading.textContent || `section-${index + 1}`);
            }
            const link = document.createElement("a");
            link.className = "help-sidebar__sublink";
            link.href = `#${heading.id}`;
            link.textContent = heading.textContent || `Section ${index + 1}`;
            tocEl.appendChild(link);
        });
    };

    const setupScrollHighlighting = () => {
        if (!tocEl) {
            return;
        }
        const links = Array.from(tocEl.querySelectorAll(".help-sidebar__sublink"));
        if (!links.length) {
            return;
        }
        const headings = links
            .map((link) => document.getElementById(link.getAttribute("href").slice(1)))
            .filter(Boolean);

        const setActive = (id) => {
            links.forEach((link) => {
                link.classList.toggle("help-sidebar__sublink--active", link.getAttribute("href") === `#${id}`);
            });
        };

        const observer = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        setActive(entry.target.id);
                    }
                });
            },
            {
                rootMargin: "-30% 0px -60% 0px",
                threshold: [0, 1.0]
            }
        );

        headings.forEach((heading) => observer.observe(heading));
        if (headings.length) {
            setActive(headings[0].id);
        }
    };

    fetch(`help/${activeTopic}.md`)
        .then((response) => {
            if (!response.ok) {
                throw new Error("Failed to load help content");
            }
            return response.text();
        })
        .then((markdown) => {
            contentEl.innerHTML = marked.parse(markdown);
            buildSubTOC();
            setupScrollHighlighting();
        })
        .catch(() => {
            contentEl.innerHTML = "<p class=\"help-content__error\">Unable to load help content. Please try again later.</p>";
        });
</script>
<script src="JS/construction-modal-simple.js"></script>

<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
