# Instagram URL Persistence Fix

This document explains the Instagram URL persistence fixes implemented in the codebase and how to test them.

## Problem

The Instagram URL settings on Android devices were not persisting properly across app restarts. URLs needed to be set in two separate locations:

1. In `url_config.xml` with field name `instagram_url`
2. In `instagram_traffic_simulator_prefs.xml` with field name `target_url`

## Solution

The solution implements several improvements to ensure URL persistence:

1. Fixed XML formatting in configuration files to correctly store URL values
2. Improved file permissions and ownership handling when transferring config files to devices
3. Corrected broadcast command formatting to avoid URL parameter quoting issues
4. Implemented a reliable direct modification method for the `target_url` entry using sed commands
5. Fixed URL parameter handling in the app start intent

These fixes ensure that URLs persist across app restarts, similar to the pattern in the working `drono_control.sh` script.

## Key Files Modified

- `server/core/instagram_manager.py` - Main module implementing the URL persistence fixes

## Testing

A comprehensive test suite has been created to verify the fixes:

### Automated Testing

Run the automated test script which:
1. Tests multiple URL formats (simple, complex, with special characters)
2. Verifies settings in both configuration locations
3. Tests persistence across app restarts
4. Works with different device access methods (root, run-as)

```bash
# Run on the first connected device:
./tools/run_instagram_tests.sh

# Run on a specific device:
./tools/run_instagram_tests.sh DEVICE_ID
```

### Manual Testing

You can also test the fixes manually:

1. Set a URL using the API:
   ```bash
   curl -X POST http://localhost:8000/instagram/set-url-sync \
     -H "Content-Type: application/json" \
     -d '{"url": "https://instagram.com/p/example", "all_devices": true}'
   ```

2. Verify the settings persisted after restarting the app:
   ```bash
   # Using API to restart:
   curl -X POST http://localhost:8000/instagram/restart-app \
     -H "Content-Type: application/json" \
     -d '{"all_devices": true}'
   
   # Or manually restart:
   adb shell am force-stop com.example.imtbf.debug
   adb shell am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity
   ```

3. Check URL values in XML files using ADB:
   ```bash
   # For root access:
   adb shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml'"
   adb shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"
   
   # For debug builds with run-as:
   adb shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml"
   adb shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml"
   ```

## Known Limitations

- Devices without root or run-as access rely solely on broadcast intents which may be less reliable
- Complex URLs with special characters may require additional escaping in some contexts
- Some Android devices may have manufacturer-specific limitations on app preferences

## Future Improvements

- Add in-app verification of URL settings to improve feedback
- Implement a retry mechanism for failed URL settings
- Add a cache of recently used URLs to improve recovery from errors 