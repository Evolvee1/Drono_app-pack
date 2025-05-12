#!/bin/bash
# Set and Restart Script for Drono App
# Changes settings and does a hard restart of the app to guarantee UI updates

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
  result=$(adb shell "am broadcast -a $BROADCAST_ACTION -e command '$command' $params -p $PACKAGE")
  
  # Check for success
  if [[ "$result" == *"result=0"* ]]; then
    echo "✅ Setting updated successfully"
    return 0
  else
    echo "❌ Failed to update setting: $result"
    return 1
  fi
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

# First stop any running simulation
echo "Stopping any active simulation..."
send_broadcast "stop" ""
sleep 2

# Process all setting-value pairs provided
arg_count=$#
i=1
changes=()

echo "Updating settings..."
while [ $i -le $((arg_count-1)) ]; do
  setting="${!i}"
  i=$((i+1))
  value="${!i}"
  i=$((i+1))
  
  # Store changes for summary
  changes+=("$setting=$value")
  
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

# Print summary of changes
echo "===================================================="
echo "✅ Settings updated with these changes:"
for change in "${changes[@]}"; do
  echo "  👉 $change"
done
echo "===================================================="

# This is the most reliable way to make UI updates appear:
# 1. Force stop the app
echo "Restarting app to refresh UI..."
adb shell "am force-stop $PACKAGE"
sleep 1.5

# 2. Start it again fresh
adb shell "am start -n $PACKAGE/$ACTIVITY"
sleep 2
echo "App restarted with new settings!"

# 3. Offer to start a simulation
echo ""
echo "Do you want to start a new simulation with these settings? (y/n)"
read -p "> " start_choice

if [[ "$start_choice" == "y" || "$start_choice" == "Y" ]]; then
  echo "Starting simulation..."
  send_broadcast "start" ""
  echo "✅ Simulation started with new settings!"
else
  echo "Settings have been applied. Start the simulation manually when ready."
fi 