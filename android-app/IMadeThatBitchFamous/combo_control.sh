#!/bin/bash
# Combination Control Script for Drono App
# This script allows multiple operations in sequence

# Define app package name for debug build
PACKAGE="com.example.imtbf.debug"
# Define main activity
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
# Define action for commands
ACTION="com.example.imtbf.REMOTE_COMMAND"
# Define broadcast action
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"

# Function to focus the app window
focus_app() {
  echo "Focusing app window..."
  adb shell "input keyevent KEYCODE_WAKEUP"
  sleep 0.5
  adb shell "am start -n $PACKAGE/$ACTIVITY"
  sleep 2
}

# Function to send direct command to activity
send_activity_command() {
  local cmd="$1"
  echo "Sending activity command: $cmd"
  adb shell "am start -n $PACKAGE/$ACTIVITY -a $ACTION --es command '$cmd' --activity-single-top"
  sleep 2
}

# Function to send broadcast command
send_broadcast_command() {
  local cmd="$1"
  local extra_params="$2"
  echo "Sending broadcast command: $cmd $extra_params"
  
  if [ -z "$extra_params" ]; then
    adb shell "am broadcast -a $BROADCAST_ACTION -p $PACKAGE -e command '$cmd'"
  else
    adb shell "am broadcast -a $BROADCAST_ACTION -p $PACKAGE -e command '$cmd' $extra_params"
  fi
  
  sleep 1
}

# Function to handle configuration
configure_app() {
  local param="$1"
  local value="$2"
  local type="$3"
  
  echo "Configuring: $param = $value"
  
  case "$type" in
    "string")
      send_broadcast_command "$param" "-e value '$value'"
      ;;
    "int")
      send_broadcast_command "$param" "-e value $value"
      ;;
    "bool")
      send_broadcast_command "toggle_feature" "-e feature $param -e value $value"
      ;;
    *)
      echo "Unknown type: $type"
      ;;
  esac
}

# Run a preset configuration
run_preset() {
  local preset="$1"
  echo "Running preset: $preset"
  
  case "$preset" in
    "performance")
      configure_app "set_url" "https://instagram.com" "string"
      configure_app "set_iterations" "50" "int"
      configure_app "set_min_interval" "3" "int"
      configure_app "set_max_interval" "10" "int"
      configure_app "set_airplane_delay" "3000" "int"
      configure_app "rotate_ip" "true" "bool"
      configure_app "random_devices" "true" "bool"
      configure_app "webview_mode" "false" "bool"
      ;;
    "stealth")
      configure_app "set_url" "https://instagram.com" "string"
      configure_app "set_iterations" "30" "int"
      configure_app "set_min_interval" "10" "int"
      configure_app "set_max_interval" "20" "int"
      configure_app "set_airplane_delay" "5000" "int"
      configure_app "rotate_ip" "true" "bool"
      configure_app "random_devices" "true" "bool"
      configure_app "webview_mode" "true" "bool"
      configure_app "aggressive_clearing" "true" "bool"
      ;;
    "balanced")
      configure_app "set_url" "https://instagram.com" "string"
      configure_app "set_iterations" "40" "int"
      configure_app "set_min_interval" "5" "int"
      configure_app "set_max_interval" "15" "int"
      configure_app "set_airplane_delay" "4000" "int"
      configure_app "rotate_ip" "true" "bool"
      configure_app "random_devices" "true" "bool"
      configure_app "webview_mode" "true" "bool"
      ;;
    *)
      echo "Unknown preset: $preset"
      return 1
      ;;
  esac
  
  echo "Preset configuration applied"
  return 0
}

# Execute a sequence of operations
run_sequence() {
  echo "Running sequence: $*"
  
  # First ensure app is focused
  focus_app
  
  # Process each argument in sequence
  for arg in "$@"; do
    case "$arg" in
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
      "performance"|"stealth"|"balanced")
        run_preset "$arg"
        ;;
      *)
        if [[ "$arg" == *"="* ]]; then
          # Handle key=value configuration
          local key="${arg%%=*}"
          local value="${arg#*=}"
          
          case "$key" in
            "url")
              configure_app "set_url" "$value" "string"
              ;;
            "iterations")
              configure_app "set_iterations" "$value" "int"
              ;;
            "min_interval")
              configure_app "set_min_interval" "$value" "int"
              ;;
            "max_interval")
              configure_app "set_max_interval" "$value" "int"
              ;;
            "delay")
              configure_app "set_airplane_delay" "$value" "int"
              ;;
            "rotate_ip"|"webview_mode"|"random_devices"|"aggressive_clearing")
              configure_app "$key" "$value" "bool"
              ;;
            *)
              echo "Unknown configuration key: $key"
              ;;
          esac
        else
          echo "Unknown argument: $arg"
        fi
        ;;
    esac
    
    # Short delay between operations
    sleep 1
  done
  
  echo "Sequence completed"
}

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to show help
show_help() {
  echo "Drono App Combo Control"
  echo "-----------------------"
  echo "Usage: ./combo_control.sh command1 [command2] [command3] ..."
  echo ""
  echo "Commands:"
  echo "  start             - Start simulation"
  echo "  pause             - Pause simulation"
  echo "  resume            - Resume simulation"
  echo "  stop              - Stop simulation"
  echo ""
  echo "Presets:"
  echo "  performance       - High iteration count, short intervals"
  echo "  stealth           - Lower iteration count, longer intervals"
  echo "  balanced          - Balanced configuration"
  echo ""
  echo "Individual Settings (key=value):"
  echo "  url=<url>         - Set target URL"
  echo "  iterations=<n>    - Set number of iterations"
  echo "  min_interval=<n>  - Set minimum interval (seconds)"
  echo "  max_interval=<n>  - Set maximum interval (seconds)"
  echo "  delay=<n>         - Set airplane mode delay (milliseconds)"
  echo "  rotate_ip=true|false    - Enable/disable IP rotation"
  echo "  webview_mode=true|false - Enable/disable WebView mode"
  echo "  random_devices=true|false - Enable/disable random device profiles"
  echo ""
  echo "Examples:"
  echo "  ./combo_control.sh performance start"
  echo "  ./combo_control.sh url=https://example.com iterations=50 start"
  echo "  ./combo_control.sh stealth start pause resume"
}

# Main command processing
if [ $# -eq 0 ]; then
  show_help
else
  run_sequence "$@"
fi 