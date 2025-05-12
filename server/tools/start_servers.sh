#!/bin/bash

# start_servers.sh - Start all servers and open dashboard
# This script starts the API server, static file server, and opens the dashboard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_SERVER="$SCRIPT_DIR/settings_api_server.py"
FRONTEND_SERVER="$SCRIPT_DIR/serve_frontend.py"
STATIC_DIR="$SCRIPT_DIR/static"
API_PORT=8000
FRONTEND_PORT=8080

echo "Starting VeeWoy Device Settings Servers..."

# Ensure the scripts are executable
chmod +x "$API_SERVER" "$FRONTEND_SERVER"

# Check if servers are already running
if ps aux | grep -v grep | grep -q "$API_SERVER"; then
  echo "API server already running"
else
  echo "Starting API server on port $API_PORT..."
  python3 "$API_SERVER" &
  API_PID=$!
  echo "API server started with PID $API_PID"
fi

if ps aux | grep -v grep | grep -q "$FRONTEND_SERVER"; then
  echo "Frontend server already running"
else
  echo "Starting frontend server on port $FRONTEND_PORT..."
  python3 "$FRONTEND_SERVER" &
  FRONTEND_PID=$!
  echo "Frontend server started with PID $FRONTEND_PID"
fi

# Wait for servers to start
echo "Waiting for servers to start..."
sleep 3

# Try to open the dashboard
echo "Opening dashboard in your default browser..."
if command -v open &>/dev/null; then
  # macOS
  open "http://localhost:$FRONTEND_PORT"
elif command -v xdg-open &>/dev/null; then
  # Linux
  xdg-open "http://localhost:$FRONTEND_PORT"
elif command -v start &>/dev/null; then
  # Windows
  start "http://localhost:$FRONTEND_PORT"
else
  echo "Could not automatically open browser"
  echo "Please open http://localhost:$FRONTEND_PORT in your browser"
fi

echo ""
echo "Server URLs:"
echo "- API: http://localhost:$API_PORT"
echo "- Dashboard: http://localhost:$FRONTEND_PORT"
echo ""
echo "Test API with:"
echo "python3 test_settings_api.py help"
echo ""
echo "To stop servers, use:"
echo "ps aux | grep 'settings_api_server\|serve_frontend' | grep -v grep | awk '{print \$2}' | xargs kill"
echo ""

# Keep the script running to prevent background processes from being killed
# when the terminal is closed
echo "Press Ctrl+C to stop this script (servers will continue running in background)"
wait 