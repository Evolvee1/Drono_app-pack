#!/bin/bash
echo "Drono Lite Control Server"
echo "===================================="

# Set error handling
set -e

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Python not found. Please install Python 3.8 or higher."
    exit 1
fi

# Check if ADB is installed
if ! command -v adb &> /dev/null; then
    echo "ADB not found. Please install Android Debug Bridge and add it to your PATH."
    exit 1
fi

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies if needed
if [ ! -d "venv/lib/python3.*/site-packages/fastapi" ]; then
    echo "Installing dependencies..."
    pip install -r requirements.txt
fi

# Default settings
PORT=8000
QUIET_MODE=""
LOG_LEVEL=""

# Parse command line arguments
function show_help {
    echo "Usage: start_server.sh [--port PORT] [--quiet] [--log-level LEVEL]"
    echo ""
    echo "Options:"
    echo "  --port PORT       Set the server port (default: 8000)"
    echo "  --quiet           Run in quiet mode (suppresses status messages)"
    echo "  --log-level LEVEL Set logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)
            PORT="$2"
            shift 2
            ;;
        --quiet)
            QUIET_MODE="--quiet"
            shift
            ;;
        --log-level)
            LOG_LEVEL="--log-level $2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        *)
            # Skip unknown arguments
            shift
            ;;
    esac
done

# Start the server
echo "Starting server on port $PORT..."
echo "Access the dashboard at: http://localhost:$PORT"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Run the server with the specified port and logging options
python -m uvicorn main:app --host 0.0.0.0 --port $PORT $QUIET_MODE $LOG_LEVEL

# Deactivate virtual environment
deactivate 