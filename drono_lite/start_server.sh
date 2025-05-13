#!/bin/bash
# Drono Lite Control Server startup script

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

# Start the server
echo "Starting Drono Lite Control Server..."
echo "Server will be available at http://localhost:8000"
python main.py 