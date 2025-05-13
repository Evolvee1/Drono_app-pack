#!/bin/bash

# check_all_devices.sh - Check Instagram traffic simulation status on all connected devices

# Define package name
PACKAGE="com.example.imtbf.debug"

# Echo with timestamp
function log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Get a list of connected devices
DEVICES=$(adb devices | grep -v "List" | grep "device$" | awk '{print $1}')

if [ -z "$DEVICES" ]; then
  log "No devices connected. Exiting."
  exit 1
fi

log "Found connected devices:"
for DEVICE in $DEVICES; do
  echo "- $DEVICE"
done

echo "========================================"
echo "CHECKING ALL DEVICES STATUS"
echo "========================================"

for DEVICE in $DEVICES; do
  echo ""
  echo "========================================"
  log "Checking device: $DEVICE"
  echo "========================================"
  
  # Get device model
  MODEL=$(adb -s $DEVICE shell getprop ro.product.model)
  log "Device model: $MODEL"
  
  # Check if app is installed
  APP_INFO=$(adb -s $DEVICE shell pm list packages | grep $PACKAGE)
  if [ -n "$APP_INFO" ]; then
    log "✓ App is installed"
    
    # Check if app is running
    APP_PID=$(adb -s $DEVICE shell "ps | grep $PACKAGE" | grep -v grep)
    if [ -n "$APP_PID" ]; then
      log "✓ App is running"
      echo "$APP_PID"
    else
      log "✗ App is NOT running"
    fi
    
    # Check URL configuration
    log "URL configuration:"
    URL_CONFIG=$(adb -s $DEVICE shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/url_config.xml'" 2>/dev/null || \
      adb -s $DEVICE shell "cat /data/data/$PACKAGE/shared_prefs/url_config.xml" 2>/dev/null)
    
    if [ -n "$URL_CONFIG" ]; then
      echo "$URL_CONFIG" | grep -i "instagram_url"
    else
      log "✗ Could not read URL configuration"
    fi
    
    # Check preferences
    log "App preferences:"
    PREFS=$(adb -s $DEVICE shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml'" 2>/dev/null || \
      adb -s $DEVICE shell "cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml" 2>/dev/null)
    
    if [ -n "$PREFS" ]; then
      # Check key settings
      USE_WEBVIEW=$(echo "$PREFS" | grep -i "use_webview_mode")
      NEW_WEBVIEW=$(echo "$PREFS" | grep -i "new_webview_per_request")
      RESTORE_EXIT=$(echo "$PREFS" | grep -i "restore_on_exit")
      TARGET_URL=$(echo "$PREFS" | grep -i "target_url")
      IS_RUNNING=$(echo "$PREFS" | grep -i "is_running")
      
      echo "$USE_WEBVIEW"
      echo "$NEW_WEBVIEW"
      echo "$RESTORE_EXIT"
      
      if [ -n "$TARGET_URL" ]; then
        echo "$TARGET_URL"
      fi
      
      if [ -n "$IS_RUNNING" ]; then
        echo "$IS_RUNNING"
      fi
      
      # Verify correct settings
      if echo "$USE_WEBVIEW" | grep -q 'value="true"' && \
         echo "$NEW_WEBVIEW" | grep -q 'value="true"' && \
         echo "$RESTORE_EXIT" | grep -q 'value="false"'; then
        log "✓ Key settings are correctly configured"
      else
        log "✗ Some key settings are NOT correctly configured"
      fi
    else
      log "✗ Could not read preferences"
    fi
    
    # Request app status via broadcast
    log "Requesting app status via broadcast:"
    adb -s $DEVICE shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command get_status -p $PACKAGE"
    
    # Check logcat for recent Instagram URL processing
    log "Recent Instagram URL processing in logs:"
    adb -s $DEVICE logcat -d | grep -i "$PACKAGE.*instagram.*url" | tail -n 3
  else
    log "✗ App is NOT installed"
  fi
done

echo ""
echo "========================================"
log "Status check complete for all devices"
echo "========================================" 