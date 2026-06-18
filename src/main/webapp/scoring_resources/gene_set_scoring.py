"""
Gene Set Scoring Application for scSAID
Implements AUCell, GSVA, and Mean Expression scoring with smart recommendations
"""

import os
import json
import glob
import numpy as np
import pandas as pd
import scanpy as sc
from scipy import stats
from scipy.sparse import issparse
from sklearn.metrics.pairwise import cosine_similarity

from flask import Flask
from dash import Dash, html, dcc, dash_table, Input, Output, State, ALL
import plotly.graph_objects as go

# ============ Configuration ============
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
GENE_SETS_DIR = os.path.join(BASE_DIR, "mouse_gene_sets", "reactome_sets")
MAPPING_PATH = os.path.join(BASE_DIR, "..", "..", "WEB-INF", "mapping.json")

# ============ Load Gene Sets ============
print("=" * 60)
print("Loading Reactome Gene Sets...")

def load_gene_sets():
    """Load all GMT files from reactome_sets directory"""
    gene_sets = {}
    gmt_files = glob.glob(os.path.join(GENE_SETS_DIR, "*.gmt"))

    for gmt_file in gmt_files:
        with open(gmt_file, 'r') as f:
            line = f.readline().strip()
            parts = line.split('\t')
            if len(parts) >= 3:
                name = parts[0]
                url = parts[1]
                genes = parts[2:]
                gene_sets[name] = {
                    'genes': genes,
                    'url': url,
                    'size': len(genes),
                    'description': name.replace('REACTOME_', '').replace('_', ' ').title()
                }

    return gene_sets

GENE_SETS = load_gene_sets()
print(f"  Loaded {len(GENE_SETS)} gene sets")
print("=" * 60)


# ============ Scoring Functions ============

def score_aucell(adata, gene_set, cell_type_col='cell_type'):
    """
    AUCell scoring: Ranks genes by expression and calculates AUC
    """
    if issparse(adata.X):
        expr_matrix = adata.X.toarray()
    else:
        expr_matrix = adata.X

    # Get gene indices
    gene_indices = [i for i, g in enumerate(adata.var_names) if g in gene_set]

    if len(gene_indices) == 0:
        return pd.DataFrame()

    # Rank genes per cell
    ranks = np.argsort(np.argsort(-expr_matrix, axis=1), axis=1)

    # Calculate AUC for gene set
    n_genes = expr_matrix.shape[1]
    auc_scores = []

    for cell_idx in range(expr_matrix.shape[0]):
        cell_ranks = ranks[cell_idx, gene_indices]
        # AUC = (sum of ranks) / (n_genes_in_set * n_total_genes)
        auc = 1 - (cell_ranks.sum() / (len(gene_indices) * n_genes))
        auc_scores.append(auc)

    # Create result dataframe
    result = pd.DataFrame({
        'cell': adata.obs_names,
        'score': auc_scores,
        'cell_type': adata.obs[cell_type_col] if cell_type_col in adata.obs else 'Unknown'
    })

    return result


def score_mean_expression(adata, gene_set, cell_type_col='cell_type'):
    """
    Mean Expression scoring: Average expression of genes in set
    """
    if issparse(adata.X):
        expr_matrix = adata.X.toarray()
    else:
        expr_matrix = adata.X

    # Get gene indices
    gene_indices = [i for i, g in enumerate(adata.var_names) if g in gene_set]

    if len(gene_indices) == 0:
        return pd.DataFrame()

    # Calculate mean expression
    mean_scores = expr_matrix[:, gene_indices].mean(axis=1)

    result = pd.DataFrame({
        'cell': adata.obs_names,
        'score': mean_scores,
        'cell_type': adata.obs[cell_type_col] if cell_type_col in adata.obs else 'Unknown'
    })

    return result


def score_gsva(adata, gene_set, cell_type_col='cell_type'):
    """
    GSVA-like scoring: Z-score normalized mean expression
    """
    if issparse(adata.X):
        expr_matrix = adata.X.toarray()
    else:
        expr_matrix = adata.X

    # Get gene indices
    gene_indices = [i for i, g in enumerate(adata.var_names) if g in gene_set]

    if len(gene_indices) == 0:
        return pd.DataFrame()

    # Z-score normalization per gene
    expr_subset = expr_matrix[:, gene_indices]
    mean_per_gene = expr_subset.mean(axis=0)
    std_per_gene = expr_subset.std(axis=0) + 1e-10
    z_scores = (expr_subset - mean_per_gene) / std_per_gene

    # Mean z-score per cell
    gsva_scores = z_scores.mean(axis=1)

    result = pd.DataFrame({
        'cell': adata.obs_names,
        'score': gsva_scores,
        'cell_type': adata.obs[cell_type_col] if cell_type_col in adata.obs else 'Unknown'
    })

    return result


