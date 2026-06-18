"""
CellPhoneDB Dynamic Analysis Flask API for scSAID
Provides on-demand cell-cell communication analysis using CellPhoneDB
"""

import os
import sys
import json
import hashlib
import threading
import uuid
import time
from datetime import datetime, timedelta
from functools import lru_cache

import numpy as np
import pandas as pd
import scanpy as sc
from scipy.sparse import issparse
from flask import Flask, request, jsonify
import plotly.graph_objects as go
import plotly.express as px

# ============ Configuration ============
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MAPPING_PATH = os.path.join(BASE_DIR, "..", "WEB-INF", "classes", "mapping.json")
CACHE_DIR = os.path.join(BASE_DIR, "cache")
CPDB_DB_PATH = os.path.join(BASE_DIR, "cellphonedb.zip")

# Alternative mapping path locations
MAPPING_PATHS = [
    os.path.join(BASE_DIR, "..", "WEB-INF", "classes", "mapping.json"),
    os.path.join(BASE_DIR, "..", "..", "resources", "mapping.json"),
    "/opt/SkinDB_web/src/main/resources/mapping.json",
]

# Cell type column name in h5ad obs
CELL_TYPE_COL = "Gross_Map"

# Cache duration in seconds (24 hours)
CACHE_DURATION = 86400

# Ensure cache directory exists
os.makedirs(CACHE_DIR, exist_ok=True)

# ============ Flask App ============
app = Flask(__name__)

# Job storage (in-memory for simplicity)
JOBS = {}
JOBS_LOCK = threading.Lock()

# Dataset cache
DATASETS = {}


def get_mapping_path():
    """Find the mapping.json file"""
    for path in MAPPING_PATHS:
        if os.path.exists(path):
            return path
    return None


