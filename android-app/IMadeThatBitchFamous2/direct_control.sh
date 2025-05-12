#!/bin/bash
# Direct Control Script for Drono App
# This script uses direct ADB commands to control the app

# Define app package name for debug build
PACKAGE="com.example.imtbf2.debug"
# Define activity name
MAIN_ACTIVITY="com.example.imtbf2.presentation.activities.MainActivity"
# Define action for remote command intent
ACTION="com.example.imtbf2.REMOTE_COMMAND"

# Function to directly trigger MainActivity commands using startActivity
send_activity_command() {
  echo "Sending direct activity command: $1"
  adb shell am start -n $PACKAGE/$MAIN_ACTIVITY -a $ACTION --es command "$1"
  sleep 2
}

# Function to update a preference setting
update_preference() {
  echo "Updating preference: $1 with value: $2 (type: $3)"
  if [ "$3" = "string" ]; then
    adb shell "run-as $PACKAGE sh -c 'echo -n \"$2\" > /data/data/$PACKAGE/shared_prefs/preference_value'"
    adb shell "run-as $PACKAGE sh -c 'sqlite3 /data/data/$PACKAGE/databases/app_preferences.db \"UPDATE preferences SET string_value=\\\"$2\\\" WHERE key=\\\"$1\\\"\"'"
  elif [ "$3" = "int" ]; then
    adb shell "run-as $PACKAGE sh -c 'sqlite3 /data/data/$PACKAGE/databases/app_preferences.db \"UPDATE preferences SET int_value=$2 WHERE key=\\\"$1\\\"\"'"
  elif [ "$3" = "boolean" ]; then
    if [ "$2" = "true" ]; then
      value=1
    else
      value=0
    fi
    adb shell "run-as $PACKAGE sh -c 'sqlite3 /data/data/$PACKAGE/databases/app_preferences.db \"UPDATE preferences SET boolean_value=$value WHERE key=\\\"$1\\\"\"'"
  fi
  sleep 1
}

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Print help menu
help() {
  echo "Drono App Direct Control"
  echo "------------------------"
  echo "Usage: ./direct_control.sh [command]"
  echo ""
  echo "Available commands:"
  echo "  start             - Start simulation"
  echo "  pause             - Pause simulation"
  echo "  resume            - Resume simulation"
  echo "  stop              - Stop simulation"
  echo "  url [url]         - Set target URL"
  echo "  iterations [n]    - Set number of iterations"
  echo "  min_int [n]       - Set minimum interval (seconds)"
  echo "  max_int [n]       - Set maximum interval (seconds)"
  echo "  delay [n]         - Set airplane mode delay (milliseconds)"
  echo "  rotate_ip [true/false] - Toggle IP rotation"
  echo "  webview [true/false]   - Toggle WebView mode"
  echo "  random [true/false]    - Toggle random device profiles"
  echo ""
  echo "Examples:"
  echo "  ./direct_control.sh start"
  echo "  ./direct_control.sh url https://example.com"
  echo "  ./direct_control.sh iterations 100"
  echo "  ./direct_control.sh webview true"
}

# Process command line arguments
case "$1" in
  "start")
    send_activity_command "start"
    ;;
  "pause")
    send_activity_command "pause"
    ;;
  "resume")
    send_activity_command "resume"
    ;;
  "stop")
    send_activity_command "stop"
    ;;
  "url")
    if [ -z "$2" ]; then
      echo "Error: URL required"
      exit 1
    fi
    update_preference "target_url" "$2" "string"
    echo "Target URL set to: $2"
    ;;
  "iterations")
    if [ -z "$2" ]; then
      echo "Error: Iteration count required"
      exit 1
    fi
    update_preference "iterations" "$2" "int"
    echo "Iterations set to: $2"
    ;;
  "min_int")
    if [ -z "$2" ]; then
      echo "Error: Value required"
      exit 1
    fi
    update_preference "min_interval" "$2" "int"
    echo "Min interval set to: $2"
    ;;
  "max_int")
    if [ -z "$2" ]; then
      echo "Error: Value required"
      exit 1
    fi
    update_preference "max_interval" "$2" "int"
    echo "Max interval set to: $2"
    ;;
  "delay")
    if [ -z "$2" ]; then
      echo "Error: Value required"
      exit 1
    fi
    update_preference "airplane_mode_delay" "$2" "int"
    echo "Airplane mode delay set to: $2"
    ;;
  "rotate_ip")
    if [ -z "$2" ]; then
      echo "Error: Value (true/false) required"
      exit 1
    fi
    update_preference "rotate_ip" "$2" "boolean"
    echo "IP rotation set to: $2"
    ;;
  "webview")
    if [ -z "$2" ]; then
      echo "Error: Value (true/false) required"
      exit 1
    fi
    update_preference "use_webview_mode" "$2" "boolean"
    echo "WebView mode set to: $2"
    ;;
  "random")
    if [ -z "$2" ]; then
      echo "Error: Value (true/false) required"
      exit 1
    fi
    update_preference "use_random_device_profile" "$2" "boolean"
    echo "Random device profiles set to: $2"
    ;;
  *)
    help
    ;;
esac 