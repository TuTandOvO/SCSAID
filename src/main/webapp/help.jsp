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
    <meta name="theme-color" content="#333333">
    <title>Help - scSAID</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css?v=20260701g">
    <link rel="stylesheet" href="CSS/header.css?v=20260701g">
    <link rel="stylesheet" href="CSS/help.css?v=20260701g">
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

<%@ include file="includes/header.jsp" %>

<main class="help-page" id="main-content" tabindex="-1">
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

            <article class="help-content panel-loader" id="help-content" role="status" aria-label="Loading"></article>
        </div>
    </section>
</main>

<script src="lib/marked.min.js?v=20260701"></script>
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
        return base + "-" + slugCounts[base];
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
        return "<h" + depth + " id=\"" + id + "\">" + headingText + "</h" + depth + ">";
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
                heading.id = slugifyUnique(heading.textContent || "section-" + (index + 1));
            }
            const link = document.createElement("a");
            link.className = "help-sidebar__sublink";
            link.href = "#" + heading.id;
            link.textContent = heading.textContent || "Section " + (index + 1);
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
                link.classList.toggle("help-sidebar__sublink--active", link.getAttribute("href") === "#" + id);
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

    fetch("help/" + activeTopic + ".md")
        .then((response) => {
            if (!response.ok) {
                throw new Error("Failed to load help content");
            }
            return response.text();
        })
        .then((markdown) => {
            contentEl.classList.remove("panel-loader");
            contentEl.removeAttribute("role");
            contentEl.removeAttribute("aria-label");
            contentEl.innerHTML = marked.parse(markdown);
            buildSubTOC();
            setupScrollHighlighting();
        })
        .catch(() => {
            contentEl.classList.remove("panel-loader");
            contentEl.removeAttribute("role");
            contentEl.removeAttribute("aria-label");
            contentEl.innerHTML = "<p class=\"help-content__error\">Unable to load help content. Please try again later.</p>";
        });
</script>

<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
