<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%
    // The gene-expression UMAP overlay now lives on the Feature Plot page, which
    // owns the nav link + SEO. Preserve any ?gene= deep-link on the way through.
    String gene = request.getParameter("gene");
    String target = "featureplot.jsp";
    if (gene != null && !gene.trim().isEmpty()) {
        target += "?gene=" + java.net.URLEncoder.encode(gene.trim(), "UTF-8");
    }
    response.setStatus(301);
    response.setHeader("Location", target);
%>
