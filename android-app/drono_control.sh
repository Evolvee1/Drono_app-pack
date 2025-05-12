#!/bin/bash
# Drono Master Control Script
# A comprehensive script to reliably change settings and control the Drono app

# --- PATCH: Require ADB_DEVICE_ID ---
if [ -z "$ADB_DEVICE_ID" ]; then
  echo "Error: ADB_DEVICE_ID is not set. Refusing to run without explicit device."
  exit 1
fi

# Define app package name for debug build
PACKAGE="com.example.imtbf.debug"
# Define main activity
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
# Define broadcast action
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"
# Define preferences file
PREFS_FILE="/data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml"

# Check if ADB is available
adb -s "$ADB_DEVICE_ID" devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Check if at least one device is connected
if ! adb -s "$ADB_DEVICE_ID" devices | grep -q "device$"; then
  echo "Error: No device connected or device not authorized"
  echo "Please connect a device and ensure USB debugging is enabled"
  exit 1
fi

# ------------------------------------------------------
# DIRECT PREFERENCES EDITOR
# The most reliable way to change settings
# ------------------------------------------------------

# Function to check if we can access the file via root or run-as
check_file_access() {
  # Try via root first
  adb -s "$ADB_DEVICE_ID" shell "su -c 'ls $PREFS_FILE'" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ Can access file with root. Using su method."
    USE_RUNAS=0
    return 0
  fi
  
  # Try via run-as as fallback (for debug builds)
  adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE ls /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ Can access file with run-as. Using run-as method."
    USE_RUNAS=1
    return 0
  fi
  
  echo "❌ Cannot access preferences file. No root or run-as access."
  return 1
}

# Function to update integer or boolean preference
update_preference() {
  local name=$1
  local value=$2
  local type=$3
  echo "Updating $name to $value..."
  
  # If in dry run mode, just return
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would set $name to $value"
    return 0
  fi
  
  # Create exact pattern match for the sed command
  if [ $USE_RUNAS -eq 1 ]; then
    # Use run-as for debug builds
    adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep -q \"<$type name=\\\"$name\\\"\"" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE sed -i \"s|<$type name=\\\"$name\\\" value=\\\"[^\\\"]*\\\"|<$type name=\\\"$name\\\" value=\\\"$value\\\"|g\" $PREFS_FILE"
    else
      echo "Warning: Could not find $name in preferences file. Entry might be missing."
    fi
  else
    # Use su for rooted devices
    # Use more direct approach with exact pattern matching
    adb -s "$ADB_DEVICE_ID" shell "su -c 'sed -i \"s|<$type name=\\\"$name\\\" value=\\\"[^\\\"]*\\\"|<$type name=\\\"$name\\\" value=\\\"$value\\\"|g\" $PREFS_FILE'"
  fi
  
  # Verify the change was made
  if [ $USE_RUNAS -eq 1 ]; then
    local current_value=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep \"<$type name=\\\"$name\\\"\"" | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
  else
    local current_value=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE | grep \"<$type name=\\\"$name\\\"\"'" | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
  fi
  
  if [ "$current_value" = "$value" ]; then
    echo "✅ Verified: $name is now set to $value"
  else
    echo "⚠️ Warning: $name appears to be set to $current_value instead of $value"
  fi
}

# Function to update string preference
update_string_preference() {
  local name=$1
  local value=$2
  echo "Updating $name to $value..."
  
  # If in dry run mode, just return
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would set $name to $value"
    return 0
  fi
  
  # Escape special characters for sed
  local escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
  
  if [ $USE_RUNAS -eq 1 ]; then
    # Use run-as for debug builds
    adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep -q \"<string name=\\\"$name\\\"\"" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE sed -i \"s|<string name=\\\"$name\\\">[^<]*</string>|<string name=\\\"$name\\\">$escaped_value</string>|g\" $PREFS_FILE"
    else
      echo "Warning: Could not find $name in preferences file. Entry might be missing."
    fi
  else
    # Use su for rooted devices - direct approach with exact pattern matching
    adb -s "$ADB_DEVICE_ID" shell "su -c 'sed -i \"s|<string name=\\\"$name\\\">[^<]*</string>|<string name=\\\"$name\\\">$escaped_value</string>|g\" $PREFS_FILE'"
  fi
  
  # Verify the change was made
  if [ $USE_RUNAS -eq 1 ]; then
    local current_value=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep \"<string name=\\\"$name\\\"\"" | sed "s/.*<string name=\\\"$name\\\">\(.*\)<\/string>.*/\1/")
  else
    local current_value=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE | grep \"<string name=\\\"$name\\\"\"'" | sed "s/.*<string name=\\\"$name\\\">\(.*\)<\/string>.*/\1/")
  fi
  
  if [ "$current_value" = "$escaped_value" ]; then
    echo "✅ Verified: $name is now set to $value"
  else
    echo "⚠️ Warning: $name appears to be set to $current_value instead of $value"
  fi
}

