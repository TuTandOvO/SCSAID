"""
Script to create integrated h5ad file for gene expression visualization

This script:
1. Loads all individual dataset h5ad files
2. Concatenates them into a single AnnData object
3. Performs batch integration using Harmony
4. Computes UMAP on integrated space
5. Saves the integrated dataset

Requirements:
    pip install scanpy pandas numpy harmonypy openpyxl

Usage:
    python3 create_integrated_dataset.py

Author: scSAID Development Team
Date: 2026-02-02
"""

import os
import sys
import scanpy as sc
import pandas as pd
import numpy as np
from pathlib import Path

# Configuration
SCRIPT_DIR = Path(__file__).parent
BASE_DIR = SCRIPT_DIR.parent
INFO_FILE = BASE_DIR / "WEB-INF" / "IntegrateTable.xlsx"
OUTPUT_FILE = SCRIPT_DIR / "integrated.h5ad"

# You may need to update this path to point to your h5ad files directory
H5AD_DIR = BASE_DIR / "dataset_resources" / "h5ad_files"

print("=" * 70)
print("scSAID Integrated Dataset Creator")
print("=" * 70)
print()

# Check if info file exists
if not INFO_FILE.exists():
    print(f"Error: IntegrateTable.xlsx not found at {INFO_FILE}")
    print("This file is required to know which datasets to integrate.")
    sys.exit(1)

# Load dataset information
print(f"Loading dataset information from {INFO_FILE}...")
try:
    info_df = pd.read_excel(INFO_FILE)
    print(f"Found {len(info_df)} datasets in IntegrateTable.xlsx")
except Exception as e:
    print(f"Error reading IntegrateTable.xlsx: {e}")
    sys.exit(1)

# Check if h5ad directory exists
if not H5AD_DIR.exists():
    print()
    print(f"Error: h5ad directory not found at {H5AD_DIR}")
    print()
    print("Please update the H5AD_DIR variable in this script to point")
    print("to the directory containing your h5ad files.")
    print()
    print("Example:")
    print('    H5AD_DIR = Path("/path/to/your/h5ad/files")')
    sys.exit(1)

print()
print(f"Looking for h5ad files in: {H5AD_DIR}")
print()

# Ask user for confirmation
print("This script will:")
print("  1. Load all individual dataset h5ad files")
print("  2. Concatenate and integrate using Harmony")
print("  3. Compute UMAP on integrated space")
print(f"  4. Save to: {OUTPUT_FILE}")
print()

# Check for existing output file
if OUTPUT_FILE.exists():
    print(f"Warning: {OUTPUT_FILE} already exists.")
    response = input("Overwrite? (yes/no): ").strip().lower()
    if response not in ['yes', 'y']:
        print("Aborted.")
        sys.exit(0)
    print()

# Load all datasets
print("=" * 70)
print("Step 1: Loading datasets...")
print("=" * 70)

adatas = []
failed_datasets = []
skipped_datasets = []

for idx, row in info_df.iterrows():
    said = row['SAID']
    h5ad_filename = row['file']
    h5ad_path = H5AD_DIR / h5ad_filename

    if not h5ad_path.exists():
        skipped_datasets.append((said, "File not found"))
        continue

    try:
        print(f"Loading {said}...", end=" ")
        adata = sc.read_h5ad(h5ad_path)

        # Add metadata
        adata.obs['dataset'] = said
        adata.obs['gse'] = row['GSE']
        adata.obs['species'] = row.get('species', 'unknown')

        # Ensure cell_type exists
        if 'cell_type' not in adata.obs:
            print(f"Warning: {said} missing 'cell_type' annotation")
            # Try alternative names
            for alt_col in ['celltype', 'cluster', 'leiden', 'louvain']:
                if alt_col in adata.obs:
                    adata.obs['cell_type'] = adata.obs[alt_col]
                    print(f" (using '{alt_col}' as cell_type)", end="")
                    break
            else:
                adata.obs['cell_type'] = 'Unknown'

        adatas.append(adata)
        print(f"✓ {adata.n_obs} cells, {adata.n_vars} genes")

    except Exception as e:
        failed_datasets.append((said, str(e)))
        print(f"✗ Error: {e}")

print()
print(f"Successfully loaded: {len(adatas)} datasets")
if len(skipped_datasets) > 0:
    print(f"Skipped: {len(skipped_datasets)} datasets (files not found)")
if len(failed_datasets) > 0:
    print(f"Failed: {len(failed_datasets)} datasets (errors)")

if len(adatas) == 0:
    print("\nError: No datasets could be loaded!")
    sys.exit(1)

# Concatenate datasets
print()
print("=" * 70)
print("Step 2: Concatenating datasets...")
print("=" * 70)

