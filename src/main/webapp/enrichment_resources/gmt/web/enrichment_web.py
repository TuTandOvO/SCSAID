"""
Enrichment Analysis Visualization - scSAID Web Integration
Matches warm scientific aesthetic of the main site
"""

import os
import json
import numpy as np
import pandas as pd

from flask import Flask
from dash import Dash, html, dcc, dash_table
from dash.dependencies import Input, Output
import plotly.graph_objects as go

# ============ Configuration ============
# Use relative paths from web directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MARKER_GENES_PATH = os.path.join(BASE_DIR, "marker_genes_fine_map.json")
ENRICHMENT_PATH = os.path.join(BASE_DIR, "enrichment_results.json")

# ============ Load Data ============
print("=" * 50)
print("Loading enrichment data...")

with open(MARKER_GENES_PATH, 'r') as f:
    MARKER_DATA = json.load(f)
print(f"  Marker genes: {len(MARKER_DATA)} cell types")

with open(ENRICHMENT_PATH, 'r') as f:
    ENRICHMENT_DATA = json.load(f)
print(f"  Enrichment results: {len(ENRICHMENT_DATA)} cell types")

# Get available databases
CELLTYPES = sorted(ENRICHMENT_DATA.keys())
sample_ct = CELLTYPES[0]
AVAILABLE_LIBS = list(ENRICHMENT_DATA[sample_ct].keys())
print(f"  Available libraries: {AVAILABLE_LIBS}")

total_results = sum(
    len(ENRICHMENT_DATA[ct].get(lib, []))
    for ct in ENRICHMENT_DATA
    for lib in AVAILABLE_LIBS
)
print(f"  Total enrichment terms: {total_results:,}")
print("=" * 50)


def get_sig_color(p):
    """Return color based on p-value - warm scientific palette"""
    if p < 0.001:
        return '#e8927c'  # Coral - highly significant
    if p < 0.01:
        return '#d4a574'  # Bronze - significant
    if p < 0.05:
        return '#c4b8a6'  # Taupe - marginally significant
    return '#d1c9bd'  # Light gray - not significant