# ------------------------------------------------------
# BROADCAST COMMANDS
# For actions that don't change settings
# ------------------------------------------------------

# Function to send broadcast command
send_broadcast() {
  local command="$1"
  local params="$2"
  echo "Sending broadcast: $command $params"
  adb -s "$ADB_DEVICE_ID" shell "am broadcast -a $BROADCAST_ACTION --es command '$command' $params -p $PACKAGE"
  sleep 0.5
}

# Function to send broadcast with integer value
send_int_broadcast() {
  local command="$1"
  local value="$2"
  echo "Setting $command to $value"
  adb -s "$ADB_DEVICE_ID" shell "am broadcast -a $BROADCAST_ACTION --es command '$command' --ei value $value -p $PACKAGE"
  sleep 0.5
}

# Function to send broadcast with string value
send_string_broadcast() {
  local command="$1"
  local value="$2"
  echo "Setting $command to $value"
  adb -s "$ADB_DEVICE_ID" shell "am broadcast -a $BROADCAST_ACTION --es command '$command' --es value \"$value\" -p $PACKAGE"
  sleep 0.5
}

# Function to send command via activity
send_activity_command() {
  local cmd="$1"
  echo "Sending activity command: $cmd"
  
  # If in dry run mode, just return
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would send activity command: $cmd"
    return 0
  fi
  
  # For restore_session we need a special command handler
  if [ "$cmd" = "restore_session" ]; then
    # First check if the app is fully started
    if ! is_app_running; then
      echo "App is not running, starting it first..."
      adb -s "$ADB_DEVICE_ID" shell am start -n $PACKAGE/$ACTIVITY
      wait_for_app 10 false  # Don't auto dismiss when we want to restore
    fi
    
    # Special handler for restore command since it's not directly supported via intent
    # We could create a broadcast handler for this, but for now we'll use the file method
    if check_file_access; then
      # Check if a saved session exists
      if [ $USE_RUNAS -eq 1 ]; then
        local has_session=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep -c session_current_index" 2>/dev/null || echo 0)
      else
        local has_session=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE | grep -c session_current_index'" 2>/dev/null || echo 0)
      fi
      
      if [ "$has_session" -gt 0 ]; then
        # Verify the intent handler handles session restoration
        # For now, we'll use a broadcast with a special command
        send_broadcast "restore_session" ""
        echo "Restore session broadcast sent"
        sleep 1
        
        # Also send a focus intent to ensure the dialog is shown/handled
        adb -s "$ADB_DEVICE_ID" shell am start -n $PACKAGE/$ACTIVITY --activity-single-top
      else
        echo "No saved session data found to restore."
      fi
    else
      # Fallback to direct activity start with a special parameter
      adb -s "$ADB_DEVICE_ID" shell am start -n $PACKAGE/$ACTIVITY -a com.example.imtbf.REMOTE_COMMAND --es command "restore_session" --activity-single-top
    fi
  else
    # Normal command via activity intent
    adb -s "$ADB_DEVICE_ID" shell am start -n $PACKAGE/$ACTIVITY -a com.example.imtbf.REMOTE_COMMAND --es command "$cmd" --activity-single-top
  fi
  
  sleep 1
}

# ------------------------------------------------------
# APP CONTROL
# Restart, force stop, launch, etc.
# ------------------------------------------------------

# Force stop the app
force_stop_app() {
  echo "Force stopping app..."
  
  # If in dry run mode, just return
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would force stop the app"
    return 0
  fi
  
  adb -s "$ADB_DEVICE_ID" shell am force-stop $PACKAGE
  sleep 1
}

# Check if app is running
is_app_running() {
  if adb -s "$ADB_DEVICE_ID" shell "pidof $PACKAGE" > /dev/null 2>&1; then
    return 0  # App is running
  else
    return 1  # App is not running
  fi
}

