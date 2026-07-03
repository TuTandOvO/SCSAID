<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <!-- Favicons / PWA icons -->
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png">
    <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png">
    <link rel="icon" type="image/png" sizes="512x512" href="/images/favicon-512.png">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png">
    <link rel="manifest" href="/site.webmanifest">
    <meta name="theme-color" content="#333333">
    <title>Download Center - scSAID</title>
    <meta name="description" content="Download scRNA-seq processed data from scSAID: 252 curated datasets as h5ad / zarr files, with cleaned obs metadata (condition, age, sex, tissue location, cell-type annotation). Free to use under CC-BY-4.0.">
    <meta name="keywords" content="download scRNA-seq, h5ad download, scSAID download, skin atlas download, AnnData download">
    <meta name="robots" content="index,follow">
    <link rel="canonical" href="https://skin-scsaid.com/download.jsp">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css?v=20260702p">
    <link rel="stylesheet" href="CSS/header.css?v=20260702p">
    <link rel="stylesheet" href="CSS/download.css?v=20260702p">
</head>
<body>

<%@ include file="includes/header.jsp" %>

<main class="download-page" id="main-content" tabindex="-1">
    <!-- Page Hero -->
    <section class="page-hero">
        <div class="page-hero__inner">
            <span class="page-hero__eyebrow">Data Export</span>
            <h1 class="page-hero__title">Download Center</h1>
            <p class="page-hero__description">
                Download curated datasets from scSAID for offline analysis and integration with your research workflows.
            </p>
        </div>
    </section>

    <!-- Download Section -->
    <section class="download-section">
        <h2 class="section-title">Integrated single-cell atlases</h2>
        <p class="section-intro">
            The full integrated atlases as AnnData (<code>.h5ad</code>) objects — UMAP embeddings,
            cleaned <code>obs</code> metadata, and cell-type annotations — are deposited on Zenodo,
            one record per species. Open access under CC-BY-4.0.
        </p>

        <div class="download-grid">
            <!-- Human integrated atlas (Zenodo) -->
            <div class="download-card">
                <div class="download-card__header">
                    <div class="download-card__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <ellipse cx="12" cy="5" rx="9" ry="3"/>
                            <path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/>
                            <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
                        </svg>
                    </div>
                    <div class="download-card__meta">
                        <h3 class="download-card__title">Human integrated atlas</h3>
                        <span class="download-card__format">AnnData (.h5ad) · Zenodo</span>
                    </div>
                </div>
                <div class="download-card__body">
                    <p class="download-card__description">
                        The integrated human skin single-cell atlas — UMAP embedding, cleaned
                        <code>obs</code> metadata (condition, age, sex, skin location), and Gross/Fine
                        cell-type maps — as a single AnnData object, hosted on Zenodo.
                    </p>
                    <div class="download-card__details">
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Species</span>
                            <span class="download-card__detail-value">Human</span>
                        </div>
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Cells</span>
                            <span class="download-card__detail-value">~405K</span>
                        </div>
                    </div>
                    <a href="https://zenodo.org/records/19050479" target="_blank" rel="noopener" class="download-card__btn">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
                            <polyline points="15 3 21 3 21 9"/>
                            <line x1="10" y1="14" x2="21" y2="3"/>
                        </svg>
                        View on Zenodo
                    </a>
                </div>
            </div>

            <!-- Mouse integrated atlas (Zenodo) -->
            <div class="download-card">
                <div class="download-card__header">
                    <div class="download-card__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <ellipse cx="12" cy="5" rx="9" ry="3"/>
                            <path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/>
                            <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
                        </svg>
                    </div>
                    <div class="download-card__meta">
                        <h3 class="download-card__title">Mouse integrated atlas</h3>
                        <span class="download-card__format">AnnData (.h5ad) · Zenodo</span>
                    </div>
                </div>
                <div class="download-card__body">
                    <p class="download-card__description">
                        The integrated mouse skin single-cell atlas — UMAP embedding, cleaned
                        <code>obs</code> metadata, and Gross/Fine cell-type maps — as a single
                        AnnData object, hosted on Zenodo.
                    </p>
                    <div class="download-card__details">
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Species</span>
                            <span class="download-card__detail-value">Mouse</span>
                        </div>
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Cells</span>
                            <span class="download-card__detail-value">~795K</span>
                        </div>
                    </div>
                    <a href="https://zenodo.org/records/19015807" target="_blank" rel="noopener" class="download-card__btn">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
                            <polyline points="15 3 21 3 21 9"/>
                            <line x1="10" y1="14" x2="21" y2="3"/>
                        </svg>
                        View on Zenodo
                    </a>
                </div>
            </div>
        </div>

        <h2 class="section-title section-title--spaced">Metadata &amp; summary tables</h2>
        <p class="section-intro">
            Curated metadata for all 252 samples — dataset overview, full metadata, the
            integration table, and a flat CSV for R/Python.
        </p>

        <div class="download-grid" id="download-grid">
            <!-- Browse Data Card -->
            <div class="download-card">
                <div class="download-card__header">
                    <div class="download-card__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M3 3h18v18H3z"/>
                            <path d="M3 9h18"/>
                            <path d="M9 21V9"/>
                        </svg>
                    </div>
                    <div class="download-card__meta">
                        <h3 class="download-card__title">Browse Data</h3>
                        <span class="download-card__format">Excel (.xlsx)</span>
                    </div>
                </div>
                <div class="download-card__body">
                    <p class="download-card__description">
                        Dataset overview with key metadata including SAID identifiers, GSE/GSM accessions, species, disease status, and tissue types.
                    </p>
                    <div class="download-card__details">
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Format</span>
                            <span class="download-card__detail-value">Excel Workbook</span>
                        </div>
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Size</span>
                            <span class="download-card__detail-value" id="browse-size">—</span>
                        </div>
                    </div>
                    <a href="download-file?file=browse" class="download-card__btn">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
                            <polyline points="7,10 12,15 17,10"/>
                            <line x1="12" y1="15" x2="12" y2="3"/>
                        </svg>
                        Download
                    </a>
                </div>
            </div>

            <!-- All Data Card -->
            <div class="download-card">
                <div class="download-card__header">
                    <div class="download-card__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <ellipse cx="12" cy="5" rx="9" ry="3"/>
                            <path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/>
                            <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
                        </svg>
                    </div>
                    <div class="download-card__meta">
                        <h3 class="download-card__title">Complete Dataset</h3>
                        <span class="download-card__format">Excel (.xlsx)</span>
                    </div>
                </div>
                <div class="download-card__body">
                    <p class="download-card__description">
                        Comprehensive dataset containing all metadata, experimental details, and sample information across the entire database.
                    </p>
                    <div class="download-card__details">
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Format</span>
                            <span class="download-card__detail-value">Excel Workbook</span>
                        </div>
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Size</span>
                            <span class="download-card__detail-value" id="all-size">—</span>
                        </div>
                    </div>
                    <a href="download-file?file=all" class="download-card__btn">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
                            <polyline points="7,10 12,15 17,10"/>
                            <line x1="12" y1="15" x2="12" y2="3"/>
                        </svg>
                        Download
                    </a>
                </div>
            </div>

            <!-- Integration Table Card -->
            <div class="download-card">
                <div class="download-card__header">
                    <div class="download-card__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="12" r="10"/>
                            <path d="M12 6v12M6 12h12"/>
                        </svg>
                    </div>
                    <div class="download-card__meta">
                        <h3 class="download-card__title">Integration Table</h3>
                        <span class="download-card__format">Excel (.xlsx)</span>
                    </div>
                </div>
                <div class="download-card__body">
                    <p class="download-card__description">
                        Pre-computed integration analysis data for cross-dataset comparisons and UMAP visualizations.
                    </p>
                    <div class="download-card__details">
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Format</span>
                            <span class="download-card__detail-value">Excel Workbook</span>
                        </div>
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Size</span>
                            <span class="download-card__detail-value" id="integrate-size">—</span>
                        </div>
                    </div>
                    <a href="download-file?file=integrate" class="download-card__btn">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
                            <polyline points="7,10 12,15 17,10"/>
                            <line x1="12" y1="15" x2="12" y2="3"/>
                        </svg>
                        Download
                    </a>
                </div>
            </div>

            <!-- CSV (programmatic) Card -->
            <div class="download-card">
                <div class="download-card__header">
                    <div class="download-card__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
                            <polyline points="14 2 14 8 20 8"/>
                            <line x1="8" y1="13" x2="16" y2="13"/>
                            <line x1="8" y1="17" x2="16" y2="17"/>
                            <line x1="10" y1="9" x2="14" y2="9"/>
                        </svg>
                    </div>
                    <div class="download-card__meta">
                        <h3 class="download-card__title">Sample Metadata (CSV)</h3>
                        <span class="download-card__format">Comma-separated (.csv)</span>
                    </div>
                </div>
                <div class="download-card__body">
                    <p class="download-card__description">
                        Flat, UTF-8 CSV of all 252 samples with the cleaned obs fields
                        (condition, age, sex, skin location, cell-type map). Reads
                        directly into R (<code>read.csv</code>) or Python
                        (<code>pd.read_csv</code>).
                    </p>
                    <div class="download-card__details">
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Rows</span>
                            <span class="download-card__detail-value">252</span>
                        </div>
                        <div class="download-card__detail">
                            <span class="download-card__detail-label">Size</span>
                            <span class="download-card__detail-value" id="csv-size">—</span>
                        </div>
                    </div>
                    <a href="download-file?file=csv" class="download-card__btn">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
                            <polyline points="7,10 12,15 17,10"/>
                            <line x1="12" y1="15" x2="12" y2="3"/>
                        </svg>
                        Download
                    </a>
                </div>
            </div>
        </div>

        <!-- Info Section -->
        <div class="info-section">
            <h3 class="info-section__title">Usage Guidelines</h3>
            <div class="info-section__content">
                <div class="info-item">
                    <div class="info-item__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
                            <polyline points="14,2 14,8 20,8"/>
                            <line x1="16" y1="13" x2="8" y2="13"/>
                            <line x1="16" y1="17" x2="8" y2="17"/>
                            <polyline points="10,9 9,9 8,9"/>
                        </svg>
                    </div>
                    <div class="info-item__text">
                        <h4>Data Format</h4>
                        <p>Metadata is provided as Excel (.xlsx) and CSV, readable in Excel, Google Sheets, and R/Python. The full integrated atlases are AnnData (.h5ad) objects on Zenodo — load with <code>scanpy.read_h5ad</code>.</p>
                    </div>
                </div>

                <div class="info-item">
                    <div class="info-item__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="12" r="10"/>
                            <path d="M12 16v-4"/>
                            <path d="M12 8h.01"/>
                        </svg>
                    </div>
                    <div class="info-item__text">
                        <h4>Citation</h4>
                        <p>Please cite scSAID when using downloaded data in your publications or presentations.</p>
                    </div>
                </div>

                <div class="info-item">
                    <div class="info-item__icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                            <path d="M7 11V7a5 5 0 0110 0v4"/>
                        </svg>
                    </div>
                    <div class="info-item__text">
                        <h4>License</h4>
                        <p>Data is provided for academic and research purposes. Please review the license terms before redistribution.</p>
                    </div>
                </div>
            </div>
        </div>
    </section>
</main>

<script src="lib/jquery-3.7.1.min.js"></script>
<script>
$(document).ready(function() {
    // Format file size
    function formatSize(bytes) {
        if (bytes === 0) return 'N/A';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    // Fetch file info and update sizes
    $.ajax({
        url: 'download-file',
        type: 'GET',
        dataType: 'json',
        success: function(response) {
            if (response.files) {
                response.files.forEach(function(file) {
                    const $sizeEl = $('#' + file.key + '-size');
                    if ($sizeEl.length) {
                        if (file.available) {
                            $sizeEl.text(formatSize(file.size));
                        } else {
                            $sizeEl.text('Unavailable');
                            // Disable download button
                            $sizeEl.closest('.download-card__body')
                                   .find('.download-card__btn')
                                   .addClass('download-card__btn--disabled')
                                   .removeAttr('href')
                                   .on('click', function(e) { e.preventDefault(); });
                        }
                    }
                });
            }
        },
        error: function() {
            $('#browse-size, #all-size, #integrate-size, #csv-size').text('Error');
        }
    });
});
</script>



<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
