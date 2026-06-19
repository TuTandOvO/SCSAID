<%--
  Created by IntelliJ IDEA.
  User: Colorful404
  Date: 2025/4/9
  Time: 20:34
  To change this template use File | Settings | File Templates.
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%--<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>--%>
<html>
<head>
    <!-- Favicons / PWA icons -->
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png">
    <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png">
    <link rel="icon" type="image/png" sizes="512x512" href="/images/favicon-512.png">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png">
    <link rel="manifest" href="/site.webmanifest">
    <meta name="theme-color" content="#1a2332">
    <meta charset="UTF-8">
    <title>美观实用的下拉框示例</title>
    <!-- 引入 Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@4.5.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- 引入 Select2 样式 -->
    <link href="https://cdn.jsdelivr.net/npm/select2@4.0.13/dist/css/select2.min.css" rel="stylesheet">
    <!-- 自定义样式 -->
    <link href="CSS/dropboxtest.css">
    <style>
        /* 自定义 select2 下拉框外观 */
        .select2-container--default .select2-selection--single {
            height: 38px;
            padding: 0.375rem 0.75rem;
            border: 1px solid #ced4da;
            border-radius: 0.25rem;
            background-color: #fff;
            box-shadow: none;
        }
        .select2-container--default .select2-selection--single .select2-selection__arrow {
            height: 36px;
            right: 10px;
        }
    </style>
</head>
<body>
<div class="select_wrap" id="selectWrap">
    <dl>
        <dt>请选择：</dt>
        <dd>
            <select id="selectElem">
                <option value="1">北京</option>
                <option value="2">上海</option>
                <option value="3">广东</option>
                <option value="4">湖南</option>
                <option value="5">河北</option>
                <option value="6">黑龙江</option>
            </select>
        </dd>
    </dl>
</div>
<div class="container mt-5">
    <h3 class="mb-4">美观实用的下拉框示例</h3>
    <form action="yourAction.jsp" method="post">
        <div class="form-group">
            <label for="myDropdown">请选择一个选项：</label>
            <select id="myDropdown" name="options" class="form-control select2">
                <option value="">-- 请选择 --</option>
                <option value="option1">选项1</option>
                <option value="option2">选项2</option>
                <option value="option3">选项3</option>
                <option value="option4">选项4</option>
            </select>
        </div>
        <button type="submit" class="btn btn-primary">提交</button>
    </form>
</div>
<!-- 引入 jQuery -->
<script src="lib/jquery-3.7.1.min.js"></script>
<!-- 引入 Bootstrap JS -->
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.5.2/dist/js/bootstrap.bundle.min.js"></script>
<!-- 引入 Select2 JS -->
<script src="https://cdn.jsdelivr.net/npm/select2@4.0.13/dist/js/select2.min.js"></script>
<script>
    $(document).ready(function(){
        // 初始化 Select2 插件，使下拉框更加美观
        $('#myDropdown').select2({
            placeholder: "请选择一个选项",
            allowClear: true
        });
    });
</script>
</body>
</html>