# Wait for app to be fully launched and responsive
wait_for_app() {
  local timeout=$1
  local auto_dismiss_restore=$2
  local interval=1
  local elapsed=0
  
  echo "Waiting for app to start..."
  
  while [ $elapsed -lt $timeout ]; do
    if is_app_running; then
      # App is running, now check if the activity is responsive
      if adb -s "$ADB_DEVICE_ID" shell "dumpsys activity activities | grep -q 'mResumedActivity.*$ACTIVITY'"; then
        echo "✅ App is running and activity is responsive"
        
        # If auto dismiss is enabled, check if we need to handle restore dialog
        if [ "$auto_dismiss_restore" = "true" ] && check_session_available >/dev/null 2>&1; then
          echo "Found saved session, auto-dismissing restore dialog..."
          clear_session_state
          # Give the app a moment to process
          sleep 1
        fi
        
        sleep 1  # Give it a little more time to fully initialize
        return 0
      fi
    fi
    
    sleep $interval
    elapsed=$((elapsed + interval))
    echo "  Still waiting... ($elapsed seconds)"
  done
  
  echo "⚠️ Timed out waiting for app to start"
  return 1
}

# Start the app
start_app() {
  echo "Starting app..."
  
  # If in dry run mode, just return
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would start the app"
    return 0
  fi
  
  adb -s "$ADB_DEVICE_ID" shell am start -n $PACKAGE/$ACTIVITY
  
  # Wait for app to be fully launched with auto-dismiss based on DISMISS_RESTORE_DIALOG
  wait_for_app 15 "$DISMISS_RESTORE_DIALOG"
}

# Restart the app (most reliable way to refresh UI)
restart_app() {
  force_stop_app
  start_app
}

# ------------------------------------------------------
# PRESETS
# Commonly used configurations
# ------------------------------------------------------

apply_preset() {
  local preset="$1"
  echo "Applying preset: $preset"
  
  # Check if we have access to the preferences file
  if ! check_file_access; then
    echo "Cannot apply preset without access to preferences file."
    return 1
  fi
  
  force_stop_app
  
  case "$preset" in
    "performance")
      update_string_preference "target_url" "https://instagram.com"
      update_preference "iterations" "50" "int"
      update_preference "min_interval" "3" "int"
      update_preference "max_interval" "10" "int"
      update_preference "airplane_mode_delay" "3000" "int"
      update_preference "rotate_ip" "true" "boolean"
      update_preference "use_random_device_profile" "true" "boolean"
      update_preference "use_webview_mode" "false" "boolean"
      ;;
    "stealth")
      update_string_preference "target_url" "https://instagram.com"
      update_preference "iterations" "30" "int"
      update_preference "min_interval" "10" "int"
      update_preference "max_interval" "20" "int"
      update_preference "airplane_mode_delay" "5000" "int"
      update_preference "rotate_ip" "true" "boolean"
      update_preference "use_random_device_profile" "true" "boolean"
      update_preference "use_webview_mode" "true" "boolean"
      update_preference "aggressive_session_clearing" "true" "boolean"
      ;;
    "balanced")
      update_string_preference "target_url" "https://instagram.com"
      update_preference "iterations" "40" "int"
      update_preference "min_interval" "5" "int"
      update_preference "max_interval" "15" "int"
      update_preference "airplane_mode_delay" "4000" "int"
      update_preference "rotate_ip" "true" "boolean"
      update_preference "use_random_device_profile" "true" "boolean"
      update_preference "use_webview_mode" "true" "boolean"
      ;;
    "veewoy")
      update_string_preference "target_url" "https://veewoy.com/ip-text"
      update_preference "iterations" "500" "int"
      update_preference "min_interval" "1" "int"
      update_preference "max_interval" "2" "int"
      update_preference "airplane_mode_delay" "3000" "int"
      update_preference "rotate_ip" "true" "boolean"
      update_preference "use_random_device_profile" "true" "boolean"
      update_preference "use_webview_mode" "true" "boolean"
      ;;
    *)
      echo "Unknown preset: $preset"
      return 1
      ;;
  esac
  
  # Fix permissions if needed
  if [ $USE_RUNAS -eq 0 ]; then
    echo "Fixing file permissions..."
    adb -s "$ADB_DEVICE_ID" shell "su -c 'chmod 660 $PREFS_FILE && chown $PACKAGE:$PACKAGE $PREFS_FILE'" || true
  fi
  
  start_app
  echo "Preset applied successfully"
}

# ------------------------------------------------------
# SIMULATION CONTROL
# Start, stop, pause, resume
# ------------------------------------------------------

