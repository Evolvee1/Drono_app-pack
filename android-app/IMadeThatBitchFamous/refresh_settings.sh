#!/bin/bash
# Script to change settings and refresh the UI to show changes

# Define package and activity names
PACKAGE="com.example.imtbf.debug"
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
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
  echo "Setting $command to $params"
  adb shell "am broadcast -a $BROADCAST_ACTION -e command '$command' $params -p $PACKAGE"
  sleep 1
}

# Function to restart the activity to refresh UI
restart_activity() {
  echo "Refreshing the app UI..."
  # First try to stop the app
  adb shell "am force-stop $PACKAGE"
  sleep 1
  # Then start the main activity again
  adb shell "am start -n $PACKAGE/$ACTIVITY"
  sleep 2
  echo "App UI refreshed"
}

# Main script logic
if [ $# -lt 2 ]; then
  echo "Usage: $0 <setting> <value>"
  echo "Available settings:"
  echo "  iterations <number> - Set the number of iterations"
  echo "  min_interval <seconds> - Set minimum interval"
  echo "  max_interval <seconds> - Set maximum interval"
  echo "  url <url> - Set target URL"
  echo "  delay <milliseconds> - Set airplane mode delay"
  echo "Examples:"
  echo "  $0 iterations 200"
  echo "  $0 min_interval 30"
  exit 1
fi

setting="$1"
value="$2"

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
    echo "Unknown setting: $setting"
    exit 1
    ;;
esac

# Restart the activity to refresh the UI
restart_activity
