"""
Gene Expression UMAP Visualization for scSAID
Displays integrated UMAP with gene expression overlay for selected genes
"""

import os
import sys
import json
import numpy as np
import pandas as pd
import scanpy as sc
from scipy.sparse import issparse

from flask import Flask, request, jsonify
from dash import Dash, html, dcc, Input, Output, State, ctx
import plotly.graph_objects as go

# Configuration
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INTEGRATED_FILE = os.path.join(BASE_DIR, "integrated.h5ad")
DATASET_INFO_FILE = "/Users/coellearth/Library/Mobile Documents/com~apple~CloudDocs/SkinDB_web/src/main/webapp/WEB-INF/IntegrateTable.xlsx"

print("=" * 60)
print("Gene Expression UMAP Visualization Server")
print("=" * 60)

# Load or create integrated dataset
INTEGRATED_DATA = None

def load_integrated_data():
    """Load integrated h5ad file if it exists"""
    global INTEGRATED_DATA

    if os.path.exists(INTEGRATED_FILE):
        print(f"Loading integrated dataset from {INTEGRATED_FILE}")
        INTEGRATED_DATA = sc.read_h5ad(INTEGRATED_FILE)
        print(f"Loaded {INTEGRATED_DATA.n_obs} cells, {INTEGRATED_DATA.n_vars} genes")

        # Ensure UMAP coordinates exist
        if 'X_umap' not in INTEGRATED_DATA.obsm:
            print("Warning: No UMAP coordinates found in integrated data")
            print("Computing UMAP...")
            sc.pp.neighbors(INTEGRATED_DATA)
            sc.tl.umap(INTEGRATED_DATA)

        return True
    else:
        print(f"Warning: Integrated dataset not found at {INTEGRATED_FILE}")
        print("Please create integrated.h5ad file first")
        return False

DATA_LOADED = load_integrated_data()

# Flask/Dash app
server = Flask(__name__)
app = Dash(__name__, server=server, url_base_pathname="/gene-viz/")

# Warm scientific aesthetic matching scSAID
COLORS = {
    'coral': '#e8927c',
    'bronze': '#d4a574',
    'beige': '#faf8f5',
    'navy': '#1a2332',
    'taupe': '#e5e0d8',
    'light_gray': '#f5f3f0',
}

def get_gene_expression(gene_names):
    """Get expression values for specified genes"""
    if not DATA_LOADED or INTEGRATED_DATA is None:
        return None

    # Convert to list if single gene
    if isinstance(gene_names, str):
        gene_names = [gene_names]

    # Find genes in dataset
    valid_genes = [g for g in gene_names if g in INTEGRATED_DATA.var_names]

    if len(valid_genes) == 0:
        return None

    # Get UMAP coordinates
    umap_coords = INTEGRATED_DATA.obsm['X_umap']

    # Get expression matrix
    expr_matrix = INTEGRATED_DATA.X.toarray() if issparse(INTEGRATED_DATA.X) else INTEGRATED_DATA.X

    # Get gene indices
    gene_indices = [list(INTEGRATED_DATA.var_names).index(g) for g in valid_genes]

    # Calculate mean expression if multiple genes
    if len(valid_genes) == 1:
        expression = expr_matrix[:, gene_indices[0]]
    else:
        expression = expr_matrix[:, gene_indices].mean(axis=1)

    # Get metadata
    cell_types = INTEGRATED_DATA.obs.get('cell_type', pd.Series(['Unknown'] * INTEGRATED_DATA.n_obs))
    datasets = INTEGRATED_DATA.obs.get('dataset', pd.Series(['Unknown'] * INTEGRATED_DATA.n_obs))

    return {
        'umap_x': umap_coords[:, 0].tolist(),
        'umap_y': umap_coords[:, 1].tolist(),
        'expression': expression.tolist(),
        'cell_types': cell_types.tolist(),
        'datasets': datasets.tolist(),
        'genes': valid_genes,
        'n_cells': INTEGRATED_DATA.n_obs,
    }

