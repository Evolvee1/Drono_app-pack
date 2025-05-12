#!/bin/bash
# ADB Control Script for Drono App
# This script demonstrates how to remotely control the app using ADB commands

# Define app package name for debug build
PACKAGE="com.example.imtbf2.debug"
# Define broadcast action for commands
ACTION="com.example.imtbf2.debug.COMMAND"

# Function to send a command to the app
send_command() {
  echo "Sending command: $1 $2 $3 $4 $5"
  adb shell am broadcast -a $ACTION --es command "$1" $2 $3 $4 $5
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
  echo "Drono App Remote Control"
  echo "------------------------"
  echo "Usage: ./adb_control.sh [command]"
  echo ""
  echo "Available commands:"
  echo "  status            - Get app status"
  echo "  start             - Start simulation"
  echo "  pause             - Pause simulation"
  echo "  resume            - Resume simulation"
  echo "  stop              - Stop simulation"
  echo "  set_url [url]     - Set target URL"
  echo "  set_iterations [n]- Set number of iterations"
  echo "  set_min_int [n]   - Set minimum interval (seconds)"
  echo "  set_max_int [n]   - Set maximum interval (seconds)"
  echo "  set_delay [n]     - Set airplane mode delay (milliseconds)"
  echo "  toggle [feature] [true/false] - Toggle a feature on/off"
  echo "  list_configs      - List saved configurations"
  echo "  export [name] [desc] - Export configuration"
  echo "  import [name]     - Import configuration"
  echo ""
  echo "Examples:"
  echo "  ./adb_control.sh start"
  echo "  ./adb_control.sh set_url \"https://example.com\""
  echo "  ./adb_control.sh set_iterations 100"
  echo "  ./adb_control.sh toggle rotate_ip true"
  echo ""
  echo "Available features for toggle:"
  echo "  rotate_ip, random_devices, webview_mode, aggressive_clearing"
  echo "  new_webview_per_request, handle_redirects"
}

# Process command line arguments
case "$1" in
  "status")
    send_command "get_status"
    ;;
  "start")
    send_command "start"
    ;;
  "pause")
    send_command "pause"
    ;;
  "resume")
    send_command "resume"
    ;;
  "stop")
    send_command "stop"
    ;;
  "set_url")
    if [ -z "$2" ]; then
      echo "Error: URL required"
      exit 1
    fi
    send_command "set_url" "--es value \"$2\""
    ;;
  "set_iterations")
    if [ -z "$2" ]; then
      echo "Error: Iteration count required"
      exit 1
    fi
    send_command "set_iterations" "--ei value $2"
    ;;
  "set_min_int")
    if [ -z "$2" ]; then
      echo "Error: Value required"
      exit 1
    fi
    send_command "set_min_interval" "--ei value $2"
    ;;
  "set_max_int")
    if [ -z "$2" ]; then
      echo "Error: Value required"
      exit 1
    fi
    send_command "set_max_interval" "--ei value $2"
    ;;
  "set_delay")
    if [ -z "$2" ]; then
      echo "Error: Value required"
      exit 1
    fi
    send_command "set_airplane_delay" "--ei value $2"
    ;;
  "toggle")
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "Error: Feature name and value (true/false) required"
      exit 1
    fi
    send_command "toggle_feature" "--es feature \"$2\"" "--ez value $3"
    ;;
  "list_configs")
    send_command "list_configs"
    ;;
  "export")
    if [ -z "$2" ]; then
      echo "Error: Configuration name required"
      exit 1
    fi
    if [ -z "$3" ]; then
      send_command "export_config" "--es name \"$2\""
    else
      send_command "export_config" "--es name \"$2\"" "--es desc \"$3\""
    fi
    ;;
  "import")
    if [ -z "$2" ]; then
      echo "Error: Configuration name required"
      exit 1
    fi
    send_command "import_config" "--es name \"$2\""
    ;;
  *)
    help
    ;;
esac 