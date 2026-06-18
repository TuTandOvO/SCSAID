import os
import pandas as pd
import scanpy as sc
from flask import Flask
from dash import Dash, html, dcc
from dash.dependencies import Input, Output
from urllib.parse import parse_qs
import plotly.express as px
import plotly.colors as pcolors
from functools import lru_cache

# Flask + Dash 初始化
server = Flask(__name__)
app = Dash(__name__, server=server, url_base_pathname="/dash/")

# Path to the master h5ad file (this should match the path in IntegrateServlet)
# 你需要根据你的实际部署环境来设置这个路径
H5AD_PATH = "SkinDB_combined_human_integrated.h5ad"

# Cache size for processed datasets (32 unique sample combinations)
CACHE_MAXSIZE = 32

# Downsampling thresholds
MAX_CELLS_THRESHOLD = 8000
TARGET_CELLS_AFTER_DOWNSAMPLE = 5000


def downsample_if_needed(adata, max_cells=MAX_CELLS_THRESHOLD, target_cells=TARGET_CELLS_AFTER_DOWNSAMPLE):
    """
    Downsample large datasets to improve rendering performance.
    Uses uniform sampling to preserve cell type distribution.
    """
    n_cells = adata.n_obs
    if n_cells > max_cells:
        step = int(n_cells / target_cells)
        indices = list(range(0, n_cells, step))[:target_cells]
        return adata[indices].copy(), True
    return adata, False


@lru_cache(maxsize=CACHE_MAXSIZE)
def load_and_process_adata_cached(saids_tuple):
    """
    Cached version of data loading and processing.
    Uses tuple for saids since lists are not hashable.
    Returns processed AnnData object.
    """
    saids = list(saids_tuple)
    return _load_integrated_adata_impl(saids)


def _load_integrated_adata_impl(saids: list):
    """
    Loads the master .h5ad file, selects specified SAIDs, and performs integration and UMAP.
    """
    if not os.path.exists(H5AD_PATH):
        raise FileNotFoundError(f"Master H5AD file not found: {H5AD_PATH}")

    # Load the entire master AnnData object
    adata = sc.read_h5ad(H5AD_PATH)

    # 确保用于筛选的列存在于 adata.obs
    ACTUAL_SAMPLE_IDENTIFIER_COLUMN = 'GSM'
    if ACTUAL_SAMPLE_IDENTIFIER_COLUMN not in adata.obs.columns:
        raise ValueError(f"The '{ACTUAL_SAMPLE_IDENTIFIER_COLUMN}' column is missing in the master H5AD's .obs. "
                         f"Cannot filter by SAIDs. Available columns: {adata.obs.columns.tolist()}")

    # 过滤选定的 SAIDs (现在是 GSM 编号)
    adata_filtered = adata[adata.obs[ACTUAL_SAMPLE_IDENTIFIER_COLUMN].isin(saids)].copy()

    if adata_filtered.n_obs == 0:
        raise ValueError(f"No data found for the selected SAIDs ({saids}). "
                         f"Please check SAID values or master H5AD content and the '{ACTUAL_SAMPLE_IDENTIFIER_COLUMN}' column.")

    # 执行集成和 UMAP 步骤
    sc.pp.normalize_total(adata_filtered, target_sum=1e4)
    sc.pp.log1p(adata_filtered)
    sc.pp.highly_variable_genes(adata_filtered, min_mean=0.0125, max_mean=3, min_disp=0.5)
    adata_filtered = adata_filtered[:, adata_filtered.var['highly_variable']]
    sc.pp.scale(adata_filtered, max_value=10)
    sc.tl.pca(adata_filtered, svd_solver='arpack')
    sc.pp.neighbors(adata_filtered)
    sc.tl.umap(adata_filtered)
    sc.tl.leiden(adata_filtered, key_added="integrated_clusters")

    return adata_filtered

