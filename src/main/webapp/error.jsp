<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8"
         isErrorPage="true" %>
<%
    // Never expose stack traces or internal details to the client.
    response.setStatus(500);
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Something went wrong - scSAID</title>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="CSS/design-system.css?v=20260701g">
    <style>
        body { background:#ffffff; font-family:'Nunito', sans-serif; color:#333333;
               display:flex; min-height:100vh; min-height:100dvh; align-items:center; justify-content:center; margin:0; padding:1rem; }
        .err { width:min(100%,520px); text-align:center; padding:clamp(1rem,5vw,2rem); }
        .err h1 { font-size:clamp(2rem,10vw,3rem); margin:0 0 .5rem; color:#333333; }
        .err p { color:#6b7280; line-height:1.7; }
        .err a { color:#337ab7; text-decoration:none; font-weight:300; }
    </style>
</head>
<body>
    <div class="err">
        <h1>Something went wrong</h1>
        <p>An unexpected error occurred while processing your request. The issue has been logged.
           Please try again, or return to the <a href="index.jsp">home page</a>.</p>
    </div>
</body>
</html>