# ============ Dash Application ============
server = Flask(__name__)
app = Dash(__name__, server=server, url_base_pathname="/enrichment/")

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
                html.Div(
                    style={"display": "flex", "justifyContent": "space-between", "alignItems": "center"},
                    children=[
                        html.Div([
                            html.H1(
                                "Cell Type Enrichment Analysis",
                                style={
                                    "margin": "0",
                                    "fontSize": "22px",
                                    "fontFamily": "'Cormorant Garamond', Georgia, serif",
                                    "color": "#ffffff",
                                    "fontWeight": "500",
                                },
                            ),
                            html.P(
                                "Gene set enrichment using MSigDB v2026.1.Mm",
                                style={"margin": "4px 0 0 0", "fontSize": "13px", "color": "rgba(255,255,255,0.7)"},
                            ),
                        ]),
                        html.Div(
                            id="header-stats",
                            style={
                                "padding": "6px 14px",
                                "backgroundColor": "rgba(232, 146, 124, 0.15)",
                                "border": "1px solid rgba(232, 146, 124, 0.3)",
                                "borderRadius": "6px",
                                "fontSize": "13px",
                                "color": "#e8927c",
                                "fontWeight": "500",
                            },
                            children=f"{len(CELLTYPES)} cell types • {len(AVAILABLE_LIBS)} databases",
                        ),
                    ],
                ),
            ],
        ),

        # Main content
        html.Div(
            style={"padding": "0 28px 28px 28px"},
            children=[
                # Control Panel
                html.Div(
                    style={
                        "backgroundColor": "#ffffff",
                        "border": "1px solid #e5e0d8",
                        "borderRadius": "12px",
                        "padding": "18px 22px",
                        "marginBottom": "20px",
                        "display": "flex",
                        "gap": "20px",
                        "alignItems": "flex-end",
                        "flexWrap": "wrap",
                        "boxShadow": "0 2px 8px rgba(26, 35, 50, 0.04)",
                    },
                    children=[
                        html.Div([
                            html.Label(
                                "Cell Type",
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
                                id="celltype-select",
                                options=[{"label": ct, "value": ct} for ct in CELLTYPES],
                                value=CELLTYPES[0],
                                clearable=False,
                                style={"width": "380px"},
                            ),
                        ]),
                        html.Div([
                            html.Label(
                                "Database",
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
                                id="library-select",
                                options=[{"label": lib, "value": lib} for lib in AVAILABLE_LIBS],
                                value=AVAILABLE_LIBS[0],
                                clearable=False,
                                style={"width": "220px"},
                            ),
                        ]),
                        html.Div(
                            id="result-stats",
                            style={
                                "marginLeft": "auto",
                                "padding": "8px 16px",
                                "backgroundColor": "rgba(232, 146, 124, 0.08)",
                                "border": "1px solid rgba(232, 146, 124, 0.2)",
                                "borderRadius": "6px",
                                "fontSize": "13px",
                                "color": "#e8927c",
                                "fontWeight": "600",
                            },
                        ),
                    ],
                ),

                # Marker genes card
                html.Div(
                    id="marker-card",
                    style={
                        "backgroundColor": "#ffffff",
                        "border": "1px solid #e5e0d8",
                        "borderRadius": "12px",
                        "padding": "20px 22px",
                        "marginBottom": "20px",
                        "boxShadow": "0 2px 8px rgba(26, 35, 50, 0.04)",
                    },
                ),

                # Results area
                html.Div(
                    style={"display": "flex", "gap": "20px", "flexWrap": "wrap"},
                    children=[
                        # Table
                        html.Div(
                            style={
                                "flex": "1 1 600px",
                                "backgroundColor": "#ffffff",
                                "border": "1px solid #e5e0d8",
                                "borderRadius": "12px",
                                "padding": "20px 22px",
                                "boxShadow": "0 2px 8px rgba(26, 35, 50, 0.04)",
                            },
                            children=[
                                html.H3(
                                    "Enrichment Results",
                                    style={
                                        "margin": "0 0 16px 0",
                                        "fontSize": "15px",
                                        "color": "#1a2332",
                                        "fontFamily": "'Cormorant Garamond', Georgia, serif",
                                        "fontWeight": "600",
                                    }
                                ),
                                html.Div(id="result-table"),
                            ],
                        ),
                        # Bar chart
                        html.Div(
                            style={
                                "flex": "1 1 450px",
                                "backgroundColor": "#ffffff",
                                "border": "1px solid #e5e0d8",
                                "borderRadius": "12px",
                                "padding": "20px 22px",
                                "boxShadow": "0 2px 8px rgba(26, 35, 50, 0.04)",
                            },
                            children=[
                                html.H3(
                                    "Top Enriched Terms",
                                    style={
                                        "margin": "0 0 16px 0",
                                        "fontSize": "15px",
                                        "color": "#1a2332",
                                        "fontFamily": "'Cormorant Garamond', Georgia, serif",
                                        "fontWeight": "600",
                                    }
                                ),
                                dcc.Graph(id="bar-chart", config={"displayModeBar": False}),
                            ],
                        ),
                    ],
                ),

                # Legend
                html.Div(
                    style={
                        "backgroundColor": "#ffffff",
                        "border": "1px solid #e5e0d8",
                        "borderRadius": "12px",
                        "padding": "14px 20px",
                        "marginTop": "20px",
                        "display": "flex",
                        "gap": "20px",
                        "alignItems": "center",
                        "flexWrap": "wrap",
                        "boxShadow": "0 2px 8px rgba(26, 35, 50, 0.04)",
                    },
                    children=[
                        html.Span(
                            "Significance:",
                            style={"fontWeight": "600", "color": "#5a6473", "fontSize": "12px"}
                        ),
                        html.Span(
                            [html.Span("●", style={"color": "#e8927c", "marginRight": "5px"}), "p < 0.001"],
                            style={"color": "#1a2332", "fontSize": "12px"}
                        ),
                        html.Span(
                            [html.Span("●", style={"color": "#d4a574", "marginRight": "5px"}), "p < 0.01"],
                            style={"color": "#1a2332", "fontSize": "12px"}
                        ),
                        html.Span(
                            [html.Span("●", style={"color": "#c4b8a6", "marginRight": "5px"}), "p < 0.05"],
                            style={"color": "#1a2332", "fontSize": "12px"}
                        ),
                        html.Span(
                            [html.Span("●", style={"color": "#d1c9bd", "marginRight": "5px"}), "p ≥ 0.05"],
                            style={"color": "#1a2332", "fontSize": "12px"}
                        ),
                    ],
                ),
            ],
        ),
    ],
)


