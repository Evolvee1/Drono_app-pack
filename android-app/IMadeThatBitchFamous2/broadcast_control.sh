#!/bin/bash
# Broadcast Control Script for Drono App
# This script uses broadcast commands that work even when the app is minimized

# Define app package name for debug build
PACKAGE="com.example.imtbf2.debug"
# Define broadcast action for commands
ACTION="com.example.imtbf2.debug.COMMAND"

# Function to send broadcast command
send_broadcast() {
  echo "Sending broadcast command: $1"
  adb shell am broadcast -a $ACTION --es command "$1"
  sleep 1
}

# Function to send broadcast command with additional parameters
send_broadcast_with_params() {
  local command=$1
  shift
  echo "Sending broadcast command: $command with parameters: $@"
  adb shell am broadcast -a $ACTION --es command "$command" $@
  sleep 1
}

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to show help
show_help() {
  echo "Drono App Broadcast Control"
  echo "---------------------------"
  echo "Usage: ./broadcast_control.sh <command> [options]"
  echo ""
  echo "Basic Commands:"
  echo "  start               - Start simulation"
  echo "  pause               - Pause simulation"
  echo "  resume              - Resume simulation"
  echo "  stop                - Stop simulation"
  echo "  status              - Show current status"
  echo ""
  echo "Configuration Commands:"
  echo "  set_url <url>       - Set target URL"
  echo "  set_iterations <n>  - Set number of iterations"
  echo "  set_min_interval <n> - Set minimum interval (seconds)"
  echo "  set_max_interval <n> - Set maximum interval (seconds)"
  echo "  set_delay <n>       - Set airplane mode delay (milliseconds)"
  echo "  toggle <feature> <true|false> - Toggle feature on/off"
  echo "  list_configs        - List available configurations"
  echo ""
  echo "Available features to toggle:"
  echo "  rotate_ip           - IP rotation"
  echo "  webview_mode        - WebView mode"
  echo "  random_devices      - Random device profiles"
  echo "  aggressive_clearing - Aggressive session clearing"
  echo "  new_webview_per_request - New WebView per request"
  echo "  handle_redirects    - Handle marketing redirects"
  echo ""
  echo "Examples:"
  echo "  ./broadcast_control.sh start"
  echo "  ./broadcast_control.sh pause"
  echo "  ./broadcast_control.sh set_url https://example.com"
  echo "  ./broadcast_control.sh toggle webview_mode true"
}

# Main command processing
case "$1" in
  "start")
    send_broadcast "start"
    ;;
  "pause")
    send_broadcast "pause"
    ;;
  "resume")
    send_broadcast "resume"
    ;;
  "stop")
    send_broadcast "stop"
    ;;
  "status")
    send_broadcast "get_status"
    ;;
  "set_url")
    if [ -z "$2" ]; then
      echo "Error: URL required"
      exit 1
    fi
    send_broadcast_with_params "set_url" "--es value '$2'"
    ;;
  "set_iterations")
    if [ -z "$2" ]; then
      echo "Error: Number required"
      exit 1
    fi
    send_broadcast_with_params "set_iterations" "--ei value $2"
    ;;
  "set_min_interval")
    if [ -z "$2" ]; then
      echo "Error: Number required"
      exit 1
    fi
    send_broadcast_with_params "set_min_interval" "--ei value $2"
    ;;
  "set_max_interval")
    if [ -z "$2" ]; then
      echo "Error: Number required"
      exit 1
    fi
    send_broadcast_with_params "set_max_interval" "--ei value $2"
    ;;
  "set_delay")
    if [ -z "$2" ]; then
      echo "Error: Number required"
      exit 1
    fi
    send_broadcast_with_params "set_airplane_delay" "--ei value $2"
    ;;
  "toggle")
    if [ -z "$2" ]; then
      echo "Error: Feature name required"
      exit 1
    fi
    if [ -z "$3" ]; then
      echo "Error: Value (true/false) required"
      exit 1
    fi
    send_broadcast_with_params "toggle_feature" "--es feature $2 --ez value $3"
    ;;
  "list_configs")
    send_broadcast "list_configs"
    ;;
  *)
    show_help
    ;;
esac 