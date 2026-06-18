#!/usr/bin/env python3
"""
Individual Dataset Visualization Suite for scSAID
Provides visualization tools for individual single-cell RNA-seq datasets
"""

import sys
import os
import argparse
import dash
from dash import dcc, html, Input, Output, State, callback_context
import plotly.graph_objects as go
import plotly.express as px
import scanpy as sc
import pandas as pd
import numpy as np
from pathlib import Path
import json
from scipy import sparse
try:
    from scipy.cluster.hierarchy import linkage, leaves_list
except Exception:  # pragma: no cover - optional clustering dependency
    linkage = None
    leaves_list = None

# Initialize Dash app
app = dash.Dash(
    __name__,
    url_base_pathname='/viz/',
    suppress_callback_exceptions=True
)

app.title = "scSAID Individual Visualization Suite"

# Global variables
current_adata = None
dataset_id = None
viz_type = "individual"
MAX_GENE_OPTIONS = 5000
MAX_PLOT_CELLS = 8000


def load_dataset(dataset_path, dataset_type="individual"):
    """
    Load dataset from H5AD file and preprocess if needed for individual datasets
    """
    global current_adata, viz_type

    try:
        current_adata = sc.read_h5ad(dataset_path)
        viz_type = dataset_type
        print(f"Dataset loaded successfully: {current_adata.n_obs} cells, {current_adata.n_vars} genes")

        # For individual datasets, if UMAP is not computed, calculate it
        if dataset_type == "individual" and 'X_umap' not in current_adata.obsm_keys():
            print("Computing UMAP for individual dataset...")

            # Perform minimal preprocessing for visualization
            if 'highly_variable' not in current_adata.var.keys():
                # Basic normalization and identification of highly variable genes
                sc.pp.normalize_total(current_adata, target_sum=1e4)
                sc.pp.log1p(current_adata)
                # Identify highly variable genes
                sc.pp.highly_variable_genes(current_adata, min_mean=0.0125, max_mean=3, min_disp=0.5)

            # Work with highly variable genes for efficiency
            adata_subset = current_adata[:, current_adata.var['highly_variable']] if 'highly_variable' in current_adata.var.keys() else current_adata

            # Scale the data
            sc.pp.scale(adata_subset, max_value=10)

            # Compute PCA
            sc.tl.pca(adata_subset, svd_solver='arpack')

            # Compute neighborhood graph and UMAP
            sc.pp.neighbors(adata_subset)
            sc.tl.umap(adata_subset)

            # Copy the computed UMAP back to the full dataset
            current_adata.obsm['X_umap'] = adata_subset.obsm['X_umap']

            if 'X_pca' in adata_subset.obsm_keys():
                current_adata.obsm['X_pca'] = adata_subset.obsm['X_pca']

            print("UMAP computation completed for individual dataset.")

        print(f"Visualization type: {dataset_type}")
        return True
    except Exception as e:
        print(f"Error loading dataset: {str(e)}")
        return False


def _to_dense(matrix):
    if sparse.issparse(matrix):
        return matrix.toarray()
    return np.asarray(matrix)


def _flatten_expr(matrix):
    return np.ravel(_to_dense(matrix))


def _resolve_groupby(adata, requested):
    if requested in adata.obs.columns:
        return requested
    if len(adata.obs.columns) == 0:
        return None
    return adata.obs.columns[0]


def _get_obs_options(adata, max_unique=50):
    options = []
    for col in adata.obs.columns:
        try:
            unique = adata.obs[col].nunique()
        except Exception:
            continue
        if unique <= max_unique:
            options.append({'label': col, 'value': col})
    return options


def _sample_indices(n_obs, max_points):
    if n_obs <= max_points:
        return np.arange(n_obs)
    return np.random.choice(n_obs, size=max_points, replace=False)


