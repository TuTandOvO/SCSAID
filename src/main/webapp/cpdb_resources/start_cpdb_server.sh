#!/bin/bash
# Start CellPhoneDB Analysis Server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDA_PATH="/root/miniconda3"
CONDA_ENV="scrna"
PORT=8054

# Check if already running
if curl -s http://127.0.0.1:$PORT/health > /dev/null 2>&1; then
    echo "CellPhoneDB server already running on port $PORT"
    exit 0
fi

# Activate conda and start server
source "$CONDA_PATH/etc/profile.d/conda.sh"
conda activate "$CONDA_ENV"

echo "Starting CellPhoneDB server on port $PORT..."
cd "$SCRIPT_DIR"
nohup python3 cpdb_analysis.py --port $PORT --host 127.0.0.1 > /tmp/cpdb_server.log 2>&1 &

# Wait for startup
sleep 3

if curl -s http://127.0.0.1:$PORT/health > /dev/null 2>&1; then
    echo "CellPhoneDB server started successfully"
else
    echo "Failed to start CellPhoneDB server. Check /tmp/cpdb_server.log"
    exit 1
fi
