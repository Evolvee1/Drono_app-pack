#!/bin/bash
# Quick Update Script for Drono App
# Changes settings and automatically restarts the simulation session

# Define package name
PACKAGE="com.example.imtbf.debug"
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to send broadcast command
send_broadcast() {
  local command="$1"
  local params="$2"
  
  if [ -z "$params" ]; then
    echo "Sending command: $command"
  else
    echo "Setting $command to $params"
  fi
  
  adb shell "am broadcast -a $BROADCAST_ACTION -e command '$command' $params -p $PACKAGE" > /dev/null
  sleep 0.5
}

# Process arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <setting> <value> [<setting2> <value2> ...]"
  echo ""
  echo "Available settings:"
  echo "  iterations <number>      - Set the number of iterations"
  echo "  min_interval <seconds>   - Set minimum interval"
  echo "  max_interval <seconds>   - Set maximum interval"
  echo "  url <url>                - Set target URL"
  echo "  delay <milliseconds>     - Set airplane mode delay"
  echo ""
  echo "Examples:"
  echo "  $0 iterations 200"
  echo "  $0 min_interval 30 max_interval 60"
  exit 1
fi

# Always stop and restart the simulation regardless of status
# This ensures the UI reflects our changes
echo "Stopping any running simulation..."
send_broadcast "stop" ""
sleep 2

# Change all requested settings
echo "Updating settings..."
arg_count=$#
i=1

while [ $i -le $((arg_count-1)) ]; do
  setting="${!i}"
  i=$((i+1))
  value="${!i}"
  i=$((i+1))
  
  # Apply setting change based on parameter type
  case "$setting" in
    "iterations")
      send_broadcast "set_iterations" "-e value $value"
      ;;
    "min_interval")
      send_broadcast "set_min_interval" "-e value $value"
      ;;
    "max_interval")
      send_broadcast "set_max_interval" "-e value $value"
      ;;
    "url")
      send_broadcast "set_url" "-e value '$value'"
      ;;
    "delay")
      send_broadcast "set_airplane_delay" "-e value $value"
      ;;
    *)
      echo "⚠️ Unknown setting: $setting (skipping)"
      ;;
  esac
done

# Start a new simulation
echo "Starting new simulation with updated settings..."
send_broadcast "start" ""
echo "✅ Simulation restarted with new settings!" 