# ============ Recommendation Algorithm ============

def recommend_gene_sets(adata, n_recommendations=5):
    """
    Smart recommendation algorithm based on:
    1. Expressed genes overlap
    2. Cell type diversity
    3. Gene set size (prefer medium-sized sets)
    """
    # Get expressed genes (> 0 in at least 10% cells)
    if issparse(adata.X):
        expr_matrix = adata.X.toarray()
    else:
        expr_matrix = adata.X

    expression_rate = (expr_matrix > 0).mean(axis=0)
    expressed_genes = set(adata.var_names[expression_rate > 0.1])

    recommendations = []

    for name, gs_info in GENE_SETS.items():
        genes = set(gs_info['genes'])
        overlap = len(genes & expressed_genes)
        overlap_rate = overlap / len(genes) if len(genes) > 0 else 0

        # Score based on multiple criteria
        # 1. Overlap rate (0.3-0.8 is ideal - not too sparse, not too common)
        overlap_score = 1 - abs(overlap_rate - 0.55) / 0.55

        # 2. Size score (prefer 10-100 genes)
        size = gs_info['size']
        if 10 <= size <= 100:
            size_score = 1.0
        elif size < 10:
            size_score = size / 10
        else:
            size_score = max(0, 1 - (size - 100) / 200)

        # 3. Expression variability (higher is better)
        gene_indices = [i for i, g in enumerate(adata.var_names) if g in genes]
        if len(gene_indices) > 0:
            var_scores = expr_matrix[:, gene_indices].var(axis=0)
            variability_score = np.mean(var_scores) / (np.mean(var_scores) + 1)
        else:
            variability_score = 0

        # Combined score
        total_score = (overlap_score * 0.4 + size_score * 0.3 + variability_score * 0.3)

        recommendations.append({
            'name': name,
            'description': gs_info['description'],
            'size': size,
            'overlap': overlap,
            'overlap_rate': overlap_rate,
            'score': total_score
        })

    # Sort by score and return top N
    recommendations.sort(key=lambda x: x['score'], reverse=True)
    return recommendations[:n_recommendations]


# ============ Dash Application ============
server = Flask(__name__)
app = Dash(__name__, server=server, url_base_pathname="/gene-scoring/")

# Store loaded datasets in memory
LOADED_DATASETS = {}