# Dash 应用布局 with loading indicator
app.layout = html.Div(
    style={
        'width': '100%',
        'height': '100vh',
        'display': 'flex',
        'flexDirection': 'column'
    },
    children=[
        dcc.Location(id="url", refresh=False),
        # Store for tracking downsampling status
        dcc.Store(id="downsample-info"),
        html.Div(
            style={
                'padding': '10px',
                'textAlign': 'right',
                'background': '#f8f8f8',
                'borderBottom': '1px solid #eee',
                'display': 'flex',
                'justifyContent': 'space-between',
                'alignItems': 'center'
            },
            children=[
                # Status message (shows downsampling info)
                html.Div(id="status-message", style={
                    'fontSize': '12px',
                    'color': '#666',
                    'paddingLeft': '10px'
                }),
                # Back button
                html.A(
                    html.Button('Back', style={'marginRight': '10px'}),
                    href="http://localhost:8080/scrna_website_test_war/search.jsp",
                    target="_self"
                ),
            ]
        ),
        # Loading wrapper for the graph
        dcc.Loading(
            id="loading-indicator",
            type="circle",
            color="#e8927c",
            children=[
                html.Div(
                    style={
                        'flex': 1,
                        'display': 'flex'
                    },
                    children=[
                        dcc.Graph(
                            id='umap-plot',
                            style={'width': '100%', 'height': '100%'},
                            config={
                                'responsive': True,
                                'displayModeBar': True,
                                'toImageButtonOptions': {
                                    'format': 'png',
                                    'filename': 'integrated_umap_plot'
                                }
                            }
                        )
                    ]
                )
            ]
        )
    ]
)

@app.callback(
    [Output("umap-plot", "figure"),
     Output("status-message", "children")],
    [Input("url", "search")]
)
def update_umap(search):
    # 解析 URL 参数
    params = parse_qs(search.lstrip("?"))
    saids_str = params.get("saids", [None])[0]

    if not saids_str:
        return px.scatter(title="Error: No SAIDs (GSMs) provided in URL."), ""

    selected_saids = saids_str.split(',')

    if len(selected_saids) < 2:
        return px.scatter(title="Error: Please select at least two datasets for integration."), ""

    # Load and process data using cached function
    try:
        # Convert to tuple for caching (lists are not hashable)
        saids_tuple = tuple(sorted(selected_saids))
        adata = load_and_process_adata_cached(saids_tuple)
    except FileNotFoundError as e:
        print(f"File not found: {e}")
        return px.scatter(title="Error: Data file not found. Please contact administrator."), "Error: Data file not found"
    except ValueError as e:
        print(f"Value error: {e}")
        return px.scatter(title=f"Error: {str(e)[:100]}"), f"Error: {str(e)[:50]}"
    except Exception as e:
        print(f"Error loading or processing data: {e}")
        return px.scatter(title="Error: Failed to process data. Please try again."), "Processing error"

    # Apply downsampling for large datasets
    adata_display, was_downsampled = downsample_if_needed(adata)

    # Generate status message
    status_msg = ""
    if was_downsampled:
        status_msg = f"Showing {adata_display.n_obs:,} of {adata.n_obs:,} cells (downsampled for performance)"
    else:
        status_msg = f"Showing {adata_display.n_obs:,} cells"

    # Check required columns for coloring
    REQUIRED_COLS_FOR_COLORING = ['GSM', 'Gross_Map']
    for col in REQUIRED_COLS_FOR_COLORING:
        if col not in adata_display.obs.columns:
            return px.scatter(
                title=f"Error: Required column '{col}' not found in data."
            ), f"Missing column: {col}"

    # Build UMAP DataFrame from downsampled data
    df_umap = pd.DataFrame(
        adata_display.obsm["X_umap"],
        index=adata_display.obs.index,
        columns=["UMAP1", "UMAP2"]
    )

    # Add metadata columns
    df_umap['GSM'] = adata_display.obs['GSM'].values
    df_umap['Gross_Map'] = adata_display.obs['Gross_Map'].values

    # Add integrated_clusters if available
    if 'integrated_clusters' in adata_display.obs.columns:
        df_umap['integrated_clusters'] = adata_display.obs['integrated_clusters'].astype(str).values

    # Generate color sequence with enough unique colors
    color_sequence = (
        pcolors.qualitative.Alphabet +
        pcolors.qualitative.Light24 +
        pcolors.qualitative.Plotly +
        pcolors.qualitative.Bold
    )

    # Prepare hover data columns
    hover_data_cols = {
        "GSM": True,
        "Gross_Map": True
    }
    if 'integrated_clusters' in df_umap.columns:
        hover_data_cols['integrated_clusters'] = True

    # Create scatter plot
    fig = px.scatter(
        df_umap,
        x="UMAP1",
        y="UMAP2",
        color="Gross_Map",
        title=f"Integrated UMAP Plot for GSMs: {', '.join(selected_saids)}",
        hover_data=hover_data_cols,
        labels={"color": "Cell Type"},
        color_discrete_sequence=color_sequence
    )

    fig.update_layout(
        autosize=True,
        margin=dict(l=10, r=10, t=40, b=10),
        legend=dict(
            orientation="v",
            yanchor="top",
            y=1,
            xanchor="left",
            x=1.02
        )
    )

    return fig, status_msg

if __name__ == "__main__":
    server.run(debug=True, host="0.0.0.0", port=8050)