def create_umap_plot(data, gene_names):
    """Create interactive UMAP plot with gene expression overlay"""
    if data is None:
        return go.Figure().add_annotation(
            text="No data available",
            xref="paper", yref="paper",
            x=0.5, y=0.5, showarrow=False,
            font=dict(size=20, color=COLORS['navy'])
        )

    # Normalize expression for color mapping (0-1 scale)
    expr = np.array(data['expression'])
    expr_norm = (expr - expr.min()) / (expr.max() - expr.min() + 1e-10)

    # Create hover text
    hover_text = [
        f"Cell Type: {ct}<br>Dataset: {ds}<br>Expression: {exp:.3f}"
        for ct, ds, exp in zip(data['cell_types'], data['datasets'], expr)
    ]

    # Create scatter plot
    fig = go.Figure()

    # Add cells colored by expression
    fig.add_trace(go.Scattergl(
        x=data['umap_x'],
        y=data['umap_y'],
        mode='markers',
        marker=dict(
            size=3,
            color=expr,
            colorscale=[
                [0, '#f5f3f0'],      # Very light for zero expression
                [0.1, '#ffeaa7'],    # Light yellow
                [0.3, '#fab1a0'],    # Peach
                [0.5, '#e8927c'],    # Coral (brand color)
                [0.7, '#e17055'],    # Darker coral
                [1, '#d63031']       # Deep red for high expression
            ],
            colorbar=dict(
                title=dict(
                    text="Expression",
                    font=dict(family='Source Sans 3', size=14, color=COLORS['navy'])
                ),
                thickness=15,
                len=0.7,
                bgcolor='rgba(255,255,255,0.8)',
                bordercolor=COLORS['taupe'],
                borderwidth=1,
                tickfont=dict(family='Source Sans 3', size=11, color=COLORS['navy'])
            ),
            line=dict(width=0),
            opacity=0.6
        ),
        text=hover_text,
        hoverinfo='text',
        name='Cells'
    ))

    # Update layout with warm aesthetic
    gene_display = ', '.join(gene_names) if isinstance(gene_names, list) else gene_names

    fig.update_layout(
        title=dict(
            text=f"<b>{gene_display}</b> Expression on Integrated UMAP",
            font=dict(family='Cormorant Garamond', size=24, color=COLORS['navy']),
            x=0.5,
            xanchor='center'
        ),
        xaxis=dict(
            title="UMAP 1",
            showgrid=False,
            zeroline=False,
            showticklabels=True,
            tickfont=dict(family='Source Sans 3', size=11, color=COLORS['navy']),
            titlefont=dict(family='Source Sans 3', size=13, color=COLORS['navy'])
        ),
        yaxis=dict(
            title="UMAP 2",
            showgrid=False,
            zeroline=False,
            showticklabels=True,
            tickfont=dict(family='Source Sans 3', size=11, color=COLORS['navy']),
            titlefont=dict(family='Source Sans 3', size=13, color=COLORS['navy'])
        ),
        plot_bgcolor=COLORS['beige'],
        paper_bgcolor='white',
        margin=dict(l=60, r=60, t=80, b=60),
        hovermode='closest',
        font=dict(family='Source Sans 3', color=COLORS['navy']),
        height=700
    )

    return fig

# Dash Layout
app.layout = html.Div([
    dcc.Location(id='url', refresh=False),

    # Main container
    html.Div([
        # Header
        html.Div([
            html.H2("Gene Expression Visualization",
                   style={
                       'fontFamily': 'Cormorant Garamond',
                       'color': COLORS['navy'],
                       'marginBottom': '0.5rem',
                       'fontWeight': '600'
                   }),
            html.P("Visualize gene expression patterns on integrated UMAP",
                  style={
                      'fontFamily': 'Source Sans 3',
                      'color': COLORS['navy'],
                      'opacity': '0.7',
                      'fontSize': '1rem'
                  })
        ], style={'marginBottom': '2rem'}),

        # Status message
        html.Div(id='status-message', style={
            'padding': '1rem',
            'borderRadius': '8px',
            'marginBottom': '1.5rem',
            'display': 'none'
        }),

        # Plot container
        html.Div([
            dcc.Graph(
                id='umap-plot',
                config={
                    'displayModeBar': True,
                    'toImageButtonOptions': {
                        'format': 'png',
                        'filename': 'gene_expression_umap',
                        'height': 1200,
                        'width': 1400,
                        'scale': 2
                    },
                    'modeBarButtonsToRemove': ['select2d', 'lasso2d']
                }
            )
        ], style={
            'backgroundColor': 'white',
            'borderRadius': '12px',
            'padding': '1.5rem',
            'boxShadow': '0 2px 8px rgba(0,0,0,0.08)',
            'border': f'1px solid {COLORS["taupe"]}'
        }),

        # Dataset info
        html.Div(id='dataset-info', style={
            'marginTop': '1.5rem',
            'padding': '1rem',
            'backgroundColor': COLORS['light_gray'],
            'borderRadius': '8px',
            'fontFamily': 'Source Sans 3',
            'fontSize': '0.9rem',
            'color': COLORS['navy']
        })

    ], style={
        'maxWidth': '1400px',
        'margin': '0 auto',
        'padding': '2rem',
        'backgroundColor': COLORS['beige'],
        'minHeight': '100vh'
    }),

    # Hidden div for storing data
    dcc.Store(id='gene-data', data=None)

], style={'fontFamily': 'Source Sans 3'})

