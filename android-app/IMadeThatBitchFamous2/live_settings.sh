#!/bin/bash
# Live Settings Change Script for Drono App
# Changes settings without restarting the app

# Define package and activity names
PACKAGE="com.example.imtbf2.debug"
ACTIVITY="com.example.imtbf2.presentation.activities.MainActivity"
BROADCAST_ACTION="com.example.imtbf2.debug.COMMAND"

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to send broadcast command with feedback
send_broadcast() {
  local command="$1"
  local params="$2"
  echo "Setting $command to $params"
  result=$(adb shell "am broadcast -a $BROADCAST_ACTION -e command '$command' $params -p $PACKAGE")
  echo "$result"
  
  # Extract success or failure message
  if [[ "$result" == *"result=0"* ]]; then
    echo "✅ Command succeeded" 
  else
    echo "❌ Command failed"
  fi
  sleep 1
}

# Function to simulate a touch event at a specific screen location
touch_screen() {
  local x="$1"
  local y="$2"
  echo "Sending touch at ($x,$y)"
  adb shell "input tap $x $y"
  sleep 0.5
}

# Function to try to save settings without restarting
save_settings() {
  echo "Attempting to save settings by simulating UI interaction..."
  
  # First, ensure the app is in foreground
  adb shell "am start -n $PACKAGE/$ACTIVITY"
  sleep 1
  
  # Send a key event to close keyboard if it's open
  adb shell "input keyevent 111" # KEYCODE_ESCAPE
  sleep 0.5
  
  # Simulate clicking the "Save" button (approximate coordinates)
  # This is a guess based on common app layouts - may need adjustment
  touch_screen 950 1800
  
  echo "Settings should now be updated in the app"
}

# Main script logic for single setting change
change_setting() {
  local setting="$1"
  local value="$2"

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
      return 1
      ;;
  esac
  
  return 0
}

# Main script execution
if [ $# -lt 2 ]; then
  echo "Usage: $0 <setting> <value> [<setting2> <value2> ...]"
  echo "Available settings:"
  echo "  iterations <number> - Set the number of iterations"
  echo "  min_interval <seconds> - Set minimum interval"
  echo "  max_interval <seconds> - Set maximum interval"
  echo "  url <url> - Set target URL"
  echo "  delay <milliseconds> - Set airplane mode delay"
  echo "Examples:"
  echo "  $0 iterations 200"
  echo "  $0 min_interval 30 max_interval 60"
  exit 1
fi

# Process all setting-value pairs provided
arg_count=$#
i=1

while [ $i -lt $arg_count ]; do
  setting="${!i}"
  i=$((i+1))
  value="${!i}"
  i=$((i+1))
  
  # Change the setting
  change_setting "$setting" "$value"
done

# Try to apply changes without restarting
save_settings 