# Start the simulation
start_simulation() {
  echo "Starting simulation..."
  
  # If in dry run mode, just return
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would start the simulation"
    return 0
  fi
  
  # First check if app is already running
  local is_running_already=false
  if is_app_running; then
    is_running_already=true
    echo "App is already running, checking if responsive..."
    
    # Check if activity is in foreground
    if ! adb -s "$ADB_DEVICE_ID" shell "dumpsys activity activities | grep -q 'mResumedActivity.*$ACTIVITY'"; then
      echo "App is running but activity may not be in foreground. Bringing it to front..."
      adb -s "$ADB_DEVICE_ID" shell am start -n $PACKAGE/$ACTIVITY --activity-single-top
      wait_for_app 10 "$DISMISS_RESTORE_DIALOG"
    elif [ "$DISMISS_RESTORE_DIALOG" = true ]; then
      # App is in foreground, but we need to check and dismiss restore dialog if needed
      if check_session_available >/dev/null 2>&1; then
        echo "Found saved session, dismissing restore dialog as requested..."
        clear_session_state
        sleep 1  # Give the app a moment to process
      fi
    fi
  else
    echo "App is not running, launching app..."
    start_app
  fi
  
  # Ensure we have file access for most reliable operation
  if check_file_access; then
    echo "Setting is_running preference to true..."
    update_preference "is_running" "true" "boolean"
    
    echo "Sending start command to app..."
    if [ "$is_running_already" = true ]; then
      # If already running, send the start command
      send_activity_command "start"
    else
      # Start app with direct command
      adb -s "$ADB_DEVICE_ID" shell am start -n $PACKAGE/$ACTIVITY -a com.example.imtbf.REMOTE_COMMAND --es command start
    fi
    
    # Verify simulation is running
    sleep 2
    local is_running=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep is_running | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
    if [ "$is_running" = "true" ]; then
      echo "✅ SUCCESS: Simulation started successfully"
    else
      echo "⚠️ WARNING: Simulation may not have started properly. Current is_running value: $is_running"
    fi
  else
    # Fallback to broadcast method
    echo "No direct file access, using broadcast method..."
    send_broadcast "start" ""
    echo "Start command sent, but cannot verify if simulation is running."
  fi
  
  echo "Simulation start sequence completed"
}

# Stop the simulation
stop_simulation() {
  echo "Stopping simulation..."
  send_activity_command "stop"
  echo "Simulation stopped"
}

# Pause the simulation
pause_simulation() {
  echo "Pausing simulation..."
  send_activity_command "pause"
  echo "Simulation paused"
}

# Resume the simulation
resume_simulation() {
  echo "Resuming simulation..."
  send_activity_command "resume"
  echo "Simulation resumed"
}

# ------------------------------------------------------
# INDIVIDUAL SETTINGS
# Functions to change specific settings
# ------------------------------------------------------

set_target_url() {
  local url="$1"
  echo "Setting target URL to: $url"
  
  if check_file_access; then
    update_string_preference "target_url" "$url"
  else
    send_string_broadcast "set_url" "$url"
    restart_app
  fi
}

set_iterations() {
  local value="$1"
  echo "Setting iterations to: $value"
  
  if check_file_access; then
    update_preference "iterations" "$value" "int"
  else
    send_int_broadcast "set_iterations" "$value"
    restart_app
  fi
}

set_min_interval() {
  local value="$1"
  echo "Setting minimum interval to: $value seconds"
  
  if check_file_access; then
    update_preference "min_interval" "$value" "int"
  else
    send_int_broadcast "set_min_interval" "$value"
    restart_app
  fi
}

set_max_interval() {
  local value="$1"
  echo "Setting maximum interval to: $value seconds"
  
  if check_file_access; then
    update_preference "max_interval" "$value" "int"
  else
    send_int_broadcast "set_max_interval" "$value"
    restart_app
  fi
}

set_airplane_delay() {
  local value="$1"
  echo "Setting airplane mode delay to: $value ms"
  
  if check_file_access; then
    update_preference "airplane_mode_delay" "$value" "int"
  else
    send_int_broadcast "set_airplane_delay" "$value"
    restart_app
  fi
}

toggle_feature() {
  local feature="$1"
  local value="$2"
  echo "Setting $feature to: $value"
  
  # Map feature name to preference name
  local pref_name
  case "$feature" in
    "rotate_ip") pref_name="rotate_ip" ;;
    "random_devices") pref_name="use_random_device_profile" ;;
    "webview_mode") pref_name="use_webview_mode" ;;
    "aggressive_clearing") pref_name="aggressive_session_clearing" ;;
    "new_webview_per_request") pref_name="new_webview_per_request" ;;
    "handle_redirects") pref_name="handle_marketing_redirects" ;;
    *) echo "Unknown feature: $feature"; return 1 ;;
  esac
  
  if check_file_access; then
    update_preference "$pref_name" "$value" "boolean"
  else
    send_broadcast "toggle_feature" "--es feature '$feature' --es value $value"
    restart_app
  fi
}

