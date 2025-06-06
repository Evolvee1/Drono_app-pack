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

# Use default port 8000 or provided port as argument
PORT=8000
if [ -n "$1" ]; then
    PORT=$1
fi

# Start the server
echo "Starting server on port $PORT..."
echo "Access the dashboard at: http://localhost:$PORT"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Run the server with the specified port
python -m uvicorn main:app --host 0.0.0.0 --port $PORT

# Deactivate virtual environment
deactivate 