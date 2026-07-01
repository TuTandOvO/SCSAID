<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%
    response.setStatus(301);
    response.setHeader("Location", "feedback");
    response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
%>
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="refresh" content="0; url=feedback"><title>Contact - scSAID</title></head>
<body style="min-height:100vh;margin:0;padding:2rem;display:grid;place-items:center;background:#ffffff;color:#333333;font:1rem/1.6 Arial,sans-serif;text-align:center;box-sizing:border-box;">
<p>Contact has moved to <a href="feedback" style="color:#b65f4b;font-weight:300;">Feedback &amp; Contact</a>.</p>
</body></html>
