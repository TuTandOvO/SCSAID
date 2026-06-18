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
    <link rel="stylesheet" href="CSS/design-system.css">
    <style>
        body { background:#faf8f5; font-family:'Montserrat',Arial,sans-serif; color:#1a2332;
               display:flex; min-height:100vh; align-items:center; justify-content:center; margin:0; }
        .err { text-align:center; padding:2rem; max-width:520px; }
        .err h1 { font-size:3rem; margin:0 0 .5rem; color:#1a2332; }
        .err p { color:#6b7280; line-height:1.7; }
        .err a { color:#d4a574; text-decoration:none; font-weight:600; }
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