# ------------------------------------------------------
# STATUS FUNCTIONS
# View current settings and status
# ------------------------------------------------------

show_status() {
  echo "Checking app status..."
  
  # Check if app process is running
  if is_app_running; then
    echo "✅ App process is running"
    local app_pid=$(adb -s "$ADB_DEVICE_ID" shell "pidof $PACKAGE")
    echo "   Process ID: $app_pid"
    
    # Check if activity is in foreground
    if adb -s "$ADB_DEVICE_ID" shell "dumpsys activity activities | grep -q 'mResumedActivity.*$ACTIVITY'"; then
      echo "✅ App activity is in foreground"
    else
      echo "⚠️ App is running but activity may not be in foreground"
    fi
  else
    echo "❌ App process is NOT running"
  fi
  
  # Check for saved session
  if check_file_access; then
    # Check if a saved session exists
    if [ $USE_RUNAS -eq 1 ]; then
      local has_session=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep -c session_current_index" 2>/dev/null || echo 0)
    else
      local has_session=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE | grep -c session_current_index'" 2>/dev/null || echo 0)
    fi
    
    if [ "$has_session" -gt 0 ]; then
      echo "------------ SAVED SESSION ------------"
      echo "✅ Found saved session data available for restoration"
      
      if [ $USE_RUNAS -eq 1 ]; then
        local current_index=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep session_current_index" | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
        local total_requests=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep session_total_requests" | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
        local is_paused=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep session_is_paused" | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      else
        local current_index=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE | grep session_current_index'" | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
        local total_requests=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE | grep session_total_requests'" | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
        local is_paused=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE | grep session_is_paused'" | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      fi
      
      echo "Progress: $current_index/$total_requests"
      echo "Paused: $is_paused"
      echo "Commands: ./drono_control.sh restore_session   # To restore"
      echo "          ./drono_control.sh dismiss_restore   # To dismiss"
      echo "--------------------------------------"
    else
      echo "❌ No saved session data found"
    fi
  fi
  
  if check_file_access; then
    # Using direct preferences file access for the most accurate information
    if [ $USE_RUNAS -eq 1 ]; then
    local is_running=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep is_running | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
    local iterations=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep iterations | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
    local min_interval=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep min_interval | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
    local max_interval=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep max_interval | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
    local url=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep target_url | sed "s/.*>\(.*\)<\/string>.*/\1/")
    local rotate_ip=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep rotate_ip | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
    local airplane_delay=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep airplane_mode_delay | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
    local webview_mode=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep use_webview_mode | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
    local random_devices=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep use_random_device_profile | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      
      # Look for current iteration in UI state
      local current_iteration=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE" | grep current_iteration | sed "s/.*value=\"\([^\"]*\)\".*/\1/" 2>/dev/null || echo "0")
    else
      local is_running=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep is_running | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      local iterations=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep iterations | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      local min_interval=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep min_interval | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      local max_interval=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep max_interval | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      local url=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep target_url | sed "s/.*>\(.*\)<\/string>.*/\1/")
      local rotate_ip=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep rotate_ip | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      local airplane_delay=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep airplane_mode_delay | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      local webview_mode=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep use_webview_mode | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      local random_devices=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep use_random_device_profile | sed "s/.*value=\"\([^\"]*\)\".*/\1/")
      
      # Look for current iteration in UI state
      local current_iteration=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE'" | grep current_iteration | sed "s/.*value=\"\([^\"]*\)\".*/\1/" 2>/dev/null || echo "0")
    fi
    
    echo "------------ SIMULATION STATUS ------------"
    if [ "$is_running" = "true" ]; then
      echo "✅ SIMULATION IS RUNNING"
      
      # Get current progress from UI if available when running
      local log_progress=$(adb -s "$ADB_DEVICE_ID" shell "dumpsys activity top | grep tvProgress | grep -o 'Progress: [0-9]*/[0-9]*'" 2>/dev/null || echo "")
      if [ -n "$log_progress" ]; then
        echo "$log_progress"
        # Extract numbers for percentage calculation
        local current=$(echo "$log_progress" | awk -F'[/ ]' '{print $2}')
        local total=$(echo "$log_progress" | awk -F'[/ ]' '{print $3}')
        if [ -n "$current" ] && [ -n "$total" ] && [ "$total" -gt 0 ]; then
          local percentage=$((100 * current / total))
          echo "Completion: ${percentage}%"
          echo "Current Iteration: $current"
        fi
      elif [ "$current_iteration" != "0" ]; then
        # Use value from preferences if it exists
        echo "Progress: $current_iteration/$iterations"
        local percentage=$((100 * current_iteration / iterations))
        echo "Completion: ${percentage}%"
        echo "Current Iteration: $current_iteration"
      else
        # No progress data found, try to get from logcat
        local logcat_progress=$(adb logcat -d -t 20 -v brief | grep -o "Progress: [0-9]*/[0-9]*" | tail -1)
        if [ -n "$logcat_progress" ]; then
          echo "$logcat_progress"
          # Extract numbers for percentage calculation
          local current=$(echo "$logcat_progress" | awk -F'[/ ]' '{print $2}')
          local total=$(echo "$logcat_progress" | awk -F'[/ ]' '{print $3}')
          if [ -n "$current" ] && [ -n "$total" ] && [ "$total" -gt 0 ]; then
            local percentage=$((100 * current / total))
            echo "Completion: ${percentage}%"
            echo "Current Iteration: $current"
          fi
        else
          # If all else fails, show default progress of 1
          if [ -n "$iterations" ] && [ "$iterations" -gt 0 ]; then
            echo "Progress: 1/$iterations"
            local percentage=$((100 / iterations))
            echo "Completion: ${percentage}%"
            echo "Current Iteration: 1"
          fi
        fi
      fi
    else
      echo "❌ SIMULATION IS NOT RUNNING"
    fi
    echo ""
    echo "------------ CURRENT SETTINGS ------------"
    echo "URL: $url"
    echo "Iterations: $iterations"
    echo "Min interval: $min_interval seconds"
    echo "Max interval: $max_interval seconds"
    echo "Airplane mode delay: $airplane_delay ms"
    echo "--------------- FEATURES ----------------"
    echo "IP Rotation: $rotate_ip"
    echo "WebView Mode: $webview_mode"
    echo "Random Device Profiles: $random_devices"
    echo "----------------------------------------"
    
    # Try to get more detailed simulation status if app is running
    if is_app_running; then
      # Log the last few messages to see simulation progress
      echo ""
      echo "------------ RECENT LOG ACTIVITY ------------"
      adb logcat -d -t 10 -v brief $PACKAGE:I *:S | grep -i "simul\|traffic\|iteration\|progress" || echo "No relevant log entries found"
      echo "---------------------------------------------"
    fi
  else
    echo "Cannot access preferences file to show status."
    echo "Using broadcast method instead:"
    send_broadcast "get_status" ""
  fi
}