# Main layout
app.layout = html.Div([
    html.Div([
        html.H1("Individual Dataset Visualization Suite", className="viz-title"),
        html.P("Explore your individual single-cell RNA-seq data with advanced interactive visualizations",
               className="viz-subtitle")
    ], className="viz-header"),

    dcc.Store(id='dataset-store', data=None),
    dcc.Store(id='selected-genes-store', data=[]),

    # Navigation Tabs
    html.Div([
        dcc.Tabs(id='viz-tabs', value='umap-3d', children=[
            dcc.Tab(label='3D UMAP', value='umap-3d', className='custom-tab'),
            dcc.Tab(label='3D tSNE', value='tsne-3d', className='custom-tab'),
            dcc.Tab(label='Dot Plot', value='dotplot', className='custom-tab'),
            dcc.Tab(label='Violin Plot', value='violin', className='custom-tab'),
            dcc.Tab(label='Split Violin', value='split-violin', className='custom-tab'),
            dcc.Tab(label='Stacked Violin', value='stacked-violin', className='custom-tab'),
            dcc.Tab(label='Heatmap', value='heatmap', className='custom-tab'),
            dcc.Tab(label='Feature Plot', value='feature', className='custom-tab'),
            dcc.Tab(label='Gene Expression', value='gene-expr', className='custom-tab'),
            dcc.Tab(label='Sankey', value='sankey', className='custom-tab'),
            dcc.Tab(label='Correlation', value='correlation', className='custom-tab'),
        ], className='custom-tabs-container')
    ], className="tabs-wrapper"),

    # Control Panel
    html.Div([
        html.Div([
            html.Label("Color by:", className="control-label"),
            dcc.Dropdown(
                id='color-by-dropdown',
                options=[
                    {'label': 'Cell Type (Gross)', 'value': 'Gross_Map'},
                    {'label': 'Cell Type', 'value': 'cell_type'},
                    {'label': 'Cluster', 'value': 'leiden'},
                    {'label': 'Dataset', 'value': 'dataset'},
                    {'label': 'Sample', 'value': 'sample'}
                ],
                value='Gross_Map',
                className='control-dropdown'
            )
        ], className="control-group"),
        html.Div([
            html.Label("Secondary group:", className="control-label"),
            dcc.Dropdown(
                id='secondary-group-dropdown',
                options=[],
                value=None,
                clearable=True,
                placeholder="Optional (split/sankey/correlation)",
                className='control-dropdown'
            )
        ], className="control-group"),

        html.Div([
            html.Label("Point Size:", className="control-label"),
            dcc.Slider(
                id='point-size-slider',
                min=1,
                max=10,
                value=3,
                marks={i: str(i) for i in range(1, 11)},
                className='control-slider'
            )
        ], className="control-group"),

        html.Div([
            html.Label("Opacity:", className="control-label"),
            dcc.Slider(
                id='opacity-slider',
                min=0.1,
                max=1.0,
                step=0.1,
                value=0.8,
                marks={i/10: f'{i/10:.1f}' for i in range(1, 11)},
                className='control-slider'
            )
        ], className="control-group"),

        html.Div([
            html.Button("Export PNG", id='export-png-btn', className='export-btn'),
            html.Button("Export SVG", id='export-svg-btn', className='export-btn'),
        ], className="control-group")
    ], className="control-panel"),

    # Main visualization area
    html.Div(id='viz-content', className="viz-content"),

    # Gene selection panel (for relevant plots)
    html.Div([
        html.H3("Select Genes", className="panel-title"),
        dcc.Dropdown(
            id='gene-selection',
            options=[],
            multi=True,
            placeholder="Search and select genes...",
            className='gene-dropdown'
        ),
        html.Button("Add Selected Genes", id='add-genes-btn', className='add-btn'),
        html.Button("Clear Genes", id='clear-genes-btn', className='add-btn'),
        html.Div(id='selected-genes-list', className='genes-list')
    ], className="gene-panel", id='gene-panel', style={'display': 'none'})

], className="viz-container")


@app.callback(
    [Output('gene-selection', 'options'),
     Output('secondary-group-dropdown', 'options')],
    Input('viz-tabs', 'value')
)
def update_dataset_options(_tab):
    if current_adata is None:
        return [], []

    gene_options = [{'label': g, 'value': g} for g in current_adata.var_names[:MAX_GENE_OPTIONS]]
    group_options = _get_obs_options(current_adata)
    return gene_options, group_options


