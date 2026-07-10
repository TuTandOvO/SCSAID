"""
富集分析可视化 - 独立 Dash 应用
基于预计算的 marker genes 和富集结果
"""

import os
import json
import numpy as np
import pandas as pd

from flask import Flask
from dash import Dash, html, dcc, dash_table
from dash.dependencies import Input, Output
import plotly.graph_objects as go

# ============ 配置 ============
MARKER_GENES_PATH = "/root/SkinDB/mouse/marker_genes_fine_map.json"
ENRICHMENT_PATH = "/root/SkinDB/mouse/enrichment_results.json"

# ============ 加载数据 ============
print("=" * 50)
print("Loading enrichment data...")

with open(MARKER_GENES_PATH, 'r') as f:
    MARKER_DATA = json.load(f)
print(f"  Marker genes: {len(MARKER_DATA)} cell types")

with open(ENRICHMENT_PATH, 'r') as f:
    ENRICHMENT_DATA = json.load(f)
print(f"  Enrichment results: {len(ENRICHMENT_DATA)} cell types")

# 获取可用的数据库
CELLTYPES = sorted(ENRICHMENT_DATA.keys())
sample_ct = CELLTYPES[0]
AVAILABLE_LIBS = list(ENRICHMENT_DATA[sample_ct].keys())
print(f"  Available libraries: {AVAILABLE_LIBS}")

# 统计总结果数
total_results = sum(
    len(ENRICHMENT_DATA[ct].get(lib, []))
    for ct in ENRICHMENT_DATA
    for lib in AVAILABLE_LIBS
)
print(f"  Total enrichment terms: {total_results:,}")
print("=" * 50)


def get_sig_color(p):
    """根据 p 值返回颜色"""
    if p < 0.001:
        return '#22c55e'  # green
    if p < 0.01:
        return '#84cc16'  # lime
    if p < 0.05:
        return '#facc15'  # yellow
    return '#9ca3af'  # gray


# ============ Dash 应用 ============
server = Flask(__name__)
app = Dash(__name__, server=server, url_base_pathname="/enrichment/")

