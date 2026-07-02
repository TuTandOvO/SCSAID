<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" language="java" %>
<%
    // Redirect to details page since this functionality is now accessed from there
    String saidParam = request.getParameter("said");
    if(saidParam != null && !saidParam.isEmpty()) {
        response.sendRedirect("details?said=" + saidParam + "#EnrichmentAnalysis");
    } else {
        response.sendRedirect("details.jsp");
    }
%>
