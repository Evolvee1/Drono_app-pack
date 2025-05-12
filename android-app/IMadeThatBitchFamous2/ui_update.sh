#!/bin/bash
# UI Update Script for Drono App
# Changes settings and refreshes the UI without restarting the whole app

# Define package and activity names
PACKAGE="com.example.imtbf2.debug"
ACTIVITY="com.example.imtbf2.presentation.activities.MainActivity"
BROADCAST_ACTION="com.example.imtbf2.debug.COMMAND" 
REMOTE_COMMAND_ACTION="com.example.imtbf2.REMOTE_COMMAND"

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

# Function to send a command directly to MainActivity (bypassing the broadcast receiver)
send_direct_command() {
  local command="$1"
  echo "Sending direct command: $command"
  adb shell "am start -n $PACKAGE/$ACTIVITY -a $REMOTE_COMMAND_ACTION --es command '$command' --activity-single-top"
  sleep 1
}

# Function to send a custom intent to reload the UI safely
reload_ui() {
  echo "Triggering UI refresh..."
  
  # Focus the app first
  adb shell "am start -n $PACKAGE/$ACTIVITY"
  sleep 0.5
  
  # Use keyevent to simulate tapping in the app (should trigger onResume which refreshes the UI)
  adb shell "input keyevent KEYCODE_DPAD_CENTER"
  sleep 0.5
  
  # Force an activity restart in way that preserves state
  # This is done by sending it to background and back to foreground
  echo "Moving app to background and back to refresh UI..."
  adb shell "input keyevent KEYCODE_HOME"
  sleep 1
  adb shell "am start -n $PACKAGE/$ACTIVITY"
  sleep 2
  
  echo "✅ UI refresh completed"
}

# Main script logic
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

# Process all setting-value pairs provided
arg_count=$#
i=1
success_count=0
changes=()

echo "Updating settings..."

# If a simulation is running, pause it first
was_running=false
adb shell "dumpsys activity services | grep 'app=ProcessRecord.*$PACKAGE.*SessionManager'" > /dev/null
if [ $? -eq 0 ]; then
  echo "Simulation appears to be running, pausing temporarily..."
  was_running=true
  send_direct_command "pause"
  sleep 2
fi

# Make all the setting changes
while [ $i -le $((arg_count-1)) ]; do
  setting="${!i}"
  i=$((i+1))
  value="${!i}"
  i=$((i+1))
  
  # Store for later summary
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
  
  if [ $? -eq 0 ]; then
    success_count=$((success_count+1))
  fi
done

# Print summary of changes
echo "===================================================="
echo "✅ Settings updated with these changes:"
for change in "${changes[@]}"; do
  echo "  👉 $change"
done
echo "===================================================="

# Trigger UI refresh
reload_ui

# Resume the simulation if it was running
if $was_running; then
  echo "Resuming simulation..."
  send_direct_command "resume"
fi

echo "All operations completed! UI should now display the updated settings." 