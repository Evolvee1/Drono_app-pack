#!/bin/bash

# Start servers for ADB Settings Management Solution

# Ensure script is executable
chmod +x server/tools/*.sh

# Create logs directory if it doesn't exist
mkdir -p server/tools/logs

# Start the Settings API Server
echo "Starting Settings API Server..."
cd server/tools && \
python settings_api_server.py &
API_PID=$!

echo "Settings API Server started with PID: $API_PID"
echo "API available at: http://localhost:8000"

# Add trap to kill servers on exit
trap "kill $API_PID; echo 'Servers stopped'; exit" SIGINT SIGTERM EXIT

# Keep script running
echo "Press Ctrl+C to stop servers"
wait 