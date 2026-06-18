# Gene Set Scoring Analysis

## Overview

The Gene Set Scoring feature allows users to score cell types using Reactome pathway gene sets with three different methods: AUCell, GSVA, and Mean Expression. The system includes smart recommendations and search functionality.

## Features

### Core Functionality
- **Multiple Scoring Methods**:
  - **AUCell**: Activity-by-cell - ranks genes and calculates area under the curve
  - **GSVA**: Gene Set Variation Analysis - Z-score normalized mean expression
  - **Mean Expression**: Simple average expression across gene set

- **Smart Recommendations**:
  - Algorithm analyzes dataset to recommend 5 most relevant gene sets
  - Based on:
    - Gene expression overlap (optimal 30-80%)
    - Gene set size (prefers 10-100 genes)
    - Expression variability across cells

- **Search Functionality**:
  - Search across 1,333 Reactome pathways
  - Real-time filtering
  - Shows gene set size and description

- **Publication-Ready Visualizations**:
  - Violin plots per cell type
  - Statistical annotations
  - Export as PNG/SVG
  - Warm scientific aesthetic

### Smart Recommendation Algorithm

The recommendation system scores each gene set based on three criteria:

1. **Expression Overlap** (40% weight):
   - Calculates percentage of gene set genes expressed in dataset
   - Optimal range: 30-80% overlap
   - Too low = sparse data, too high = housekeeping genes

2. **Gene Set Size** (30% weight):
   - Prefers medium-sized sets (10-100 genes)
   - Small sets: may lack statistical power
   - Large sets: too broad, harder to interpret

3. **Expression Variability** (30% weight):
   - Higher variability = more informative across cell types
   - Low variability = constitutively expressed genes

**Final Score**: `0.4 × overlap_score + 0.3 × size_score + 0.3 × variability_score`

Top 5 scoring gene sets are recommended for each dataset.

## Data Structure

### Gene Sets Location
```
scoring_resources/
└── mouse_gene_sets/
    └── reactome_sets/
        ├── REACTOME_APOPTOSIS.gmt
        ├── REACTOME_CELL_CYCLE.gmt
        ├── REACTOME_IMMUNE_SYSTEM.gmt
        └── ... (1,333 total gene sets)
```

### GMT File Format
```
GENE_SET_NAME<tab>URL<tab>GENE1<tab>GENE2<tab>GENE3...
```

**Example**:
```
REACTOME_APOPTOSIS	https://...	BAX	BCL2	CASP3	CASP8	FADD
```

## Scoring Methods Explained

### 1. AUCell (Activity by Cell)

**How it works**:
1. Rank all genes by expression in each cell
2. Calculate area under recovery curve for gene set genes
3. Higher AUC = gene set more active in that cell

**Best for**: Identifying cells with high pathway activity

**Output**: Scores 0-1, higher = more active

### 2. GSVA (Gene Set Variation Analysis)

**How it works**:
1. Z-score normalize each gene across cells
2. Calculate mean Z-score for gene set genes
3. Positive = upregulated, negative = downregulated

**Best for**: Comparing relative pathway activity across cell types

**Output**: Z-scores, centered around 0

### 3. Mean Expression

**How it works**:
1. Average raw/normalized expression of all genes in set
2. Simple, interpretable metric

**Best for**: Quick screening, highly interpretable

**Output**: Mean expression value (units depend on data normalization)

## Installation

### Dependencies

```bash
pip install dash plotly pandas numpy scanpy scipy scikit-learn flask
```

### File Structure

```
scoring_resources/
├── README.md (this file)
├── gene_set_scoring.py          # Main application
├── start_scoring.sh              # Startup script
└── mouse_gene_sets/
    └── reactome_sets/            # 1,333 GMT files
        └── *.gmt
```

## Usage

### 1. Start the Scoring Server

```bash
cd src/main/webapp/scoring_resources
./start_scoring.sh
```

Or start Python directly:
```bash
python3 gene_set_scoring.py
```

Server starts on: `http://localhost:8052/gene-scoring/`