@app.callback(
    Output('selected-genes-store', 'data'),
    [Input('add-genes-btn', 'n_clicks'),
     Input('clear-genes-btn', 'n_clicks')],
    [State('gene-selection', 'value'),
     State('selected-genes-store', 'data')]
)
def update_selected_genes(add_clicks, clear_clicks, selected, current):
    ctx = callback_context
    if not ctx.triggered:
        return current

    trigger = ctx.triggered[0]['prop_id'].split('.')[0]
    if trigger == 'clear-genes-btn':
        return []
    if trigger == 'add-genes-btn':
        return selected or []
    return current


@app.callback(
    Output('selected-genes-list', 'children'),
    Input('selected-genes-store', 'data')
)
def render_selected_genes(selected):
    if not selected:
        return html.P("No genes selected.", className="info-message")
    return html.Ul([html.Li(g) for g in selected])


@app.callback(
    [Output('viz-content', 'children'),
     Output('gene-panel', 'style')],
    [Input('viz-tabs', 'value'),
     Input('color-by-dropdown', 'value'),
     Input('secondary-group-dropdown', 'value'),
     Input('point-size-slider', 'value'),
     Input('opacity-slider', 'value'),
     Input('selected-genes-store', 'data')],
    [State('dataset-store', 'data')]
)
def render_visualization(tab, color_by, secondary_group, point_size, opacity, selected_genes, dataset_data):
    """
    Render the appropriate visualization based on selected tab
    """
    global current_adata

    if current_adata is None:
        return html.Div([
            html.P("No dataset loaded. Please load a dataset first.",
                   className="error-message")
        ], className="empty-state"), {'display': 'none'}

    # Determine if gene panel should be shown
    show_gene_panel = tab in [
        'dotplot', 'violin', 'split-violin', 'stacked-violin',
        'heatmap', 'feature', 'gene-expr', 'correlation'
    ]
    gene_panel_style = {'display': 'block'} if show_gene_panel else {'display': 'none'}

    try:
        if tab == 'umap-3d':
            return create_3d_umap(current_adata, color_by, point_size, opacity), gene_panel_style
        elif tab == 'tsne-3d':
            return create_3d_tsne(current_adata, color_by, point_size, opacity), gene_panel_style
        elif tab == 'dotplot':
            if not selected_genes or len(selected_genes) == 0:
                return html.Div("Please select genes to display dot plot", className="info-message"), gene_panel_style
            return create_dot_plot(current_adata, selected_genes, color_by), gene_panel_style
        elif tab == 'violin':
            if not selected_genes or len(selected_genes) == 0:
                return html.Div("Please select genes to display violin plot", className="info-message"), gene_panel_style
            return create_violin_plot(current_adata, selected_genes, color_by), gene_panel_style
        elif tab == 'split-violin':
            if not selected_genes or len(selected_genes) == 0:
                return html.Div("Please select a gene to display split violin plot", className="info-message"), gene_panel_style
            return create_split_violin_plot(current_adata, selected_genes[0], color_by, secondary_group), gene_panel_style
        elif tab == 'stacked-violin':
            if not selected_genes or len(selected_genes) == 0:
                return html.Div("Please select genes to display stacked violin plot", className="info-message"), gene_panel_style
            return create_stacked_violin_plot(current_adata, selected_genes, color_by), gene_panel_style
        elif tab == 'heatmap':
            if not selected_genes or len(selected_genes) == 0:
                return html.Div("Please select genes to display heatmap", className="info-message"), gene_panel_style
            return create_heatmap(current_adata, selected_genes, color_by), gene_panel_style
        elif tab == 'feature':
            if not selected_genes or len(selected_genes) == 0:
                return html.Div("Please select a gene to display feature plot", className="info-message"), gene_panel_style
            return create_feature_plot(current_adata, selected_genes[0], point_size, opacity), gene_panel_style
        elif tab == 'gene-expr':
            if not selected_genes or len(selected_genes) == 0:
                return html.Div("Please select genes to display expression", className="info-message"), gene_panel_style
            return create_gene_expression_plot(current_adata, selected_genes, color_by), gene_panel_style
        elif tab == 'sankey':
            return create_sankey_plot(current_adata, color_by, secondary_group), gene_panel_style
        elif tab == 'correlation':
            if not selected_genes or len(selected_genes) < 2:
                return html.Div("Please select at least two genes to display correlation", className="info-message"), gene_panel_style
            return create_correlation_plot(current_adata, selected_genes[:2], color_by), gene_panel_style
    except Exception as e:
        return html.Div(f"Error rendering visualization: {str(e)}", className="error-message"), gene_panel_style

    return html.Div("Visualization not implemented yet", className="info-message"), gene_panel_style


