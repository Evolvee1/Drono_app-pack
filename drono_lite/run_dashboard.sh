#!/bin/bash
echo "Drono Lite Dashboard Server Launcher"
echo "===================================="

# Use default port 8080 or provided port as argument
PORT=8080
if [ -n "$1" ]; then
    PORT=$1
fi

# Activate virtual environment
if [ -d "venv/bin" ]; then
    source venv/bin/activate
else
    echo "Error: Virtual environment not found. Please run setup first."
    exit 1
fi

echo "Starting server on port $PORT..."
echo "Access the dashboard at: http://localhost:$PORT"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Run the server
python -m uvicorn main:app --host 0.0.0.0 --port $PORT

# Deactivate virtual environment
deactivate 