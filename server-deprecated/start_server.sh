#!/bin/bash

# Set environment variables
export PYTHONPATH=$(pwd)
export SERVER_HOST="0.0.0.0"
export SERVER_PORT="8000"
export DEBUG="true"
export LOG_LEVEL="INFO"

# Create logs directory
mkdir -p logs

# Function to check ADB
check_adb() {
  echo "Checking ADB installation..."
  if ! command -v adb &> /dev/null; then
    echo "Error: ADB is not installed or not in PATH"
    exit 1
  fi
  
  echo "ADB version:"
  adb version
  
  echo "Checking for connected devices..."
  adb devices -l
}

# Make sure ADB is working
check_adb

# Start the server
echo "Starting Drono Server..."
python3 main.py 