# ------------------------------------------------------
# HELP AND COMMAND PROCESSING
# ------------------------------------------------------

show_help() {
  echo "Drono Master Control Script"
  echo "============================"
  echo "Usage: ./drono_control.sh <command> [parameters]"
  echo ""
  echo "Commands:"
  echo ""
  echo "Simulation Control:"
  echo "  start               - Start the simulation"
  echo "  stop                - Stop the simulation"
  echo "  pause               - Pause the simulation"
  echo "  resume              - Resume the simulation"
  echo "  restart             - Restart the app"
  echo ""
  echo "Session Management:"
  echo "  restore_session     - Restore a previously saved session"
  echo "  dismiss_restore     - Dismiss the restore session dialog and clear saved state"
  echo "  check_session       - Check if a saved session is available to restore"
  echo ""
  echo "Setting Commands:"
  echo "  url <target_url>    - Set the target URL"
  echo "  iterations <number> - Set number of iterations"
  echo "  min_interval <sec>  - Set minimum interval in seconds"
  echo "  max_interval <sec>  - Set maximum interval in seconds"
  echo "  delay <ms>          - Set airplane mode delay in milliseconds"
  echo "  toggle <feature> <true|false> - Toggle a feature on/off"
  echo ""
  echo "Special Flags:"
  echo "  -settings           - Force stop app before applying settings and ensure settings are applied before starting"
  echo "  -dryrun             - Show what would be changed without actually making changes"
  echo ""
  echo "Preset Configurations:"
  echo "  preset <name>       - Apply a preset configuration"
  echo "  Available presets:  performance, stealth, balanced, veewoy"
  echo ""
  echo "Status:"
  echo "  status              - Show current app status and settings"
  echo ""
  echo "Multiple Commands:"
  echo "  You can chain multiple commands in a single line:"
  echo "  ./drono_control.sh -settings url https://example.com iterations 100 min_interval 5 start"
  echo "  ./drono_control.sh -dryrun preset veewoy"
  echo ""
  echo "Features that can be toggled:"
  echo "  rotate_ip, random_devices, webview_mode, aggressive_clearing,"
  echo "  new_webview_per_request, handle_redirects"
  echo ""
  echo "Examples:"
  echo "  ./drono_control.sh preset veewoy start"
  echo "  ./drono_control.sh -settings url https://veewoy.com iterations 500 start"
  echo "  ./drono_control.sh toggle rotate_ip true min_interval 2 max_interval 5"
  echo "  ./drono_control.sh -dryrun -settings url https://veewoy.com iterations 600 start"
  echo "  ./drono_control.sh dismiss_restore start       # Dismiss restore dialog and start new session"
  echo "  ./drono_control.sh restore_session            # Restore a previously saved session"
  echo "  ./drono_control.sh check_session              # Check if a saved session is available to restore"
}

