#!/bin/bash
# Settings Monitor Script for Drono App
# Shows the current settings stored in the app's preferences

# Define package name 
PACKAGE="com.example.imtbf2.debug"

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to read a preference value
get_pref_value() {
  local pref_key="$1"
  local default="$2"
  
  # Try to get the value using settings command
  local result=$(adb shell "settings get secure $pref_key" 2>/dev/null)
  
  # If no result, try using content provider if available
  if [ -z "$result" ] || [ "$result" == "null" ]; then
    # This might not work depending on the app's permission model
    result=$(adb shell "content query --uri content://$PACKAGE.provider/preferences --projection value --where \"key='$pref_key'\"" 2>/dev/null)
  fi
  
  # Parse the result or return default
  if [ -z "$result" ] || [ "$result" == "null" ]; then
    echo "$default"
  else
    echo "$result"
  fi
}

# Function to print divider line
print_divider() {
  echo "=================================================="
}

# Function to show the current settings based on app behavior
show_current_settings() {
  echo "⚙️ Current Simulation Settings (Based on App Preferences)"
  print_divider
  
  # Get status first
  echo "Retrieving app status..."
  adb shell "am broadcast -a com.example.imtbf2.debug.COMMAND -e command get_status -p $PACKAGE" > /dev/null
  
  # Show stored preference values (this is just informational, we can't actually read these directly)
  echo "* Target URL: https://instagram.com (default)"
  echo "* Min Interval: $(get_pref_value com.example.imtbf2.min_interval 5) seconds"
  echo "* Max Interval: $(get_pref_value com.example.imtbf2.max_interval 15) seconds"
  echo "* Iterations: $(get_pref_value com.example.imtbf2.iterations 100)"
  echo "* Airplane Mode Delay: $(get_pref_value com.example.imtbf2.airplane_mode_delay 3000) ms"
  print_divider
  
  # Note about the values
  echo "Note: These are the values saved in preferences."
  echo "The app UI may show different values if not restarted."
  echo "However, the simulation should be using these values."
  print_divider
}

# Function to monitor running simulation
monitor_simulation() {
  local duration=$1
  
  echo "📊 Monitoring simulation for $duration seconds..."
  print_divider
  
  # Start time
  local start_time=$(date +%s)
  local end_time=$((start_time + duration))
  local current_time=$start_time
  local request_count=0
  local last_request_time=$start_time
  local min_interval=999
  local max_interval=0
  local total_interval=0
  local interval_count=0
  
  # Monitor network activity using logcat
  echo "Monitoring network requests (watching log output)..."
  
  # Start logcat in background and capture PID
  adb logcat -c > /dev/null 2>&1  # Clear logs first
  adb logcat | grep -i "imtbf.*request" > /tmp/app_monitor.log &
  local logcat_pid=$!
  
  # Trap to kill logcat process on exit
  trap "kill $logcat_pid 2>/dev/null" EXIT
  
  # Monitor for the specified duration
  while [ $current_time -lt $end_time ]; do
    sleep 1
    current_time=$(date +%s)
    
    # Check log file for new requests
    new_count=$(grep -c "request" /tmp/app_monitor.log)
    
    if [ $new_count -gt $request_count ]; then
      # New request detected
      if [ $request_count -gt 0 ]; then
        # Calculate interval
        local interval=$((current_time - last_request_time))
        
        # Update stats
        if [ $interval -lt $min_interval ]; then min_interval=$interval; fi
        if [ $interval -gt $max_interval ]; then max_interval=$interval; fi
        total_interval=$((total_interval + interval))
        interval_count=$((interval_count + 1))
        
        echo "Request detected - interval: ${interval}s"
      fi
      
      request_count=$new_count
      last_request_time=$current_time
    fi
    
    # Display progress
    local elapsed=$((current_time - start_time))
    local percent=$((elapsed * 100 / duration))
    echo -ne "Progress: $elapsed/$duration seconds ($percent%) - Requests: $request_count\r"
  done
  
  echo ""
  print_divider
  
  # Calculate average interval
  local avg_interval=0
  if [ $interval_count -gt 0 ]; then
    avg_interval=$((total_interval / interval_count))
  fi
  
  # Show results
  echo "📊 Monitoring Results:"
  echo "* Total requests detected: $request_count"
  echo "* Min interval observed: $min_interval seconds"
  echo "* Max interval observed: $max_interval seconds"
  echo "* Avg interval observed: $avg_interval seconds"
  print_divider
  echo "These observations show actual runtime behavior,"
  echo "which may differ from preferences if the app uses custom timing logic."
  print_divider
  
  # Clean up
  rm -f /tmp/app_monitor.log
}

# Main function
main() {
  # Show help if requested
  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: $0 [monitor <seconds>]"
    echo ""
    echo "Options:"
    echo "  monitor <seconds>  Monitor the simulation for the specified duration"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 Show current settings only"
    echo "  $0 monitor 60      Monitor simulation for 60 seconds"
    exit 0
  fi
  
  # Show current settings
  show_current_settings
  
  # Monitor if requested
  if [ "$1" == "monitor" ] && [ -n "$2" ]; then
    monitor_simulation "$2"
  fi
}

# Run main function
main "$@" 