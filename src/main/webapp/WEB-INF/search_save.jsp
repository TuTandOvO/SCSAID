<%@ page import="java.io.InputStream" %>
<%@ page import="org.apache.poi.ss.usermodel.Workbook" %>
<%@ page import="java.io.FileInputStream" %>
<%@ page import="org.apache.poi.ss.usermodel.WorkbookFactory" %>
<%@ page import="org.apache.poi.ss.usermodel.Sheet" %>
<%@ page import="org.apache.poi.ss.usermodel.Row" %>
<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>

<html>
<head>
    <link rel="stylesheet"
          href="lib/css/jquery.dataTables.min.css"/>
    <script src="lib/jquery-3.7.1.min.js"></script>
    <script src="lib/jquery.dataTables.min.js"></script>

    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Details-SR001</title>
    <link rel="stylesheet" href="CSS/design-system.css?v=20260702c">
    <link rel="stylesheet" href="CSS/header.css?v=20260702o">
    <link rel="stylesheet" href="CSS/details.css?v=20260701h">
    <link rel="stylesheet" href="CSS/degtest.css">

    <meta charset="UTF-8"/>
    <title>Data Integrate</title>
    <style>

        .pagination { margin:10px 0;
        }
        .pagination a, .pagination span { margin-right:8px; text-decoration:none;
        }
        .pagination span.disabled { color:#999;
        }
        .pagination input { width:40px; text-align:center;
        }
    </style>
</head>

<header>
    <nav>
        <ul>
            <db_logo>
                <a href="#">sDSSA</a>
            </db_logo>
            <li><a href="index.jsp">Home</a>
            </li>
            <li><a href="browse.jsp">Browse</a>

            </li>
            <li><a href="search.jsp">Integrate</a>
                <div class="top_list">
                    <lib><a href="#">Gene</a></lib>
                    <lib><a href="#">Cell</a></lib>
                </div>

            </li>
            <li><a href="#">Help</a>
                <div class="top_list">
                    <lib><a href="#">Method</a></lib>
                    <lib><a href="#">Tutorial</a></lib>
                </div>

            </li>
            <li><a href="#">Download</a>
            </li>
            <un_logo>
                <img src="https://www.zju.edu.cn/_upload/tpl/0b/bf/3007/template3007/static/js/../../static/media/mlogo.80e02913954185729616ab6a1c6ae12d.svg" alt="" width="196" height="54">
            </un_logo>

        </ul>
    </nav>
</header>

