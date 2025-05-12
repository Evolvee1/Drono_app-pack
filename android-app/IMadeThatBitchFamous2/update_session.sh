#!/bin/bash
# Session Update Script for Drono App
# Changes settings and restarts just the simulation session (not the entire app)

# Define package and activity names
PACKAGE="com.example.imtbf2.debug"
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
  
  # Check for success
  if [[ "$result" == *"result=0"* ]]; then
    echo "✅ Command succeeded"
    return 0
  else
    echo "❌ Command failed: $result"
    return 1
  fi
}

# Main script logic for changing a single setting
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

# Function to restart the simulation session
restart_session() {
  echo "Restarting simulation session..."
  
  # First stop any running simulation
  send_broadcast "stop" ""
  sleep 2
  
  # Then start a new simulation
  send_broadcast "start" ""
  sleep 1
  
  echo "Session restarted! New settings should now be in effect."
}

# Main script execution
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

echo "Starting settings update..."

while [ $i -le $((arg_count-1)) ]; do
  setting="${!i}"
  i=$((i+1))
  value="${!i}"
  i=$((i+1))
  
  # Change the setting
  if change_setting "$setting" "$value"; then
    success_count=$((success_count+1))
  fi
done

echo "Settings update completed. $success_count out of $((arg_count/2)) settings changed."

# Ask user if they want to restart the session
echo ""
echo "Do you want to restart the simulation session to apply these changes? (y/n)"
read -p "> " restart_choice

if [[ "$restart_choice" == "y" || "$restart_choice" == "Y" ]]; then
  restart_session
else
  echo "Session not restarted. Changes will apply to the next simulation or when you manually restart."
fi 