### 2. Access via Details Page

1. Start Tomcat server
2. Start scoring server (as above)
3. Navigate to dataset details page
4. Scroll to "Gene Set Scoring Analysis" section

### 3. Using the Interface

**Recommended Gene Sets**:
- View top 5 recommended gene sets for your dataset
- Click any recommendation to score and visualize

**Search**:
- Type keywords (e.g., "immune", "metabolism", "signaling")
- Browse filtered results
- Click to score and visualize

**Scoring Method**:
- Select AUCell, GSVA, or Mean Expression
- Method applies to all visualizations

**Visualization**:
- Violin plot shows score distribution per cell type
- Statistical annotations included
- Export as publication-ready figure

## Design Integration

### Warm Scientific Aesthetic

**Colors**:
- Primary: `#e8927c` (Coral)
- Secondary: `#d4a574` (Bronze)
- Background: `#faf8f5` (Warm beige)
- Text: `#1a2332` (Dark navy)
- Borders: `#e5e0d8` (Light taupe)

**Typography**:
- Headers: Cormorant Garamond (serif)
- Body: Source Sans 3 (sans-serif)
- Monospace: JetBrains Mono

**Components**:
- Rounded corners (8-12px)
- Subtle shadows
- Smooth transitions
- Responsive layout

## API Endpoints

### `/gene-scoring/?dataset=<SAID_ID>`
Main application interface

**Parameters**:
- `dataset`: Dataset ID (e.g., SAID001)

**Returns**: Interactive Dash application

### `/load-dataset/<dataset_id>` (internal)
Loads h5ad file for scoring

**Parameters**:
- `dataset_id`: SAID identifier

**Returns**: JSON status

## Troubleshooting

### Server won't start
- Check Python 3 installed: `python3 --version`
- Install dependencies: `pip install -r requirements.txt`
- Check port 8052 available: `lsof -i :8052`

### No recommendations shown
- Verify dataset has cell type annotations
- Check h5ad file has expression data
- Ensure genes are in proper format (symbols)

### Search not working
- Verify GMT files in `mouse_gene_sets/reactome_sets/`
- Check file permissions
- Restart server

### Plots not generating
- Check gene set has genes present in dataset
- Verify cell type column exists (`cell_type` or similar)
- Check console for errors

## Performance Optimization

**For Large Datasets** (>50,000 cells):
- Consider downsampling for visualization
- Use mean expression for faster scoring
- AUCell is most computationally intensive

**Memory Usage**:
- Server caches loaded datasets
- Each dataset ~100MB-1GB in memory
- Restart server to clear cache

## Development

### Adding New Gene Sets

1. Create GMT file(s) in `mouse_gene_sets/reactome_sets/`
2. Follow GMT format (tab-separated)
3. Restart server to reload

### Modifying Recommendation Algorithm

Edit `recommend_gene_sets()` function in `gene_set_scoring.py`:
- Adjust weight parameters (currently 0.4, 0.3, 0.3)
- Modify optimal overlap range (currently 0.55 ± 0.55)
- Change size preferences (currently 10-100 genes)

### Custom Scoring Methods

Add new method to scoring functions:
```python
def score_custom(adata, gene_set, cell_type_col='cell_type'):
    # Your implementation
    return pd.DataFrame({'score': ..., 'cell_type': ...})
```

## Citation

When using this feature, please cite:

- **Reactome**: Gillespie et al. (2022) Nucleic Acids Research
- **AUCell**: Aibar et al. (2017) Nature Methods
- **GSVA**: Hänzelmann et al. (2013) BMC Bioinformatics

## Future Enhancements

Planned features:
- Multiple gene set comparison
- Export score matrices
- Custom gene set upload
- Batch scoring across datasets
- Gene set enrichment testing
- Integration with DEG results

## Support

For issues or questions:
1. Check this documentation
2. Review console logs
3. Verify data format requirements
4. Check GitHub issues

---

**Version**: 1.0.0
**Last Updated**: 2026-02-02
**Compatibility**: scSAID v1.0+