<body>
<div class="main">
    <div class="title-div">
        <h2 class="page-title">Dataset Preview</h2>
        <div id="integrate-button"  class="theme-btn">Generate Integrated UMAP</div>
    </div>

    <%
        // 读取 Excel
        String
                excelPath = application.getRealPath("/WEB-INF/BrowseShow.xlsx");
        InputStream input = null;
        Workbook workbook = null;
        try {
            input = new FileInputStream(excelPath);
            workbook = WorkbookFactory.create(input);
            Sheet sheet = workbook.getSheetAt(0);
// 分页参数
            int rowsPerPage = 10;
            int totalRows   = sheet.getLastRowNum();
            int totalPages  = (int) Math.ceil((double) totalRows / rowsPerPage);

            // 当前页
            String pageParam = request.getParameter("page");
            int pageNum = 1;
            try { pageNum = Integer.parseInt(pageParam); } catch(Exception ignore){}
            if (pageNum < 1)          pageNum = 1;
            if (pageNum > totalPages) pageNum = totalPages;

            int startRow = (pageNum - 1) * rowsPerPage + 1;
            int endRow   = Math.min(startRow + rowsPerPage - 1, totalRows);
    %>
    <table class="table-style-1">
        <thead>
        <tr>
            <th><input type="checkbox" id="select-all"/></th> <th>SAID</th>
            <th>GSE</th>
            <th>GSM</th>
            <th>species</th>
            <th>disease information</th>
            <th>tissue information</th>
            <th>Details</th>
        </tr>
        </thead>
        <tbody>
        <%
            for (int r = startRow; r <= endRow; r++) {
                Row row = sheet.getRow(r);
                if (row == null) continue;
                String said_display = row.getCell(0, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK).toString(); // 用于显示SAID
                String gse          = row.getCell(1, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK).toString();
                String gsm_value    = row.getCell(2, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK).toString(); // 用于作为checkbox的值和显示GSM
                String species      = row.getCell(3, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK).toString();
                String disease      = row.getCell(4, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK).toString();
                String tissue       = row.getCell(5, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK).toString();
        %>
        <tr>
            <td><input type="checkbox" name="dataset_checkbox" value="<%= gsm_value %>"></td> <%-- 关键修改：使用 gsm_value --%>
            <td><%= said_display %></td> <%-- 保持显示 SAID --%>
            <td><%= gse %></td>
            <td><%= gsm_value %></td> <%-- 保持显示 GSM --%>
            <td><%= species %></td>
            <td><%= disease %></td>
            <td><%= tissue %></td>
            <td>
                <%-- 注意：details.jsp 可能仍需要SAID，根据你的需求决定这里是传said_display还是gsm_value --%>
                <a href="details.jsp?said=<%= java.net.URLEncoder.encode(said_display, "UTF-8") %>">
                    Details
                </a>
            </td>
        </tr>
        <%
            }
        %>
        </tbody>
    </table>



    <div id="umap-result-container" style="text-align: center; margin-top: 20px;">
        <div id="loading-indicator" class="panel-loader" role="status" aria-label="Loading" style="display:none;"></div>
        <img id="umap-image" src="" alt="Integrated UMAP plot" style="max-width: 100%; display: none; border: 1px solid #ccc;"/>
    </div>
    <div class="pagination">
        <% if (pageNum > 1) { %>
        <a href="?page=<%= pageNum - 1 %>">Previous</a>
        <% } else { %>

        <span class="disabled">Previous</span>
        <% } %>

        <span>
        Page
        <form method="get" style="display:inline;">
          <input type="number" name="page"
                 min="1" max="<%= totalPages %>"
                 value="<%= pageNum %>"/>
          <button type="submit">Go</button>

 </form>
      </span>

        <% if (pageNum < totalPages) { %>
        <a href="?page=<%= pageNum + 1 %>">Next</a>
        <% } else { %>
        <span class="disabled">Next</span>
        <% } %>
    </div>
    <%
    } catch (Exception e) {
    %>
    <p style="color:red;">Error loading data: <%= e.getMessage() %></p>
    <%
        } finally {
            if (workbook != null) try { workbook.close();
            } catch(Exception ignore){}
            if (input    != null) try { input.close();
            } catch(Exception ignore){}
        }
    %>
</div>
</body>
<script>
    $(document).ready(function() {
        document.querySelector('#select-all').closest('table').addEventListener('change', function (e) {
            const cb = e.target;
            if (cb.type !== 'checkbox' || cb.name !== 'dataset_checkbox') return;
            const tr = cb.closest('tr');
            if (cb.checked) {
                tr.classList.add('selected-row');
            } else {
                tr.classList.remove('selected-row');
            }
        });
        // “全选”复选框的逻辑
        $('#select-all').on('click', function() {
            // 'this.checked' 会返回全选框当前是否被选中
            // $('input[name="dataset_checkbox"]').prop('checked', this.checked);
            const flag = this.checked;
            $('input[name="dataset_checkbox"]').each(function () {
                this.checked = flag;
                $(this).closest('tr').toggleClass('selected-row', flag);
            });
        });

        // “整合”按钮的点击事件逻辑
        // ... inside document.ready function ...

        $('#integrate-button').on('click', function() {
            console.log("Button clicked!");
            let selectedSaids = [];
            $('input[name="dataset_checkbox"]:checked').each(function() {
                selectedSaids.push($(this).val());
            });

            if (selectedSaids.length < 2) {
                alert('Please select at least two datasets to integrate. (请至少选择两个数据集进行整合)');
                return;
            }

            $.ajax({
                url: 'integrate',
                type: 'POST',
                data: { 'saids[]': selectedSaids }, // Ensure the parameter name matches servlet's getParameterValues
                beforeSend: function() {
                    $('#loading-indicator').show();
                    $('#umap-image').hide(); // Still hide previous image if any
                },
                success: function(response) {
                    $('#loading-indicator').hide();

                    if (response.redirectUrl) {
                        window.open(response.redirectUrl, '_blank'); // Open Dash app in a new tab/window
                    } else if (response.error) {
                        alert('Error: ' + response.error);
                    } else {
                        alert('An unknown error occurred.');
                    }
                },
                error: function(xhr, status, error) {
                    $('#loading-indicator').hide();
                    alert('AJAX error: ' + error + '\n' + xhr.responseText);
                    console.error("AJAX Error:", status, error, xhr.responseText);
                }
            });
        });

        // ... rest of your script ...
    });

</script>
