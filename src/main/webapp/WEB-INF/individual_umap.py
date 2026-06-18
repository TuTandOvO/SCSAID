import os
import pandas as pd
import scanpy as sc
from flask import Flask, request
from dash import Dash, html, dcc
from dash.dependencies import Input, Output
import plotly.express as px
import plotly.colors as pcolors
import json
from urllib.parse import urlparse, parse_qs

# Flask + Dash initialization
server = Flask(__name__)
app = Dash(__name__, server=server, url_base_pathname="/individual-umap/")

# Path to the data root directory
DATA_ROOT = "/opt/SkinDB"
DOWNLOAD_DATA_RELATIVE_PATH = "download_data"

def get_individual_h5ad_path(data_root, said):
    """
    Constructs the path to the individual H5AD file for a given SAID.
    Based on the mapping from the Java code.
    """
    # First, we need to find the GSE and GSM for the given SAID from the CSV files
    human_csv_path = os.path.join(data_root, "human", "human_obs_by_batch.csv")
    mouse_csv_path = os.path.join(data_root, "mouse", "mouse_obs_by_batch.csv")

    # Look for the SAID in both CSV files to get GSE and GSM
    gse = None
    gsm = None
    species = None

    for csv_path, current_species in [(human_csv_path, "human"), (mouse_csv_path, "mouse")]:
        if os.path.exists(csv_path):
            df = pd.read_csv(csv_path)
            # Find the row where the SAID column matches our SAID
            # Assuming the column with SAIDs is named 'SAID' or similar
            # Looking at the CSV sample earlier, the SAID appears to be in the 11th column (index 10)
            for idx, row in df.iterrows():
                if len(row) > 10 and str(row.iloc[10]) == said:  # SAID column
                    gse = str(row.iloc[9])  # GSE column
                    gsm = str(row.iloc[5])  # GSM column
                    species = current_species
                    break

        if gse and gsm and species:
            break

    if not gse or not gsm or not species:
        return None

    # Build the expected H5AD file path
    h5ad_filename = f"{gse}_{gsm}.h5ad"
    h5ad_path = os.path.join(data_root, DOWNLOAD_DATA_RELATIVE_PATH, "10X", species, gse, gsm, h5ad_filename)

    return h5ad_path if os.path.exists(h5ad_path) else None

def compute_umap_if_missing(adata):
    """
    Computes UMAP if it's not already present in the AnnData object.
    """
    if 'X_umap' not in adata.obsm_keys():
        # Perform basic preprocessing if needed
        if 'highly_variable' not in adata.var.keys():
            # Normalize and find highly variable genes
            sc.pp.normalize_total(adata, target_sum=1e4)
            sc.pp.log1p(adata)
            sc.pp.highly_variable_genes(adata, min_mean=0.0125, max_mean=3, min_disp=0.5)

        # Filter to highly variable genes
        adata_temp = adata[:, adata.var['highly_variable']].copy() if 'highly_variable' in adata.var.keys() else adata

        # Scale and compute PCA
        sc.pp.scale(adata_temp, max_value=10)
        sc.tl.pca(adata_temp, svd_solver='arpack')

        # Compute neighbors and UMAP
        sc.pp.neighbors(adata_temp)
        sc.tl.umap(adata_temp)

        # Copy the computed UMAP back to the original adata
        adata.obsm['X_umap'] = adata_temp.obsm['X_umap']

        # Also copy other relevant computed components
        if 'X_pca' in adata_temp.obsm_keys():
            adata.obsm['X_pca'] = adata_temp.obsm['X_pca']

        if 'leiden' in adata_temp.obs.keys():
            adata.obs['leiden'] = adata_temp.obs['leiden']

def downsample_if_needed(adata, max_cells=8000, target_cells=5000):
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

# Dash app layout with loading indicator
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
                    href="/scrna_website_test/browse.jsp",
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
                                    'filename': 'individual_umap_plot'
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
def update_umap_individual(search):
    # Parse URL parameters to get SAID
    parsed_url = urlparse(f"?{search}" if search.startswith('?') else search)
    params = parse_qs(parsed_url.query)
    said = params.get("said", [None])[0]

    if not said:
        return px.scatter(title="Error: No SAID provided in URL."), "Error: No SAID provided"

    # Attempt to find and load the H5AD file for this specific SAID
    try:
        h5ad_path = get_individual_h5ad_path(DATA_ROOT, said)
        if not h5ad_path:
            return px.scatter(title=f"Error: H5AD file not found for SAID {said}."), f"File not found for {said}"

        # Load the AnnData object
        adata = sc.read_h5ad(h5ad_path)

        # Compute UMAP if it doesn't exist
        compute_umap_if_missing(adata)

        # Apply downsampling for large datasets
        adata_display, was_downsampled = downsample_if_needed(adata)

        # Generate status message
        status_msg = ""
        if was_downsampled:
            status_msg = f"Showing {adata_display.n_obs:,} of {adata.n_obs:,} cells (downsampled for performance)"
        else:
            status_msg = f"Showing {adata_display.n_obs:,} cells"

        # Prepare the UMAP visualization
        # Check if UMAP coordinates exist
        if 'X_umap' not in adata_display.obsm_keys():
            return px.scatter(title="Error: UMAP coordinates not found in dataset."), "No UMAP coordinates"

        # Build UMAP DataFrame
        df_umap = pd.DataFrame(
            adata_display.obsm["X_umap"],
            index=adata_display.obs.index,
            columns=["UMAP1", "UMAP2"]
        )

        # Add available metadata columns for coloring and hover
        # Check for available metadata columns in obs
        metadata_cols = []
        for col in ['Gross_Map', 'cell_type', 'leiden', 'GSM', 'GSE']:
            if col in adata_display.obs.columns:
                df_umap[col] = adata_display.obs[col].values
                metadata_cols.append(col)

        # Choose a column for coloring (preferably cell type related)
        color_col = 'Gross_Map' if 'Gross_Map' in metadata_cols else \
                   'cell_type' if 'cell_type' in metadata_cols else \
                   'leiden' if 'leiden' in metadata_cols else None

        # Generate color sequence with enough unique colors
        color_sequence = (
            pcolors.qualitative.Alphabet +
            pcolors.qualitative.Light24 +
            pcolors.qualitative.Plotly +
            pcolors.qualitative.Bold
        )

        # Prepare hover data columns
        hover_data_cols = {col: True for col in metadata_cols}

        # Create scatter plot
        if color_col:
            fig = px.scatter(
                df_umap,
                x="UMAP1",
                y="UMAP2",
                color=color_col,
                title=f"Individual Dataset UMAP for SAID: {said}",
                hover_data=hover_data_cols,
                labels={"color": color_col},
                color_discrete_sequence=color_sequence
            )
        else:
            fig = px.scatter(
                df_umap,
                x="UMAP1",
                y="UMAP2",
                title=f"Individual Dataset UMAP for SAID: {said}",
                hover_data=hover_data_cols
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

    except FileNotFoundError as e:
        print(f"File not found: {e}")
        return px.scatter(title="Error: Data file not found. Please contact administrator."), "Error: Data file not found"
    except ValueError as e:
        print(f"Value error: {e}")
        return px.scatter(title=f"Error: {str(e)[:100]}"), f"Error: {str(e)[:50]}"
    except Exception as e:
        print(f"Error loading or processing data: {e}")
        import traceback
        traceback.print_exc()
        return px.scatter(title="Error: Failed to process data. Please try again."), "Processing error"

if __name__ == "__main__":
    server.run(debug=True, host="0.0.0.0", port=8051)