<%@ page language="java"
         contentType="application/xml; charset=UTF-8"
         pageEncoding="UTF-8"
         trimDirectiveWhitespaces="true" %>
<%@ page import="
    java.io.*,
    java.util.*,
    java.text.SimpleDateFormat,
    com.google.gson.Gson,
    com.google.gson.reflect.TypeToken" %>
<%
    // Dynamic sitemap served at /sitemap.xml (nginx will rewrite or we add a
    // Tomcat welcome mapping). Lists all SAID detail pages plus static pages.
    response.setHeader("Cache-Control", "public, max-age=86400");
    String today = new SimpleDateFormat("yyyy-MM-dd").format(new Date());

    List<String> saids = new ArrayList<String>();
    try (InputStreamReader r = new InputStreamReader(
            application.getResourceAsStream("/WEB-INF/classes/mapping.csv.json"),
            "UTF-8")) {
        Map<String, Map<String, String>> mapping = new Gson().fromJson(
                r, new TypeToken<Map<String, Map<String, String>>>(){}.getType());
        if (mapping != null) {
            saids.addAll(mapping.keySet());
            Collections.sort(saids);
        }
    } catch (Exception ignore) {
        // Fallback: no SAIDs; main pages still listed below.
    }

    // Static top-level pages
    String[] staticUrls = new String[] {
        "https://skin-scsaid.com/",
        "https://skin-scsaid.com/browse.jsp",
        "https://skin-scsaid.com/featureplot.jsp",
        "https://skin-scsaid.com/gene-search.jsp",
        "https://skin-scsaid.com/deg-search.jsp",
        "https://skin-scsaid.com/download.jsp",
        "https://skin-scsaid.com/help?topic=faq",
        "https://skin-scsaid.com/help?topic=methods",
        "https://skin-scsaid.com/help?topic=pipeline",
        "https://skin-scsaid.com/help?topic=usage",
        "https://skin-scsaid.com/help?topic=markers",
        "https://skin-scsaid.com/contact",
        "https://skin-scsaid.com/feedback"
    };
%><?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
<% for (String u : staticUrls) { %>
    <url>
        <loc><%= u %></loc>
        <lastmod><%= today %></lastmod>
        <changefreq>weekly</changefreq>
        <priority><%= u.endsWith("/") ? "1.0" : "0.8" %></priority>
    </url>
<% } %>
<% for (String said : saids) { %>
    <url>
        <loc>https://skin-scsaid.com/details.jsp?said=<%= said %></loc>
        <lastmod><%= today %></lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.7</priority>
    </url>
<% } %>
</urlset>
