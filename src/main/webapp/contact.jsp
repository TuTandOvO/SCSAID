<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%
    response.setStatus(301);
    response.setHeader("Location", "feedback");
    response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
%>
<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0; url=feedback"><title>Moved</title></head>
<body>Contact has moved to <a href="feedback">Feedback &amp; Contact</a>.</body></html>