app.layout = html.Div(
    style={
        "width": "100%",
        "minHeight": "100vh",
        "backgroundColor": "#faf8f5",
        "fontFamily": "'Source Sans 3', sans-serif",
        "color": "#1a2332",
        "padding": "0",
        "margin": "0",
    },
    children=[
        # Header
        html.Div(
            style={
                "background": "linear-gradient(135deg, #1a2332 0%, #2a3442 100%)",
                "padding": "20px 28px",
                "borderBottom": "2px solid #e8927c",
                "marginBottom": "24px",
            },
            children=[
                html.H1(
                    "Gene Set Scoring Analysis",
                    style={
                        "margin": "0",
                        "fontSize": "22px",
                        "fontFamily": "'Cormorant Garamond', Georgia, serif",
                        "color": "#ffffff",
                        "fontWeight": "500",
                    },
                ),
                html.P(
                    "Score cell types using Reactome pathways with AUCell, GSVA, or Mean Expression",
                    style={"margin": "4px 0 0 0", "fontSize": "13px", "color": "rgba(255,255,255,0.7)"},
                ),
            ],
        ),

        # Hidden dataset storage
        dcc.Store(id='dataset-store'),
        dcc.Store(id='current-dataset-id'),

        # Main content
        html.Div(
            style={"padding": "0 28px 28px 28px"},
            children=[
                # Dataset Selector & Recommendations
                html.Div(
                    style={
                        "backgroundColor": "#ffffff",
                        "border": "1px solid #e5e0d8",
                        "borderRadius": "12px",
                        "padding": "20px 22px",
                        "marginBottom": "20px",
                        "boxShadow": "0 2px 8px rgba(26, 35, 50, 0.04)",
                    },
                    children=[
                        html.H3(
                            "Recommended Gene Sets",
                            style={
                                "margin": "0 0 12px 0",
                                "fontSize": "15px",
                                "fontFamily": "'Cormorant Garamond', Georgia, serif",
                                "fontWeight": "600",
                                "color": "#1a2332",
                            }
                        ),
                        html.P(
                            "Based on your dataset's expressed genes and cell type diversity:",
                            style={"fontSize": "13px", "color": "#8b95a5", "margin": "0 0 16px 0"}
                        ),
                        html.Div(id="recommendations-container"),
                    ],
                ),

                # Search & Selection
                html.Div(
                    style={
                        "backgroundColor": "#ffffff",
                        "border": "1px solid #e5e0d8",
                        "borderRadius": "12px",
                        "padding": "20px 22px",
                        "marginBottom": "20px",
                        "boxShadow": "0 2px 8px rgba(26, 35, 50, 0.04)",
                    },
                    children=[
                        html.Div(
                            style={"display": "flex", "gap": "16px", "alignItems": "flex-end", "marginBottom": "16px"},
                            children=[
                                html.Div(
                                    style={"flex": "1"},
                                    children=[
                                        html.Label(
                                            "Search Gene Sets",
                                            style={
                                                "display": "block",
                                                "fontSize": "11px",
                                                "color": "#5a6473",
                                                "marginBottom": "6px",
                                                "fontWeight": "600",
                                                "textTransform": "uppercase",
                                                "letterSpacing": "0.05em",
                                            }
                                        ),
                                        dcc.Input(
                                            id="search-input",
                                            type="text",
                                            placeholder="Search pathways (e.g., immune, metabolism, signaling)...",
                                            style={
                                                "width": "100%",
                                                "padding": "10px 14px",
                                                "border": "2px solid #e5e0d8",
                                                "borderRadius": "8px",
                                                "fontSize": "14px",
                                                "fontFamily": "'Source Sans 3', sans-serif",
                                            },
                                            debounce=True,
                                        ),
                                    ]
                                ),
                                html.Div(
                                    style={"flex": "0 0 180px"},
                                    children=[
                                        html.Label(
                                            "Scoring Method",
                                            style={
                                                "display": "block",
                                                "fontSize": "11px",
                                                "color": "#5a6473",
                                                "marginBottom": "6px",
                                                "fontWeight": "600",
                                                "textTransform": "uppercase",
                                                "letterSpacing": "0.05em",
                                            }
                                        ),
                                        dcc.Dropdown(
                                            id="method-select",
                                            options=[
                                                {"label": "AUCell", "value": "aucell"},
                                                {"label": "GSVA", "value": "gsva"},
                                                {"label": "Mean Expression", "value": "mean"},
                                            ],
                                            value="aucell",
                                            clearable=False,
                                        ),
                                    ]
                                ),
                            ],
                        ),
                        html.Div(id="search-results"),
                    ],
                ),

                # Violin Plot Display
                html.Div(
                    id="plot-container",
                    style={
                        "backgroundColor": "#ffffff",
                        "border": "1px solid #e5e0d8",
                        "borderRadius": "12px",
                        "padding": "20px 22px",
                        "boxShadow": "0 2px 8px rgba(26, 35, 50, 0.04)",
                        "minHeight": "500px",
                    },
                ),
            ],
        ),
    ],
)