# Process commands sequentially
process_commands() {
  if [ $# -eq 0 ]; then
    show_help
    exit 0
  fi

  local skip=0
  local use_settings_mode=false
  local need_to_start=false
  local settings_changed=false
  DRY_RUN=false
  DISMISS_RESTORE_DIALOG=false
  
  # First pass to check for settings mode and if start is requested
  for arg in "$@"; do
    if [ "$arg" = "-settings" ]; then
      use_settings_mode=true
    elif [ "$arg" = "start" ]; then
      need_to_start=true
    elif [ "$arg" = "-dryrun" ]; then
      DRY_RUN=true
      echo "🔍 DRY RUN MODE: No changes will be made"
    elif [ "$arg" = "dismiss_restore" ]; then
      DISMISS_RESTORE_DIALOG=true
    fi
  done
  
  # If settings mode, force stop the app first
  if [ "$use_settings_mode" = true ]; then
    echo "🔄 Settings mode: Force stopping app to ensure clean settings application..."
    force_stop_app
  fi
  
  # Process all commands
  for ((i=1; i<=$#; i++)); do
    if [ $skip -gt 0 ]; then
      skip=$((skip - 1))
      continue
    fi
    
    arg="${!i}"
    next_idx=$((i + 1))
    next_arg="${!next_idx}"
    
    # Skip the settings flag since we already processed it
    if [ "$arg" = "-settings" ] || [ "$arg" = "-dryrun" ]; then
      continue
    fi
    
    # In settings mode, don't process start command here
    if [ "$use_settings_mode" = true ] && [ "$arg" = "start" ]; then
      continue
    fi
    
    case "$arg" in
      "help")
        show_help
        exit 0
        ;;
      "start")
        if [ "$use_settings_mode" = false ]; then
          start_simulation
        fi
        ;;
      "stop")
        stop_simulation
        ;;
      "pause")
        pause_simulation
        ;;
      "resume")
        resume_simulation
        ;;
      "restart")
        restart_app
        ;;
      "restore_session")
        restore_session
        ;;
      "dismiss_restore")
        clear_session_state
        ;;
      "check_session")
        check_session_available
        ;;
      "url")
        if [ -z "$next_arg" ]; then
          echo "Error: No URL specified"
          exit 1
        fi
        set_target_url "$next_arg"
        settings_changed=true
        skip=1
        ;;
      "iterations")
        if [ -z "$next_arg" ]; then
          echo "Error: No value specified"
          exit 1
        fi
        set_iterations "$next_arg"
        settings_changed=true
        skip=1
        ;;
      "min_interval")
        if [ -z "$next_arg" ]; then
          echo "Error: No value specified"
          exit 1
        fi
        set_min_interval "$next_arg"
        settings_changed=true
        skip=1
        ;;
      "max_interval")
        if [ -z "$next_arg" ]; then
          echo "Error: No value specified"
          exit 1
        fi
        set_max_interval "$next_arg"
        settings_changed=true
        skip=1
        ;;
      "delay")
        if [ -z "$next_arg" ]; then
          echo "Error: No value specified"
          exit 1
        fi
        set_airplane_delay "$next_arg"
        settings_changed=true
        skip=1
        ;;
      "toggle")
        feature="${!next_idx}"
        value_idx=$((next_idx + 1))
        value="${!value_idx}"
        
        if [ -z "$feature" ] || [ -z "$value" ]; then
          echo "Error: Missing feature or value"
          echo "Usage: toggle <feature> <true|false>"
          exit 1
        fi
        
        toggle_feature "$feature" "$value"
        settings_changed=true
        skip=2
        ;;
      "preset")
        if [ -z "$next_arg" ]; then
          echo "Error: No preset specified"
          echo "Available presets: performance, stealth, balanced, veewoy"
          exit 1
        fi
        apply_preset "$next_arg"
        settings_changed=true
        skip=1
        ;;
      "status")
        show_status
        ;;
      *)
        echo "Unknown command: $arg"
        echo "Use './drono_control.sh help' for usage information"
        exit 1
        ;;
    esac
  done
  
  # If in settings mode and start was requested, start the app now after all settings are applied
  if [ "$use_settings_mode" = true ] && [ "$need_to_start" = true ]; then
    if [ "$settings_changed" = true ]; then
      echo ""
      echo "============================================================"
      echo "✅ SETTINGS: All settings have been successfully applied"
      echo "============================================================"
      echo ""
      # A small pause to make the separation more visible in the output
      sleep 1
    fi
    
    echo "============================================================"
    echo "🚀 STARTING SIMULATION: Launching app and starting simulation"
    echo "============================================================"
    start_simulation
    
    echo ""
    echo "============================================================"
    echo "🏁 OPERATION COMPLETE"
    echo "============================================================"
  fi
  
  # If this was a dry run, remind user
  if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN COMPLETE: No changes were made"
  fi
}