@app.callback(
    [Output('umap-plot', 'figure'),
     Output('status-message', 'children'),
     Output('status-message', 'style'),
     Output('dataset-info', 'children'),
     Output('gene-data', 'data')],
    [Input('url', 'search')]
)
def update_plot(search):
    """Update plot based on URL parameters"""

    # Default empty state
    default_fig = go.Figure()
    default_fig.update_layout(
        plot_bgcolor=COLORS['beige'],
        paper_bgcolor='white',
        height=700
    )
    default_fig.add_annotation(
        text="Select genes from the search results to visualize",
        xref="paper", yref="paper",
        x=0.5, y=0.5, showarrow=False,
        font=dict(size=16, color=COLORS['navy'], family='Source Sans 3')
    )

    default_status_style = {'display': 'none'}

    if not DATA_LOADED:
        error_fig = default_fig
        error_fig.layout.annotations[0].text = "Integrated dataset not available"

        return (
            error_fig,
            html.Div([
                html.Strong("⚠️ Integrated Dataset Not Found"),
                html.P("Please create integrated.h5ad file first. See documentation for instructions.")
            ]),
            {
                'padding': '1rem',
                'borderRadius': '8px',
                'marginBottom': '1.5rem',
                'backgroundColor': '#fff3cd',
                'border': '1px solid #ffc107',
                'color': '#856404',
                'display': 'block'
            },
            "",
            None
        )

    # Parse URL parameters
    if not search or search == '':
        return default_fig, "", default_status_style, "", None

    # Extract genes parameter
    params = {}
    for param in search.lstrip('?').split('&'):
        if '=' in param:
            key, value = param.split('=', 1)
            params[key] = value

    genes_param = params.get('genes', '')
    if not genes_param:
        return default_fig, "", default_status_style, "", None

    # Parse gene list (comma-separated)
    gene_names = [g.strip().upper() for g in genes_param.split(',') if g.strip()]

    if len(gene_names) == 0:
        return default_fig, "", default_status_style, "", None

    # Get gene expression data
    data = get_gene_expression(gene_names)

    if data is None:
        error_fig = default_fig
        error_fig.layout.annotations[0].text = f"Genes not found: {', '.join(gene_names)}"

        return (
            error_fig,
            html.Div([
                html.Strong("Gene(s) Not Found"),
                html.P(f"The following genes were not found in the integrated dataset: {', '.join(gene_names)}")
            ]),
            {
                'padding': '1rem',
                'borderRadius': '8px',
                'marginBottom': '1.5rem',
                'backgroundColor': '#f8d7da',
                'border': '1px solid #f5c6cb',
                'color': '#721c24',
                'display': 'block'
            },
            "",
            None
        )

    # Create plot
    fig = create_umap_plot(data, data['genes'])

    # Success message
    gene_display = ', '.join(data['genes'])
    n_genes = len(data['genes'])

    success_msg = html.Div([
        html.Strong("✓ Visualization Generated"),
        html.P(f"Showing expression of {n_genes} gene{'s' if n_genes > 1 else ''}: {gene_display}")
    ])

    success_style = {
        'padding': '1rem',
        'borderRadius': '8px',
        'marginBottom': '1.5rem',
        'backgroundColor': '#d4edda',
        'border': '1px solid #c3e6cb',
        'color': '#155724',
        'display': 'block'
    }

    # Dataset info
    info_text = f"Displaying {data['n_cells']:,} cells across all integrated datasets"

    return fig, success_msg, success_style, info_text, data

# API endpoint for getting available genes
@server.route('/api/genes')
def get_available_genes():
    """Return list of available genes"""
    if not DATA_LOADED or INTEGRATED_DATA is None:
        return jsonify({'error': 'Integrated dataset not loaded'}), 500

    genes = sorted(INTEGRATED_DATA.var_names.tolist())
    return jsonify({'genes': genes, 'count': len(genes)})

@server.route('/api/gene-info/<gene_name>')
def get_gene_info(gene_name):
    """Get information about a specific gene"""
    if not DATA_LOADED or INTEGRATED_DATA is None:
        return jsonify({'error': 'Integrated dataset not loaded'}), 500

    gene_name = gene_name.upper()

    if gene_name not in INTEGRATED_DATA.var_names:
        return jsonify({'error': f'Gene {gene_name} not found'}), 404

    # Get expression statistics
    gene_idx = list(INTEGRATED_DATA.var_names).index(gene_name)
    expr_matrix = INTEGRATED_DATA.X.toarray() if issparse(INTEGRATED_DATA.X) else INTEGRATED_DATA.X
    expression = expr_matrix[:, gene_idx]

    info = {
        'gene': gene_name,
        'mean_expression': float(np.mean(expression)),
        'max_expression': float(np.max(expression)),
        'pct_expressed': float(np.sum(expression > 0) / len(expression) * 100),
        'n_cells': int(INTEGRATED_DATA.n_obs)
    }

    return jsonify(info)

if __name__ == "__main__":
    print("\nStarting Gene Expression Visualization server on port 8053...")
    print("Access at: http://localhost:8053/gene-viz/")
    print("=" * 60)
    print()
    server.run(debug=False, host="127.0.0.1", port=8053)