def create_3d_umap(adata, color_by='cell_type', point_size=3, opacity=0.8):
    """
    Create 3D UMAP visualization
    """
    if 'X_umap' not in adata.obsm:
        return html.Div("UMAP coordinates not available", className="error-message")

    umap_coords = adata.obsm['X_umap']
    if umap_coords.shape[1] >= 3:
        z_coords = umap_coords[:, 2]
    else:
        z_coords = np.zeros(umap_coords.shape[0])

    # Get color data
    groupby = _resolve_groupby(adata, color_by)
    if groupby:
        color_data = adata.obs[groupby].astype(str)
    else:
        color_data = ['Unknown'] * adata.n_obs

    # Create 3D scatter plot
    fig = go.Figure(data=[go.Scatter3d(
        x=umap_coords[:, 0],
        y=umap_coords[:, 1],
        z=z_coords if len(z_coords) > 0 else np.zeros(adata.n_obs),
        mode='markers',
        marker=dict(
            size=point_size,
            color=pd.Categorical(color_data).codes,
            colorscale='Viridis',
            opacity=opacity,
            line=dict(width=0)
        ),
        text=color_data,
        hovertemplate='<b>%{text}</b><br>UMAP1: %{x:.2f}<br>UMAP2: %{y:.2f}<br>UMAP3: %{z:.2f}<extra></extra>'
    )])

    fig.update_layout(
        scene=dict(
            xaxis_title='UMAP 1',
            yaxis_title='UMAP 2',
            zaxis_title='UMAP 3',
            camera=dict(eye=dict(x=1.5, y=1.5, z=1.3))
        ),
        height=700,
        margin=dict(l=0, r=0, t=30, b=0),
        paper_bgcolor='#faf8f5',
        plot_bgcolor='#faf8f5'
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_3d_tsne(adata, color_by='cell_type', point_size=3, opacity=0.8):
    """
    Create 3D tSNE visualization (uses precomputed X_tsne if available).
    """
    tsne_coords = None
    sampled = False

    if 'X_tsne' in adata.obsm:
        tsne_coords = adata.obsm['X_tsne']
        if tsne_coords.shape[1] == 2:
            z_coords = np.zeros(tsne_coords.shape[0])
        else:
            z_coords = tsne_coords[:, 2]
    else:
        if adata.n_obs == 0:
            return html.Div("No cells found in dataset", className="error-message")
        sample_idx = _sample_indices(adata.n_obs, MAX_PLOT_CELLS)
        adata_sample = adata[sample_idx].copy()
        try:
            sc.tl.tsne(adata_sample, n_components=3)
            tsne_coords = adata_sample.obsm.get('X_tsne')
            z_coords = tsne_coords[:, 2] if tsne_coords.shape[1] >= 3 else np.zeros(tsne_coords.shape[0])
            adata = adata_sample
            sampled = True
        except Exception as exc:
            return html.Div(f"tSNE coordinates not available: {exc}", className="error-message")

    groupby = _resolve_groupby(adata, color_by)
    if groupby:
        color_data = adata.obs[groupby].astype(str)
    else:
        color_data = ['Unknown'] * adata.n_obs

    fig = go.Figure(data=[go.Scatter3d(
        x=tsne_coords[:, 0],
        y=tsne_coords[:, 1],
        z=z_coords if len(z_coords) > 0 else np.zeros(adata.n_obs),
        mode='markers',
        marker=dict(
            size=point_size,
            color=pd.Categorical(color_data).codes,
            colorscale='Plasma',
            opacity=opacity,
            line=dict(width=0)
        ),
        text=color_data,
        hovertemplate='<b>%{text}</b><br>tSNE1: %{x:.2f}<br>tSNE2: %{y:.2f}<br>tSNE3: %{z:.2f}<extra></extra>'
    )])

    title_suffix = " (sampled)" if sampled else ""
    fig.update_layout(
        title=f'3D tSNE{title_suffix}',
        scene=dict(
            xaxis_title='tSNE 1',
            yaxis_title='tSNE 2',
            zaxis_title='tSNE 3',
            camera=dict(eye=dict(x=1.5, y=1.5, z=1.3))
        ),
        height=700,
        margin=dict(l=0, r=0, t=30, b=0),
        paper_bgcolor='#faf8f5',
        plot_bgcolor='#faf8f5'
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_dot_plot(adata, genes, groupby='cell_type'):
    """
    Create dot plot showing gene expression across groups
    """
    # Filter genes that exist in the dataset
    available_genes = [g for g in genes if g in adata.var_names]

    if len(available_genes) == 0:
        return html.Div(f"None of the selected genes found in dataset", className="error-message")

    groupby = _resolve_groupby(adata, groupby)
    if groupby is None:
        return html.Div("No grouping column available for dot plot", className="error-message")

    # Calculate mean expression and percent expressed
    dot_data = []

    for group in adata.obs[groupby].unique():
        subset = adata[adata.obs[groupby] == group]

        for gene in available_genes:
            if gene in adata.var_names:
                expr = _flatten_expr(subset[:, gene].X)
                mean_expr = np.mean(expr)
                pct_expr = (np.sum(expr > 0) / len(expr)) * 100

                dot_data.append({
                    'group': str(group),
                    'gene': gene,
                    'mean_expression': mean_expr,
                    'pct_expressed': pct_expr
                })

    df = pd.DataFrame(dot_data)

    # Create figure
    fig = go.Figure()

    for gene in available_genes:
        gene_data = df[df['gene'] == gene]

        fig.add_trace(go.Scatter(
            x=gene_data['group'],
            y=[gene] * len(gene_data),
            mode='markers',
            marker=dict(
                size=gene_data['pct_expressed'] / 2,
                color=gene_data['mean_expression'],
                colorscale='Reds',
                showscale=True,
                colorbar=dict(title="Mean<br>Expression"),
                sizemode='diameter',
                sizemin=4,
                line=dict(width=0.5, color='#333')
            ),
            name=gene,
            showlegend=False,
            hovertemplate='<b>%{y}</b> in %{x}<br>Mean Expression: %{marker.color:.2f}<br>% Expressed: %{marker.size:.1f}%<extra></extra>'
        ))

    fig.update_layout(
        title='Dot Plot: Gene Expression by Group',
        xaxis_title='Group',
        yaxis_title='Gene',
        height=max(400, len(available_genes) * 40),
        hovermode='closest',
        paper_bgcolor='#faf8f5',
        plot_bgcolor='white',
        xaxis=dict(tickangle=-45)
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_violin_plot(adata, genes, groupby='cell_type'):
    """
    Create violin plot for gene expression
    """
    available_genes = [g for g in genes if g in adata.var_names][:6]

    if len(available_genes) == 0:
        return html.Div(f"None of the selected genes found in dataset", className="error-message")

    groupby = _resolve_groupby(adata, groupby)
    if groupby is None:
        return html.Div("No grouping column available for violin plot", className="error-message")

    fig = go.Figure()

    for gene in available_genes:
        for group in adata.obs[groupby].unique():
            subset = adata[adata.obs[groupby] == group]
            expr = _flatten_expr(subset[:, gene].X)
            if len(expr) > MAX_PLOT_CELLS:
                expr = expr[_sample_indices(len(expr), MAX_PLOT_CELLS)]

            fig.add_trace(go.Violin(
                y=expr,
                x=[str(group)] * len(expr),
                name=f'{gene} - {group}',
                box_visible=True,
                meanline_visible=True,
                legendgroup=gene,
                scalegroup=gene,
                showlegend=True
            ))

    fig.update_layout(
        title='Violin Plot: Gene Expression Distribution',
        xaxis_title='Group',
        yaxis_title='Expression Level',
        height=600,
        violinmode='group',
        paper_bgcolor='#faf8f5',
        plot_bgcolor='white'
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_split_violin_plot(adata, gene, groupby='cell_type', split_by=None):
    """
    Create split violin plot (requires a secondary group with 2 categories).
    """
    if gene not in adata.var_names:
        return html.Div(f"Gene {gene} not found in dataset", className="error-message")

    groupby = _resolve_groupby(adata, groupby)
    if groupby is None:
        return html.Div("No grouping column available for split violin plot", className="error-message")

    if split_by is None or split_by not in adata.obs.columns:
        return html.Div("Select a secondary group (with 2 categories) for split violins", className="info-message")

    split_values = list(adata.obs[split_by].dropna().unique())
    if len(split_values) != 2:
        return html.Div("Split violin requires a secondary group with exactly 2 categories", className="info-message")

    colors = px.colors.qualitative.Set2
    fig = go.Figure()

    groups = adata.obs[groupby].unique()
    for group in groups:
        for idx, split_val in enumerate(split_values):
            mask = (adata.obs[groupby] == group) & (adata.obs[split_by] == split_val)
            expr = _flatten_expr(adata[mask, gene].X)
            if len(expr) == 0:
                continue
            if len(expr) > MAX_PLOT_CELLS:
                expr = expr[_sample_indices(len(expr), MAX_PLOT_CELLS)]

            fig.add_trace(go.Violin(
                y=expr,
                x=[str(group)] * len(expr),
                name=str(split_val),
                legendgroup=str(split_val),
                scalegroup=str(group),
                side='negative' if idx == 0 else 'positive',
                line_color=colors[idx % len(colors)],
                showlegend=(group == groups[0]),
                meanline_visible=True,
                points=False
            ))

    fig.update_layout(
        title=f'Split Violin: {gene} by {groupby} split by {split_by}',
        xaxis_title='Group',
        yaxis_title='Expression Level',
        height=600,
        violinmode='overlay',
        paper_bgcolor='#faf8f5',
        plot_bgcolor='white'
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_stacked_violin_plot(adata, genes, groupby='cell_type'):
    """
    Create stacked violin plots (one row per gene).
    """
    available_genes = [g for g in genes if g in adata.var_names][:6]
    if len(available_genes) == 0:
        return html.Div("None of the selected genes found in dataset", className="error-message")

    groupby = _resolve_groupby(adata, groupby)
    if groupby is None:
        return html.Div("No grouping column available for stacked violin plot", className="error-message")

    rows = []
    for gene in available_genes:
        expr = _flatten_expr(adata[:, gene].X)
        if len(expr) > MAX_PLOT_CELLS:
            idx = _sample_indices(len(expr), MAX_PLOT_CELLS)
            expr = expr[idx]
            group_vals = adata.obs[groupby].iloc[idx].astype(str).values
        else:
            group_vals = adata.obs[groupby].astype(str).values
        rows.append(pd.DataFrame({
            'gene': gene,
            'group': group_vals,
            'expression': expr
        }))

    df = pd.concat(rows, ignore_index=True)

    fig = px.violin(
        df,
        x='group',
        y='expression',
        color='group',
        facet_row='gene',
        box=True,
        points=False,
        category_orders={'gene': list(reversed(available_genes))}
    )

    fig.update_layout(
        title='Stacked Violin Plots',
        height=max(600, len(available_genes) * 180),
        showlegend=False,
        paper_bgcolor='#faf8f5',
        plot_bgcolor='white'
    )

    fig.update_xaxes(tickangle=-45)
    fig.update_yaxes(matches=None)

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_heatmap(adata, genes, groupby='cell_type'):
    """
    Create heatmap of gene expression across groups
    """
    available_genes = [g for g in genes if g in adata.var_names]

    if len(available_genes) == 0:
        return html.Div(f"None of the selected genes found in dataset", className="error-message")

    # Calculate mean expression per group
    groupby = _resolve_groupby(adata, groupby)
    if groupby is None:
        return html.Div("No grouping column available for heatmap", className="error-message")

    groups = adata.obs[groupby].unique()
    expr_matrix = []

    for group in groups:
        subset = adata[adata.obs[groupby] == group]
        group_expr = []
        for gene in available_genes:
            expr = _flatten_expr(subset[:, gene].X)
            group_expr.append(np.mean(expr))
        expr_matrix.append(group_expr)

    expr_matrix = np.array(expr_matrix)

    gene_order = list(range(len(available_genes)))
    group_order = list(range(len(groups)))

    if linkage and leaves_list:
        try:
            gene_order = leaves_list(linkage(expr_matrix.T, method='average', metric='correlation')).tolist()
            group_order = leaves_list(linkage(expr_matrix, method='average', metric='correlation')).tolist()
        except Exception:
            gene_order = list(range(len(available_genes)))
            group_order = list(range(len(groups)))

    ordered_genes = [available_genes[i] for i in gene_order]
    ordered_groups = [groups[i] for i in group_order]
    expr_matrix = expr_matrix[group_order, :][:, gene_order]

    # Create heatmap
    fig = go.Figure(data=go.Heatmap(
        z=expr_matrix.T,
        x=[str(g) for g in ordered_groups],
        y=ordered_genes,
        colorscale='RdBu_r',
        zmid=np.median(expr_matrix),
        hovertemplate='Gene: %{y}<br>Group: %{x}<br>Expression: %{z:.2f}<extra></extra>'
    ))

    fig.update_layout(
        title='Heatmap: Average Gene Expression (Clustered)',
        xaxis_title='Group',
        yaxis_title='Gene',
        height=max(400, len(available_genes) * 25),
        paper_bgcolor='#faf8f5',
        xaxis=dict(tickangle=-45)
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_feature_plot(adata, gene, point_size=3, opacity=0.8):
    """
    Create feature plot showing gene expression on UMAP
    """
    if gene not in adata.var_names:
        return html.Div(f"Gene {gene} not found in dataset", className="error-message")

    if 'X_umap' not in adata.obsm:
        return html.Div("UMAP coordinates not available", className="error-message")

    # Get expression values
    expr = _flatten_expr(adata[:, gene].X)

    # Create scatter plot
    fig = go.Figure(data=go.Scatter(
        x=adata.obsm['X_umap'][:, 0],
        y=adata.obsm['X_umap'][:, 1],
        mode='markers',
        marker=dict(
            size=point_size,
            color=expr,
            colorscale='Viridis',
            opacity=opacity,
            colorbar=dict(title=f"{gene}<br>Expression"),
            line=dict(width=0)
        ),
        text=[f'Expression: {e:.2f}' for e in expr],
        hovertemplate='<b>%{text}</b><br>UMAP1: %{x:.2f}<br>UMAP2: %{y:.2f}<extra></extra>'
    ))

    fig.update_layout(
        title=f'Feature Plot: {gene} Expression',
        xaxis_title='UMAP 1',
        yaxis_title='UMAP 2',
        height=600,
        paper_bgcolor='#faf8f5',
        plot_bgcolor='white',
        xaxis=dict(showgrid=False),
        yaxis=dict(showgrid=False)
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_gene_expression_plot(adata, genes, groupby='cell_type'):
    """
    Create bar plot of mean gene expression across groups
    """
    available_genes = [g for g in genes if g in adata.var_names]

    if len(available_genes) == 0:
        return html.Div(f"None of the selected genes found in dataset", className="error-message")

    fig = go.Figure()

    groupby = _resolve_groupby(adata, groupby)
    if groupby is None:
        return html.Div("No grouping column available for gene expression plot", className="error-message")

    groups = adata.obs[groupby].unique()

    for gene in available_genes:
        mean_expr = []
        for group in groups:
            subset = adata[adata.obs[groupby] == group]
            expr = _flatten_expr(subset[:, gene].X)
            mean_expr.append(np.mean(expr))

        fig.add_trace(go.Bar(
            x=[str(g) for g in groups],
            y=mean_expr,
            name=gene,
            hovertemplate='<b>%{fullData.name}</b><br>Group: %{x}<br>Mean Expression: %{y:.2f}<extra></extra>'
        ))

    fig.update_layout(
        title='Gene Expression by Group',
        xaxis_title='Group',
        yaxis_title='Mean Expression',
        height=500,
        barmode='group',
        paper_bgcolor='#faf8f5',
        plot_bgcolor='white',
        xaxis=dict(tickangle=-45)
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_sankey_plot(adata, source_key, target_key):
    """
    Create Sankey diagram for cell type proportions between two groupings.
    """
    source_key = _resolve_groupby(adata, source_key)
    if source_key is None:
        return html.Div("No grouping column available for Sankey plot", className="error-message")

    if target_key is None or target_key not in adata.obs.columns:
        fallback = 'cell_type' if 'cell_type' in adata.obs.columns else None
        if fallback is None or fallback == source_key:
            fallback = 'dataset' if 'dataset' in adata.obs.columns else None
        target_key = fallback

    if target_key is None or target_key not in adata.obs.columns:
        return html.Div("Select a valid secondary group for Sankey plot", className="info-message")

    df = adata.obs[[source_key, target_key]].copy()
    df[source_key] = df[source_key].astype(str)
    df[target_key] = df[target_key].astype(str)

    counts = df.groupby([source_key, target_key]).size().reset_index(name='value')
    if counts.empty:
        return html.Div("No data available for Sankey plot", className="error-message")

    sources = counts[source_key].unique().tolist()
    targets = counts[target_key].unique().tolist()
    labels = sources + targets
    source_indices = {label: idx for idx, label in enumerate(labels)}

    sankey_links = dict(
        source=[source_indices[s] for s in counts[source_key]],
        target=[source_indices[t] for t in counts[target_key]],
        value=counts['value']
    )

    fig = go.Figure(data=[go.Sankey(
        node=dict(
            pad=15,
            thickness=20,
            line=dict(color='rgba(0,0,0,0.2)', width=0.5),
            label=labels,
            color='rgba(232,146,124,0.7)'
        ),
        link=dict(
            source=sankey_links['source'],
            target=sankey_links['target'],
            value=sankey_links['value']
        )
    )])

    fig.update_layout(
        title=f'Sankey: {source_key} → {target_key}',
        height=650,
        paper_bgcolor='#faf8f5',
        plot_bgcolor='white'
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


def create_correlation_plot(adata, genes, color_by='cell_type'):
    """
    Create interactive correlation plot between two genes.
    """
    gene_x, gene_y = genes[0], genes[1]
    if gene_x not in adata.var_names or gene_y not in adata.var_names:
        return html.Div("Selected genes not found in dataset", className="error-message")

    x_expr = _flatten_expr(adata[:, gene_x].X)
    y_expr = _flatten_expr(adata[:, gene_y].X)

    idx = _sample_indices(len(x_expr), MAX_PLOT_CELLS)
    x_expr = x_expr[idx]
    y_expr = y_expr[idx]

    groupby = _resolve_groupby(adata, color_by)
    if groupby:
        groups = adata.obs[groupby].astype(str).values[idx]
    else:
        groups = ['All'] * len(x_expr)

    df = pd.DataFrame({
        'x': x_expr,
        'y': y_expr,
        'group': groups
    })

    corr = np.corrcoef(x_expr, y_expr)[0, 1] if len(x_expr) > 1 else np.nan

    fig = px.scatter(
        df,
        x='x',
        y='y',
        color='group',
        opacity=0.7,
        labels={'x': gene_x, 'y': gene_y}
    )

    fig.update_layout(
        title=f'Correlation: {gene_x} vs {gene_y} (r={corr:.3f})',
        height=600,
        paper_bgcolor='#faf8f5',
        plot_bgcolor='white'
    )

    return dcc.Graph(figure=fig, config={'displayModeBar': True, 'displaylogo': False})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Individual Dataset Visualization Suite for scSAID')
    parser.add_argument('--dataset', type=str, help='Path to H5AD dataset file')
    parser.add_argument('--dataset-id', type=str, help='Dataset ID (SAID)')
    parser.add_argument('--type', type=str, default="individual", help='Visualization type (integrated/individual)')
    parser.add_argument('--port', type=int, default=8050, help='Port to run the server')
    parser.add_argument('--debug', action='store_true', help='Run in debug mode')

    args = parser.parse_args()

    if args.dataset:
        dataset_type = args.type  # Use the provided type
        if load_dataset(args.dataset, dataset_type=dataset_type):
            print(f"Starting visualization server on port {args.port}...")
            app.run_server(debug=args.debug, host='0.0.0.0', port=args.port)
        else:
            print("Failed to load dataset. Exiting.")
            sys.exit(1)
    else:
        print("No dataset specified. Starting server without data...")
        app.run_server(debug=args.debug, host='0.0.0.0', port=args.port)