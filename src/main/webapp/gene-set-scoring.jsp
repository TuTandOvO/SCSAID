<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" language="java" %>
<%
    // Redirect to details page since this functionality is now accessed from there
    String saidParam = request.getParameter("said");
    if(saidParam != null && saidParam.matches("SAID\\d{3}")) {
        response.sendRedirect("details?said=" + java.net.URLEncoder.encode(saidParam, "UTF-8") + "#GeneSetScoring");
    } else {
        response.sendRedirect("details.jsp");
    }
%>
