#!/bin/bash

# Start Gene Set Scoring Server for scSAID
# This script starts the Dash server on port 8052

echo "======================================================"
echo "  scSAID Gene Set Scoring Server"
echo "======================================================"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed or not in PATH"
    exit 1
fi

# Check if required packages are installed
echo "Checking dependencies..."
python3 -c "import dash, plotly, pandas, numpy, scanpy, scipy, sklearn, flask" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Required Python packages are missing"
    echo "Please install: pip install dash plotly pandas numpy scanpy scipy scikit-learn flask"
    exit 1
fi

echo "Dependencies OK"
echo ""

# Change to script directory
cd "$SCRIPT_DIR"

# Check if gene sets directory exists
if [ ! -d "mouse_gene_sets/reactome_sets" ]; then
    echo "Error: mouse_gene_sets/reactome_sets directory not found"
    exit 1
fi

# Count gene sets
GENESET_COUNT=$(ls mouse_gene_sets/reactome_sets/*.gmt 2>/dev/null | wc -l)
echo "Found $GENESET_COUNT gene set files"

if [ "$GENESET_COUNT" -eq 0 ]; then
    echo "Error: No GMT files found in mouse_gene_sets/reactome_sets/"
    exit 1
fi

echo ""

# Start the server
echo "Starting server on http://localhost:8052/gene-scoring/"
echo "Press Ctrl+C to stop"
echo "======================================================"
echo ""

python3 gene_set_scoring.py