@app.callback(
    Output("marker-card", "children"),
    Output("result-table", "children"),
    Output("bar-chart", "figure"),
    Output("result-stats", "children"),
    Input("celltype-select", "value"),
    Input("library-select", "value"),
)
def update_content(celltype, library):
    # ========== Marker Genes ==========
    marker_info = MARKER_DATA.get(celltype, {})
    genes = marker_info.get('genes', [])
    n_genes = marker_info.get('n_genes', len(genes))
    logfcs = marker_info.get('logfoldchanges', [])
    avg_lfc = np.mean(logfcs) if logfcs else 0

    marker_card = [
        html.H3(
            f"Marker Genes: {celltype}",
            style={
                "margin": "0 0 16px 0",
                "fontSize": "15px",
                "color": "#1a2332",
                "fontFamily": "'Cormorant Garamond', Georgia, serif",
                "fontWeight": "600",
            }
        ),
        html.Div(
            style={"display": "flex", "gap": "28px", "marginBottom": "16px"},
            children=[
                html.Div([
                    html.Span(
                        f"{n_genes}",
                        style={"fontSize": "28px", "fontWeight": "700", "color": "#e8927c"}
                    ),
                    html.Span(
                        " genes",
                        style={"color": "#8b95a5", "marginLeft": "6px", "fontSize": "14px"}
                    ),
                ]),
                html.Div([
                    html.Span(
                        f"{avg_lfc:.2f}",
                        style={"fontSize": "28px", "fontWeight": "700", "color": "#d4a574"}
                    ),
                    html.Span(
                        " avg logFC",
                        style={"color": "#8b95a5", "marginLeft": "6px", "fontSize": "14px"}
                    ),
                ]),
            ],
        ),
        html.Div(
            style={
                "display": "flex",
                "flexWrap": "wrap",
                "gap": "5px",
                "maxHeight": "90px",
                "overflowY": "auto",
                "padding": "8px",
                "backgroundColor": "#faf8f5",
                "borderRadius": "6px",
            },
            children=[
                html.Span(
                    g,
                    style={
                        "padding": "3px 9px",
                        "backgroundColor": "rgba(232, 146, 124, 0.1)",
                        "border": "1px solid rgba(232, 146, 124, 0.2)",
                        "color": "#e8927c",
                        "borderRadius": "4px",
                        "fontSize": "11px",
                        "fontFamily": "'JetBrains Mono', monospace",
                        "fontWeight": "500",
                    }
                ) for g in genes[:50]
            ] + ([
                html.Span(
                    f"+{len(genes)-50} more",
                    style={"color": "#8b95a5", "fontSize": "11px", "padding": "3px", "fontStyle": "italic"}
                )
            ] if len(genes) > 50 else []),
        ),
    ]

    # ========== Enrichment Results ==========
    results = ENRICHMENT_DATA.get(celltype, {}).get(library, [])

    if not results:
        empty_fig = go.Figure()
        empty_fig.update_layout(
            paper_bgcolor='#faf8f5',
            plot_bgcolor='#faf8f5',
            font_color='#8b95a5',
            annotations=[dict(text="No results", showarrow=False, font_size=14)],
            height=450,
        )
        return (
            marker_card,
            html.Div(
                "No enrichment results for this combination",
                style={"color": "#8b95a5", "padding": "20px", "textAlign": "center"}
            ),
            empty_fig,
            "0 significant"
        )

    # Table data
    table_data = []
    for r in results[:50]:
        term = r['term'].replace('_', ' ')
        table_data.append({
            'Term': term[:65] + ('...' if len(term) > 65 else ''),
            'P-value': f"{r['pvalue']:.2e}",
            'FDR': f"{r['adjPvalue']:.2e}",
            'Score': f"{r['combinedScore']:.1f}",
            'Overlap': r['overlap'],
            'Genes': ', '.join(r['genes'][:4]) + ('...' if len(r['genes']) > 4 else ''),
        })

    table = dash_table.DataTable(
        data=table_data,
        columns=[
            {'name': 'Term', 'id': 'Term'},
            {'name': 'P-value', 'id': 'P-value'},
            {'name': 'FDR', 'id': 'FDR'},
            {'name': 'Score', 'id': 'Score'},
            {'name': 'Overlap', 'id': 'Overlap'},
            {'name': 'Genes', 'id': 'Genes'},
        ],
        style_table={'overflowX': 'auto'},
        style_cell={
            'textAlign': 'left',
            'padding': '10px 12px',
            'fontSize': '12px',
            'backgroundColor': '#ffffff',
            'color': '#1a2332',
            'border': '1px solid #e5e0d8',
            'fontFamily': "'Source Sans 3', sans-serif",
        },
        style_header={
            'backgroundColor': '#f5f2ed',
            'fontWeight': '600',
            'color': '#5a6473',
            'fontSize': '11px',
            'textTransform': 'uppercase',
            'letterSpacing': '0.05em',
            'border': '1px solid #e5e0d8',
        },
        style_data_conditional=[
            {'if': {'row_index': 'odd'}, 'backgroundColor': '#faf8f5'},
        ],
        page_size=12,
        style_as_list_view=False,
    )

    # Bar chart
    top_results = sorted(results, key=lambda x: -x['combinedScore'])[:15]

    bar_fig = go.Figure()
    bar_fig.add_trace(go.Bar(
        y=[r['term'].replace('_', ' ')[:32] + ('...' if len(r['term']) > 32 else '') for r in top_results][::-1],
        x=[r['combinedScore'] for r in top_results][::-1],
        orientation='h',
        marker_color=[get_sig_color(r['adjPvalue']) for r in top_results][::-1],
        text=[f"{r['combinedScore']:.1f}" for r in top_results][::-1],
        textposition='outside',
        textfont=dict(color='#5a6473', size=10, family="'Source Sans 3', sans-serif"),
    ))
    bar_fig.update_layout(
        paper_bgcolor='#ffffff',
        plot_bgcolor='#ffffff',
        font=dict(color='#1a2332', family="'Source Sans 3', sans-serif"),
        margin=dict(l=10, r=60, t=10, b=40),
        xaxis=dict(
            title="Combined Score",
            showgrid=True,
            gridcolor='#e5e0d8',
            zeroline=False,
            tickfont=dict(size=11),
        ),
        yaxis=dict(
            tickfont=dict(size=10),
            showgrid=False,
        ),
        height=450,
        bargap=0.25,
    )

    sig_count = sum(1 for r in results if r['adjPvalue'] < 0.05)
    stats_text = f"{sig_count} significant (FDR<0.05) / {len(results)} total"

    return marker_card, table, bar_fig, stats_text


if __name__ == "__main__":
    print(f"\nStarting Enrichment Analysis server...")
    print(f"URL: http://0.0.0.0:8051/enrichment/")
    print("=" * 50)

    server.run(debug=False, host="127.0.0.1", port=8051)