try:
    # Use outer join to keep all genes
    print("Concatenating with outer join (keeping all genes)...")
    integrated = sc.concat(
        adatas,
        join='outer',
        label='batch',
        keys=[a.obs['dataset'].iloc[0] for a in adatas],
        index_unique='_'
    )
    print(f"✓ Concatenated: {integrated.n_obs:,} cells, {integrated.n_vars:,} genes")
except Exception as e:
    print(f"✗ Error during concatenation: {e}")
    sys.exit(1)

# Preprocessing
print()
print("=" * 70)
print("Step 3: Preprocessing...")
print("=" * 70)

try:
    print("Filtering genes (min_cells=10)...", end=" ")
    sc.pp.filter_genes(integrated, min_cells=10)
    print(f"✓ {integrated.n_vars:,} genes remaining")

    print("Normalizing counts (target_sum=1e4)...", end=" ")
    sc.pp.normalize_total(integrated, target_sum=1e4)
    print("✓")

    print("Log-transforming...", end=" ")
    sc.pp.log1p(integrated)
    print("✓")

    print("Identifying highly variable genes (n=2000)...", end=" ")
    sc.pp.highly_variable_genes(
        integrated,
        n_top_genes=2000,
        batch_key='batch',
        flavor='seurat_v3'
    )
    print("✓")

    print("Scaling...", end=" ")
    sc.pp.scale(integrated, max_value=10)
    print("✓")

    print("Computing PCA (n=50)...", end=" ")
    sc.tl.pca(integrated, n_comps=50)
    print("✓")

except Exception as e:
    print(f"✗ Error during preprocessing: {e}")
    sys.exit(1)

# Integration with Harmony
print()
print("=" * 70)
print("Step 4: Batch integration with Harmony...")
print("=" * 70)

try:
    print("Running Harmony integration...")
    print("(This may take several minutes for large datasets)")

    import scanpy.external as sce
    sce.pp.harmony_integrate(integrated, 'batch')
    print("✓ Harmony integration complete")

except ImportError:
    print("✗ Error: harmonypy not installed")
    print("Please install: pip install harmonypy")
    sys.exit(1)
except Exception as e:
    print(f"✗ Error during Harmony integration: {e}")
    sys.exit(1)

# Compute UMAP
print()
print("=" * 70)
print("Step 5: Computing UMAP...")
print("=" * 70)

try:
    print("Computing nearest neighbors on integrated space...", end=" ")
    sc.pp.neighbors(integrated, use_rep='X_pca_harmony')
    print("✓")

    print("Computing UMAP...", end=" ")
    sc.tl.umap(integrated)
    print("✓")

    print(f"UMAP coordinates shape: {integrated.obsm['X_umap'].shape}")

except Exception as e:
    print(f"✗ Error during UMAP computation: {e}")
    sys.exit(1)

# Save integrated dataset
print()
print("=" * 70)
print("Step 6: Saving integrated dataset...")
print("=" * 70)

try:
    print(f"Saving to {OUTPUT_FILE}...")
    integrated.write(OUTPUT_FILE, compression='gzip')
    print("✓ Saved successfully")

    # Print file size
    file_size = OUTPUT_FILE.stat().st_size / (1024 * 1024 * 1024)  # GB
    print(f"File size: {file_size:.2f} GB")

except Exception as e:
    print(f"✗ Error saving file: {e}")
    sys.exit(1)

# Summary
print()
print("=" * 70)
print("Integration Complete!")
print("=" * 70)
print()
print(f"Integrated dataset saved to: {OUTPUT_FILE}")
print()
print("Summary:")
print(f"  - Total cells: {integrated.n_obs:,}")
print(f"  - Total genes: {integrated.n_vars:,}")
print(f"  - Number of datasets: {len(adatas)}")
print(f"  - Species: {', '.join(integrated.obs['species'].unique())}")
print(f"  - Cell types: {len(integrated.obs['cell_type'].unique())}")
print()

# Print metadata info
print("Metadata columns in integrated dataset:")
for col in integrated.obs.columns:
    print(f"  - {col}")
print()

# Print UMAP info
print("Embeddings:")
for key in integrated.obsm.keys():
    print(f"  - {key}: {integrated.obsm[key].shape}")
print()

if len(failed_datasets) > 0:
    print("Failed datasets:")
    for said, error in failed_datasets:
        print(f"  - {said}: {error}")
    print()

if len(skipped_datasets) > 0:
    print("Skipped datasets:")
    for said, reason in skipped_datasets:
        print(f"  - {said}: {reason}")
    print()

print("Next steps:")
print("  1. Start the gene visualization server:")
print("     cd gene_viz_resources")
print("     ./start_gene_viz.sh")
print()
print("  2. Start your Tomcat server")
print()
print("  3. Navigate to gene search page:")
print("     http://localhost:8080/gene-search.jsp")
print()
print("  4. Search for genes and visualize on integrated UMAP!")
print()
print("=" * 70)