app.layout = html.Div(
    style={
        "width": "100%",
        "minHeight": "100vh",
        "backgroundColor": "#0f172a",
        "fontFamily": "'Segoe UI', Arial, sans-serif",
        "color": "#e2e8f0",
    },
    children=[
        # Header
        html.Div(
            style={
                "background": "linear-gradient(135deg, #1e1b4b 0%, #0f172a 100%)",
                "padding": "24px 32px",
                "borderBottom": "1px solid rgba(148, 163, 184, 0.1)",
            },
            children=[
                html.Div(
                    style={"display": "flex", "justifyContent": "space-between", "alignItems": "center", "maxWidth": "1400px", "margin": "0 auto"},
                    children=[
                        html.Div([
                            html.H1(
                                "🧬 Cell Type Enrichment Analysis",
                                style={
                                    "margin": "0",
                                    "fontSize": "28px",
                                    "background": "linear-gradient(135deg, #06b6d4, #8b5cf6)",
                                    "WebkitBackgroundClip": "text",
                                    "WebkitTextFillColor": "transparent",
                                },
                            ),
                            html.P(
                                "Mouse Skin Atlas • Fine_Map Markers",
                                style={"margin": "4px 0 0 0", "fontSize": "14px", "color": "#94a3b8"},
                            ),
                        ]),
                        html.Div(
                            id="header-stats",
                            style={
                                "padding": "8px 16px",
                                "backgroundColor": "rgba(6, 182, 212, 0.1)",
                                "border": "1px solid rgba(6, 182, 212, 0.3)",
                                "borderRadius": "8px",
                                "fontSize": "14px",
                            },
                            children=f"📊 {len(CELLTYPES)} cell types | 📚 {len(AVAILABLE_LIBS)} databases",
                        ),
                    ],
                ),
            ],
        ),

        # Main content
        html.Div(
            style={"maxWidth": "1400px", "margin": "0 auto", "padding": "24px"},
            children=[
                # 控制面板
                html.Div(
                    style={
                        "backgroundColor": "rgba(30, 41, 59, 0.6)",
                        "border": "1px solid rgba(148, 163, 184, 0.1)",
                        "borderRadius": "12px",
                        "padding": "20px",
                        "marginBottom": "20px",
                        "display": "flex",
                        "gap": "24px",
                        "alignItems": "flex-end",
                        "flexWrap": "wrap",
                    },
                    children=[
                        html.Div([
                            html.Label("Cell Type", style={"display": "block", "fontSize": "12px", "color": "#94a3b8", "marginBottom": "6px"}),
                            dcc.Dropdown(
                                id="celltype-select",
                                options=[{"label": ct, "value": ct} for ct in CELLTYPES],
                                value=CELLTYPES[0],
                                clearable=False,
                                style={"width": "350px"},
                            ),
                        ]),
                        html.Div([
                            html.Label("Database", style={"display": "block", "fontSize": "12px", "color": "#94a3b8", "marginBottom": "6px"}),
                            dcc.Dropdown(
                                id="library-select",
                                options=[{"label": lib, "value": lib} for lib in AVAILABLE_LIBS],
                                value=AVAILABLE_LIBS[0],
                                clearable=False,
                                style={"width": "200px"},
                            ),
                        ]),
                        html.Div(
                            id="result-stats",
                            style={
                                "marginLeft": "auto",
                                "padding": "10px 20px",
                                "backgroundColor": "rgba(34, 197, 94, 0.1)",
                                "border": "1px solid rgba(34, 197, 94, 0.3)",
                                "borderRadius": "8px",
                                "fontSize": "14px",
                                "color": "#22c55e",
                            },
                        ),
                    ],
                ),

                # Marker genes card
                html.Div(
                    id="marker-card",
                    style={
                        "backgroundColor": "rgba(30, 41, 59, 0.6)",
                        "border": "1px solid rgba(148, 163, 184, 0.1)",
                        "borderRadius": "12px",
                        "padding": "20px",
                        "marginBottom": "20px",
                    },
                ),

                # 结果区域
                html.Div(
                    style={"display": "flex", "gap": "20px", "flexWrap": "wrap"},
                    children=[
                        # 表格
                        html.Div(
                            style={
                                "flex": "1 1 600px",
                                "backgroundColor": "rgba(30, 41, 59, 0.6)",
                                "border": "1px solid rgba(148, 163, 184, 0.1)",
                                "borderRadius": "12px",
                                "padding": "20px",
                                "overflowX": "auto",
                            },
                            children=[
                                html.H3("Enrichment Results", style={"margin": "0 0 16px 0", "fontSize": "16px", "color": "#cbd5e1"}),
                                html.Div(id="result-table"),
                            ],
                        ),
                        # 条形图
                        html.Div(
                            style={
                                "flex": "1 1 400px",
                                "backgroundColor": "rgba(30, 41, 59, 0.6)",
                                "border": "1px solid rgba(148, 163, 184, 0.1)",
                                "borderRadius": "12px",
                                "padding": "20px",
                            },
                            children=[
                                html.H3("Top Enriched Terms", style={"margin": "0 0 16px 0", "fontSize": "16px", "color": "#cbd5e1"}),
                                dcc.Graph(id="bar-chart", config={"displayModeBar": False}),
                            ],
                        ),
                    ],
                ),

                # 图例
                html.Div(
                    style={
                        "backgroundColor": "rgba(30, 41, 59, 0.6)",
                        "border": "1px solid rgba(148, 163, 184, 0.1)",
                        "borderRadius": "12px",
                        "padding": "16px 20px",
                        "marginTop": "20px",
                        "display": "flex",
                        "gap": "24px",
                        "alignItems": "center",
                        "flexWrap": "wrap",
                    },
                    children=[
                        html.Span("Significance:", style={"fontWeight": "600", "color": "#64748b"}),
                        html.Span([html.Span("●", style={"color": "#22c55e", "marginRight": "6px"}), "p < 0.001"], style={"color": "#94a3b8"}),
                        html.Span([html.Span("●", style={"color": "#84cc16", "marginRight": "6px"}), "p < 0.01"], style={"color": "#94a3b8"}),
                        html.Span([html.Span("●", style={"color": "#facc15", "marginRight": "6px"}), "p < 0.05"], style={"color": "#94a3b8"}),
                        html.Span([html.Span("●", style={"color": "#9ca3af", "marginRight": "6px"}), "p ≥ 0.05"], style={"color": "#94a3b8"}),
                    ],
                ),
            ],
        ),

        # Footer
        html.Div(
            style={
                "textAlign": "center",
                "padding": "20px",
                "borderTop": "1px solid rgba(148, 163, 184, 0.1)",
                "marginTop": "40px",
                "color": "#64748b",
                "fontSize": "13px",
            },
            children=[
                html.P([
                    "Enrichment analysis using MSigDB v2026.1.Mm | ",
                    html.A("GSEA-MSigDB", href="https://www.gsea-msigdb.org/", target="_blank", style={"color": "#06b6d4"}),
                ]),
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
        html.H3(f"Marker Genes: {celltype}", style={"margin": "0 0 16px 0", "fontSize": "16px", "color": "#cbd5e1"}),
        html.Div(
            style={"display": "flex", "gap": "32px", "marginBottom": "16px"},
            children=[
                html.Div([
                    html.Span(f"{n_genes}", style={"fontSize": "32px", "fontWeight": "700", "color": "#06b6d4"}),
                    html.Span(" genes", style={"color": "#64748b", "marginLeft": "8px"}),
                ]),
                html.Div([
                    html.Span(f"{avg_lfc:.2f}", style={"fontSize": "32px", "fontWeight": "700", "color": "#06b6d4"}),
                    html.Span(" avg logFC", style={"color": "#64748b", "marginLeft": "8px"}),
                ]),
            ],
        ),
        html.Div(
            style={"display": "flex", "flexWrap": "wrap", "gap": "6px", "maxHeight": "100px", "overflowY": "auto"},
            children=[
                html.Span(g, style={
                    "padding": "3px 10px",
                    "backgroundColor": "rgba(139, 92, 246, 0.15)",
                    "border": "1px solid rgba(139, 92, 246, 0.3)",
                    "color": "#a78bfa",
                    "borderRadius": "4px",
                    "fontSize": "11px",
                    "fontFamily": "monospace",
                }) for g in genes[:50]
            ] + ([html.Span(f"+{len(genes)-50} more", style={"color": "#64748b", "fontSize": "11px", "padding": "3px"})] if len(genes) > 50 else []),
        ),
    ]

    # ========== Enrichment Results ==========
    results = ENRICHMENT_DATA.get(celltype, {}).get(library, [])

    if not results:
        empty_fig = go.Figure()
        empty_fig.update_layout(
            paper_bgcolor='rgba(0,0,0,0)',
            plot_bgcolor='rgba(0,0,0,0)',
            font_color='#94a3b8',
            annotations=[dict(text="No results", showarrow=False, font_size=16)],
        )
        return marker_card, html.Div("No enrichment results for this combination", style={"color": "#64748b", "padding": "20px"}), empty_fig, "0 significant"

    # 表格数据
    table_data = []
    for r in results[:50]:
        term = r['term'].replace('_', ' ')
        table_data.append({
            'Term': term[:70] + ('...' if len(term) > 70 else ''),
            'P-value': f"{r['pvalue']:.2e}",
            'FDR': f"{r['adjPvalue']:.2e}",
            'Score': f"{r['combinedScore']:.1f}",
            'Overlap': r['overlap'],
            'Genes': ', '.join(r['genes'][:5]) + ('...' if len(r['genes']) > 5 else ''),
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
            'backgroundColor': 'transparent',
            'color': '#e2e8f0',
            'border': '1px solid rgba(148, 163, 184, 0.1)',
        },
        style_header={
            'backgroundColor': 'rgba(15, 23, 42, 0.6)',
            'fontWeight': '600',
            'color': '#94a3b8',
        },
        style_data_conditional=[
            {'if': {'row_index': 'odd'}, 'backgroundColor': 'rgba(148, 163, 184, 0.05)'},
        ],
        page_size=15,
        style_as_list_view=True,
    )

    # 条形图
    top_results = sorted(results, key=lambda x: -x['combinedScore'])[:15]

    bar_fig = go.Figure()
    bar_fig.add_trace(go.Bar(
        y=[r['term'].replace('_', ' ')[:35] + ('...' if len(r['term']) > 35 else '') for r in top_results][::-1],
        x=[r['combinedScore'] for r in top_results][::-1],
        orientation='h',
        marker_color=[get_sig_color(r['adjPvalue']) for r in top_results][::-1],
        text=[f"{r['combinedScore']:.1f}" for r in top_results][::-1],
        textposition='outside',
        textfont=dict(color='#94a3b8', size=10),
    ))
    bar_fig.update_layout(
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        font_color='#94a3b8',
        margin=dict(l=10, r=60, t=10, b=40),
        xaxis=dict(
            title="Combined Score",
            showgrid=True,
            gridcolor='rgba(148, 163, 184, 0.1)',
            zeroline=False,
        ),
        yaxis=dict(
            tickfont=dict(size=11),
            showgrid=False,
        ),
        height=500,
        bargap=0.3,
    )

    sig_count = sum(1 for r in results if r['adjPvalue'] < 0.05)
    stats_text = f"✅ {sig_count} significant (FDR<0.05) / {len(results)} total"

    return marker_card, table, bar_fig, stats_text


if __name__ == "__main__":
    print(f"\nStarting Enrichment Analysis server...")
    print(f"URL: http://0.0.0.0:8051/enrichment/")
    print("=" * 50)
    
    server.run(debug=False, host="127.0.0.1", port=8051)