@app.callback(
    Output("recommendations-container", "children"),
    Input("current-dataset-id", "data"),
)
def update_recommendations(dataset_id):
    if not dataset_id or dataset_id not in LOADED_DATASETS:
        return html.P("No dataset loaded", style={"color": "#8b95a5", "fontSize": "13px"})

    adata = LOADED_DATASETS[dataset_id]
    recommendations = recommend_gene_sets(adata, n_recommendations=5)

    recommendation_cards = []
    for i, rec in enumerate(recommendations):
        card = html.Div(
            style={
                "backgroundColor": "#faf8f5",
                "border": "1px solid #e5e0d8",
                "borderRadius": "8px",
                "padding": "14px 16px",
                "cursor": "pointer",
                "transition": "all 0.2s ease",
                "marginBottom": "10px" if i < 4 else "0",
            },
            className="recommendation-card",
            children=[
                html.Div(
                    style={"display": "flex", "justifyContent": "space-between", "alignItems": "flex-start"},
                    children=[
                        html.Div(
                            style={"flex": "1"},
                            children=[
                                html.Div(
                                    f"#{i+1}  {rec['description']}",
                                    style={
                                        "fontSize": "14px",
                                        "fontWeight": "600",
                                        "color": "#1a2332",
                                        "marginBottom": "4px",
                                    }
                                ),
                                html.Div(
                                    f"{rec['size']} genes • {rec['overlap']} expressed ({rec['overlap_rate']*100:.0f}%)",
                                    style={"fontSize": "12px", "color": "#8b95a5"},
                                ),
                            ]
                        ),
                        html.Div(
                            f"{rec['score']:.2f}",
                            style={
                                "fontSize": "16px",
                                "fontWeight": "700",
                                "color": "#e8927c",
                                "fontFamily": "'JetBrains Mono', monospace",
                            }
                        ),
                    ]
                ),
            ],
            id={"type": "rec-card", "index": rec['name']},
        )
        recommendation_cards.append(card)

    return recommendation_cards


@app.callback(
    Output("search-results", "children"),
    Input("search-input", "value"),
)
def update_search_results(search_term):
    if not search_term or len(search_term) < 3:
        return html.P(
            "Enter at least 3 characters to search...",
            style={"color": "#8b95a5", "fontSize": "13px", "fontStyle": "italic", "margin": "10px 0"}
        )

    # Search gene sets
    search_lower = search_term.lower()
    matches = []

    for name, info in GENE_SETS.items():
        if search_lower in name.lower() or search_lower in info['description'].lower():
            matches.append({
                'name': name,
                'description': info['description'],
                'size': info['size']
            })

    if len(matches) == 0:
        return html.P(
            f"No gene sets found matching '{search_term}'",
            style={"color": "#8b95a5", "fontSize": "13px", "margin": "10px 0"}
        )

    # Limit to top 10 results
    matches = matches[:10]

    result_items = []
    for match in matches:
        item = html.Div(
            style={
                "padding": "10px 14px",
                "border": "1px solid #e5e0d8",
                "borderRadius": "6px",
                "marginBottom": "8px",
                "cursor": "pointer",
                "transition": "all 0.2s ease",
                "backgroundColor": "#ffffff",
            },
            className="search-result-item",
            children=[
                html.Div(
                    match['description'],
                    style={"fontSize": "14px", "fontWeight": "500", "color": "#1a2332", "marginBottom": "4px"}
                ),
                html.Div(
                    f"{match['size']} genes",
                    style={"fontSize": "12px", "color": "#8b95a5"}
                ),
            ],
            id={"type": "search-result", "index": match['name']},
        )
        result_items.append(item)

    return [
        html.P(
            f"Found {len(matches)} matching gene sets:",
            style={"fontSize": "13px", "color": "#5a6473", "fontWeight": "600", "margin": "0 0 12px 0"}
        ),
        html.Div(
            style={"maxHeight": "400px", "overflowY": "auto"},
            children=result_items
        ),
    ]


@app.callback(
    Output("plot-container", "children"),
    Input({"type": "rec-card", "index": ALL}, "n_clicks"),
    Input({"type": "search-result", "index": ALL}, "n_clicks"),
    State("current-dataset-id", "data"),
    State("method-select", "value"),
    prevent_initial_call=True,
)
def generate_plot(rec_clicks, search_clicks, dataset_id, method):
    # Implementation continues in next part...
    pass


def load_dataset(dataset_id):
    """Load h5ad file for given dataset ID"""
    # Load mapping.json to get file path
    with open(MAPPING_PATH, 'r') as f:
        mapping = json.load(f)

    if dataset_id not in mapping:
        return None

    file_path = mapping[dataset_id]['file_path']

    if not os.path.exists(file_path):
        return None

    # Load h5ad file
    adata = sc.read_h5ad(file_path)

    # Store in memory
    LOADED_DATASETS[dataset_id] = adata

    return adata


if __name__ == "__main__":
    print(f"\nStarting Gene Set Scoring server...")
    print(f"URL: http://0.0.0.0:8052/gene-scoring/")
    print("=" * 60)

    server.run(debug=False, host="0.0.0.0", port=8052)