def load_mapping():
    """Load dataset mapping from mapping.json"""
    mapping_path = get_mapping_path()
    if not mapping_path:
        print(f"Warning: mapping.json not found in any of: {MAPPING_PATHS}")
        return {}

    try:
        with open(mapping_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading mapping.json: {e}")
        return {}


def get_dataset_path(said):
    """Get h5ad file path for a dataset ID"""
    mapping = load_mapping()
    if said not in mapping:
        return None

    file_path = mapping[said].get('file_path')
    if file_path:
        # Normalize path separators
        file_path = file_path.replace('\\', os.sep).replace('/', os.sep)
    return file_path


def load_dataset(said):
    """Load h5ad file for a dataset, with caching"""
    if said in DATASETS:
        return DATASETS[said]

    file_path = get_dataset_path(said)
    if not file_path or not os.path.exists(file_path):
        return None

    try:
        adata = sc.read_h5ad(file_path)
        DATASETS[said] = adata
        return adata
    except Exception as e:
        print(f"Error loading dataset {said}: {e}")
        return None


def get_cache_key(said, cell_types):
    """Generate cache key for analysis results"""
    sorted_types = sorted(cell_types)
    key_str = f"{said}:{','.join(sorted_types)}"
    return hashlib.md5(key_str.encode()).hexdigest()


def get_cached_results(cache_key):
    """Check for cached results"""
    cache_file = os.path.join(CACHE_DIR, f"{cache_key}.json")
    if os.path.exists(cache_file):
        try:
            mtime = os.path.getmtime(cache_file)
            if time.time() - mtime < CACHE_DURATION:
                with open(cache_file, 'r') as f:
                    return json.load(f)
        except Exception:
            pass
    return None


def save_cached_results(cache_key, results):
    """Save results to cache"""
    cache_file = os.path.join(CACHE_DIR, f"{cache_key}.json")
    try:
        with open(cache_file, 'w') as f:
            json.dump(results, f)
    except Exception as e:
        print(f"Error caching results: {e}")


def run_cpdb_analysis_simple(adata, selected_cell_types, senders=None, receivers=None):
    """
    Run a simplified CellPhoneDB-like analysis without the full cellphonedb package.
    Uses ligand-receptor pairs from a basic database.
    """
    # Subset data by selected cell types
    cell_type_col = CELL_TYPE_COL if CELL_TYPE_COL in adata.obs.columns else 'cell_type'
    mask = adata.obs[cell_type_col].isin(selected_cell_types)
    adata_sub = adata[mask].copy()

    if adata_sub.n_obs == 0:
        return {'error': 'No cells found for selected cell types'}

    # Get expression matrix
    if issparse(adata_sub.X):
        expr_matrix = pd.DataFrame(
            adata_sub.X.toarray(),
            index=adata_sub.obs_names,
            columns=adata_sub.var_names
        )
    else:
        expr_matrix = pd.DataFrame(
            adata_sub.X,
            index=adata_sub.obs_names,
            columns=adata_sub.var_names
        )

    # Basic ligand-receptor pairs (example set - expand as needed)
    lr_pairs = [
        ('CD40LG', 'CD40'),
        ('TGFB1', 'TGFBR1'),
        ('TGFB1', 'TGFBR2'),
        ('IL6', 'IL6R'),
        ('IL1B', 'IL1R1'),
        ('TNF', 'TNFRSF1A'),
        ('TNF', 'TNFRSF1B'),
        ('VEGFA', 'FLT1'),
        ('VEGFA', 'KDR'),
        ('CCL2', 'CCR2'),
        ('CCL5', 'CCR5'),
        ('CXCL12', 'CXCR4'),
        ('CXCL8', 'CXCR1'),
        ('CXCL8', 'CXCR2'),
        ('EGF', 'EGFR'),
        ('FGF2', 'FGFR1'),
        ('HGF', 'MET'),
        ('PDGFA', 'PDGFRA'),
        ('PDGFB', 'PDGFRB'),
        ('WNT5A', 'FZD5'),
        ('NOTCH1', 'JAG1'),
        ('DLL1', 'NOTCH1'),
        ('CTLA4', 'CD80'),
        ('CTLA4', 'CD86'),
        ('CD28', 'CD80'),
        ('CD28', 'CD86'),
        ('FASLG', 'FAS'),
        ('COL1A1', 'ITGA1'),
        ('COL1A1', 'ITGB1'),
        ('FN1', 'ITGA5'),
        ('LAMB1', 'ITGA6'),
    ]

    # Filter to genes present in dataset
    available_genes = set(adata_sub.var_names)
    valid_pairs = [(l, r) for l, r in lr_pairs if l in available_genes and r in available_genes]

    if len(valid_pairs) == 0:
        return {'error': 'No valid ligand-receptor pairs found in dataset'}

    # Calculate mean expression per cell type
    cell_types_in_data = adata_sub.obs[cell_type_col].unique().tolist()
    mean_expr = {}
    for ct in cell_types_in_data:
        ct_mask = adata_sub.obs[cell_type_col] == ct
        ct_expr = expr_matrix[ct_mask]
        mean_expr[ct] = ct_expr.mean()

    # Compute interaction scores
    interactions = []
    heatmap_data = {}

    for ligand, receptor in valid_pairs:
        for ct_sender in cell_types_in_data:
            for ct_receiver in cell_types_in_data:
                # Apply sender/receiver filter if specified
                if senders and ct_sender not in senders:
                    continue
                if receivers and ct_receiver not in receivers:
                    continue

                ligand_expr = mean_expr[ct_sender].get(ligand, 0)
                receptor_expr = mean_expr[ct_receiver].get(receptor, 0)

                # Interaction score (product of expressions)
                score = ligand_expr * receptor_expr

                if score > 0:
                    interaction_name = f"{ligand}_{receptor}"
                    cell_pair = f"{ct_sender}|{ct_receiver}"

                    interactions.append({
                        'interaction': interaction_name,
                        'ligand': ligand,
                        'receptor': receptor,
                        'cell_type_sender': ct_sender,
                        'cell_type_receiver': ct_receiver,
                        'ligand_expr': float(ligand_expr),
                        'receptor_expr': float(receptor_expr),
                        'score': float(score),
                        'pvalue': 0.05  # Placeholder
                    })

                    # For heatmap
                    if interaction_name not in heatmap_data:
                        heatmap_data[interaction_name] = {}
                    heatmap_data[interaction_name][cell_pair] = float(score)

    # Sort by score
    interactions.sort(key=lambda x: x['score'], reverse=True)

    # Build heatmap matrix
    if heatmap_data:
        all_interactions = list(heatmap_data.keys())[:50]  # Top 50
        all_cell_pairs = sorted(set(
            f"{i['cell_type_sender']}|{i['cell_type_receiver']}"
            for i in interactions
        ))

        heatmap_matrix = []
        for interaction in all_interactions:
            row = []
            for cell_pair in all_cell_pairs:
                row.append(heatmap_data.get(interaction, {}).get(cell_pair, 0))
            heatmap_matrix.append(row)
    else:
        all_interactions = []
        all_cell_pairs = []
        heatmap_matrix = []

    return {
        'interactions': interactions[:100],  # Top 100 interactions
        'heatmap_data': {
            'z': heatmap_matrix,
            'x': all_cell_pairs,
            'y': all_interactions
        },
        'dotplot_data': {
            'interactions': [i['interaction'] for i in interactions[:30]],
            'cell_pairs': list(set(f"{i['cell_type_sender']}|{i['cell_type_receiver']}" for i in interactions[:30])),
            'scores': [i['score'] for i in interactions[:30]],
            'sizes': [i['score'] for i in interactions[:30]]
        },
        'summary': {
            'n_interactions': len(interactions),
            'n_cell_types': len(cell_types_in_data),
            'n_lr_pairs': len(valid_pairs)
        }
    }


def run_analysis_thread(job_id, said, cell_types, senders, receivers):
    """Background thread for running analysis"""
    try:
        with JOBS_LOCK:
            JOBS[job_id]['status'] = 'running'
            JOBS[job_id]['progress'] = 10

        # Load dataset
        adata = load_dataset(said)
        if adata is None:
            with JOBS_LOCK:
                JOBS[job_id]['status'] = 'failed'
                JOBS[job_id]['error'] = 'Dataset not found'
            return

        with JOBS_LOCK:
            JOBS[job_id]['progress'] = 30

        # Check cache
        cache_key = get_cache_key(said, cell_types)
        cached = get_cached_results(cache_key)

        if cached:
            with JOBS_LOCK:
                JOBS[job_id]['status'] = 'completed'
                JOBS[job_id]['progress'] = 100
                JOBS[job_id]['results'] = cached
            return

        with JOBS_LOCK:
            JOBS[job_id]['progress'] = 50

        # Run analysis
        results = run_cpdb_analysis_simple(adata, cell_types, senders, receivers)

        if 'error' in results:
            with JOBS_LOCK:
                JOBS[job_id]['status'] = 'failed'
                JOBS[job_id]['error'] = results['error']
            return

        # Cache results
        save_cached_results(cache_key, results)

        with JOBS_LOCK:
            JOBS[job_id]['status'] = 'completed'
            JOBS[job_id]['progress'] = 100
            JOBS[job_id]['results'] = results

    except Exception as e:
        with JOBS_LOCK:
            JOBS[job_id]['status'] = 'failed'
            JOBS[job_id]['error'] = str(e)


# ============ API Endpoints ============

@app.route('/api/cell-types', methods=['GET'])
def get_cell_types():
    """Get available cell types for a dataset"""
    said = request.args.get('said')

    if not said:
        return jsonify({'error': 'Missing said parameter'}), 400

    adata = load_dataset(said)
    if adata is None:
        return jsonify({'error': f'Dataset {said} not found'}), 404

    # Get cell type column
    cell_type_col = CELL_TYPE_COL if CELL_TYPE_COL in adata.obs.columns else 'cell_type'

    if cell_type_col not in adata.obs.columns:
        # Try to find any cell type column
        possible_cols = ['cell_type', 'celltype', 'CellType', 'cluster', 'leiden', 'louvain']
        for col in possible_cols:
            if col in adata.obs.columns:
                cell_type_col = col
                break
        else:
            return jsonify({'error': 'No cell type column found in dataset'}), 404

    cell_types = sorted(adata.obs[cell_type_col].unique().tolist())

    # Get cell counts per type
    cell_counts = adata.obs[cell_type_col].value_counts().to_dict()

    return jsonify({
        'cell_types': cell_types,
        'cell_counts': {str(k): int(v) for k, v in cell_counts.items()},
        'total_cells': int(adata.n_obs)
    })


@app.route('/api/run-analysis', methods=['POST'])
def run_analysis():
    """Start a new CellPhoneDB analysis job"""
    data = request.get_json() or request.form

    said = data.get('said')
    cell_types_raw = data.get('cell_types')
    senders_raw = data.get('senders')
    receivers_raw = data.get('receivers')

    if not said:
        return jsonify({'error': 'Missing said parameter'}), 400

    # Parse cell types
    if isinstance(cell_types_raw, str):
        try:
            cell_types = json.loads(cell_types_raw)
        except:
            cell_types = [cell_types_raw]
    else:
        cell_types = cell_types_raw or []

    if len(cell_types) < 2:
        return jsonify({'error': 'Please select at least 2 cell types'}), 400

    # Parse senders/receivers (optional)
    senders = None
    receivers = None

    if senders_raw:
        if isinstance(senders_raw, str):
            try:
                senders = json.loads(senders_raw)
            except:
                senders = [senders_raw]
        else:
            senders = senders_raw

    if receivers_raw:
        if isinstance(receivers_raw, str):
            try:
                receivers = json.loads(receivers_raw)
            except:
                receivers = [receivers_raw]
        else:
            receivers = receivers_raw

    # Create job
    job_id = str(uuid.uuid4())

    with JOBS_LOCK:
        JOBS[job_id] = {
            'status': 'pending',
            'progress': 0,
            'created_at': datetime.now().isoformat(),
            'said': said,
            'cell_types': cell_types,
            'results': None,
            'error': None
        }

    # Start background thread
    thread = threading.Thread(
        target=run_analysis_thread,
        args=(job_id, said, cell_types, senders, receivers)
    )
    thread.daemon = True
    thread.start()

    return jsonify({'job_id': job_id, 'status': 'pending'})


@app.route('/api/status', methods=['GET'])
def get_status():
    """Check job status"""
    job_id = request.args.get('job_id')

    if not job_id:
        return jsonify({'error': 'Missing job_id parameter'}), 400

    with JOBS_LOCK:
        job = JOBS.get(job_id)

    if not job:
        return jsonify({'error': 'Job not found'}), 404

    return jsonify({
        'job_id': job_id,
        'status': job['status'],
        'progress': job.get('progress', 0),
        'error': job.get('error')
    })


@app.route('/api/results', methods=['GET'])
def get_results():
    """Get analysis results"""
    job_id = request.args.get('job_id')

    if not job_id:
        return jsonify({'error': 'Missing job_id parameter'}), 400

    with JOBS_LOCK:
        job = JOBS.get(job_id)

    if not job:
        return jsonify({'error': 'Job not found'}), 404

    if job['status'] != 'completed':
        return jsonify({
            'error': 'Results not ready',
            'status': job['status']
        }), 400

    return jsonify(job['results'])


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'jobs_count': len(JOBS)
    })


# ============ Main ============
if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='CellPhoneDB Analysis API')
    parser.add_argument('--port', type=int, default=8054, help='Port to run on')
    parser.add_argument('--host', type=str, default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--test', action='store_true', help='Run tests')
    args = parser.parse_args()

    if args.test:
        print("Running tests...")
        mapping_path = get_mapping_path()
        print(f"Mapping path: {mapping_path}")
        if mapping_path:
            mapping = load_mapping()
            print(f"Loaded {len(mapping)} datasets")
            if mapping:
                first_id = list(mapping.keys())[0]
                print(f"Testing dataset: {first_id}")
                adata = load_dataset(first_id)
                if adata:
                    print(f"Loaded: {adata.n_obs} cells, {adata.n_vars} genes")
                    print(f"Columns: {list(adata.obs.columns)}")
        print("Tests complete.")
    else:
        print(f"\nStarting CellPhoneDB Analysis API...")
        print(f"URL: http://{args.host}:{args.port}/")
        print("=" * 60)
        app.run(debug=False, host=args.host, port=args.port)