# Function to restore a previous session
restore_session() {
  echo "Restoring previous session..."
  
  # If in dry run mode, just return
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would restore previous session"
    return 0
  fi
  
  # Use activity command for the most reliable operation
  send_activity_command "restore_session"
  echo "Restore session command sent"
}

# Function to clear saved session state (dismiss restore dialog)
clear_session_state() {
  echo "Clearing saved session state (dismissing restore dialog)..."
  
  # If in dry run mode, just return
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would clear saved session state"
    return 0
  fi
  
  # Direct file access is most reliable
  if check_file_access; then
    echo "Using direct preferences file access to clear session state..."
    
    if [ $USE_RUNAS -eq 1 ]; then
      # Use run-as for debug builds to remove session preference keys
      adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE sed -i '/session_current_index/d' $PREFS_FILE"
      adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE sed -i '/session_total_requests/d' $PREFS_FILE"
      adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE sed -i '/session_is_paused/d' $PREFS_FILE"
      adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE sed -i '/session_start_time/d' $PREFS_FILE"
      adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE sed -i '/session_total_paused_time/d' $PREFS_FILE"
      adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE sed -i '/session_pause_start_time/d' $PREFS_FILE"
    else
      # Use su for rooted devices
      adb -s "$ADB_DEVICE_ID" shell "su -c 'sed -i \"/session_current_index/d\" $PREFS_FILE'"
      adb -s "$ADB_DEVICE_ID" shell "su -c 'sed -i \"/session_total_requests/d\" $PREFS_FILE'"
      adb -s "$ADB_DEVICE_ID" shell "su -c 'sed -i \"/session_is_paused/d\" $PREFS_FILE'"
      adb -s "$ADB_DEVICE_ID" shell "su -c 'sed -i \"/session_start_time/d\" $PREFS_FILE'"
      adb -s "$ADB_DEVICE_ID" shell "su -c 'sed -i \"/session_total_paused_time/d\" $PREFS_FILE'"
      adb -s "$ADB_DEVICE_ID" shell "su -c 'sed -i \"/session_pause_start_time/d\" $PREFS_FILE'"
    fi
    
    echo "✅ Session state cleared - restore dialog will be dismissed"
  else
    # Fallback to broadcast method by sending a command to clear session state
    echo "No direct file access, using broadcast command..."
    send_broadcast "clear_session_state" ""
    echo "⚠️ Clear session state command sent, but cannot verify if successful"
  fi
}

# Function to check if a session is available to restore
check_session_available() {
  echo "Checking if a session is available to restore..."
  
  if check_file_access; then
    # Check if the session preference keys exist
    if [ $USE_RUNAS -eq 1 ]; then
      local has_session=$(adb -s "$ADB_DEVICE_ID" shell "run-as $PACKAGE cat $PREFS_FILE | grep -c session_current_index")
    else
      local has_session=$(adb -s "$ADB_DEVICE_ID" shell "su -c 'cat $PREFS_FILE | grep -c session_current_index'")
    fi
    
    if [ "$has_session" -gt 0 ]; then
      echo "✅ Found saved session data available for restoration"
      return 0  # Success - session available
    else
      echo "❌ No saved session data found"
      return 1  # Failure - no session
    fi
  else
    echo "Cannot access preferences file to check for saved session"
    return 2  # Cannot determine
  fi
}

# Run the main command processing
process_commands "$@" 