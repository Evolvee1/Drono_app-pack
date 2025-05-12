# Troubleshooting Complex Instagram URLs

This guide addresses specific issues with setting complex Instagram redirect URLs on Android devices and provides manual solutions when the API verification reports failures.

## Understanding the "URL set but verification failed" Message

When working with long Instagram redirect URLs with tracking parameters, you may see "URL set but verification failed" messages. This typically means:

1. **The URL was successfully written to preferences**
2. **The verification step encountered issues**

The URL is likely correctly set on the device, but the verification process couldn't confirm it due to one of these reasons:

- The URL is very long and got truncated in logs
- Special characters in the URL interfered with broadcast verification
- The app didn't respond to status broadcasts within the timeout period

## Manual Solution for Complex Instagram URLs

If you encounter issues with complex Instagram redirect URLs, follow these steps:

### Step 1: Stop the App and Clear Its State

```bash
# For a specific device
adb -s DEVICE_ID shell am force-stop com.example.imtbf.debug

# For all connected devices
for device in $(adb devices | grep -v "List" | awk '{print $1}'); do
  adb -s $device shell am force-stop com.example.imtbf.debug
done
```

### Step 2: Set Preferences Directly

Create a preferences file template:

```xml
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="device_id">DEVICE_ID_VALUE</string>
    <string name="current_session_id">SESSION_ID_VALUE</string>
    <int name="min_interval" value="3" />
    <string name="target_url">YOUR_COMPLEX_URL</string>
    <int name="max_interval" value="5" />
    <int name="iterations" value="100" />
    <boolean name="use_webview_mode" value="true" />
    <boolean name="new_webview_per_request" value="true" />
    <boolean name="rotate_ip" value="true" />
    <boolean name="use_random_device_profile" value="true" />
</map>
```

Push and copy to each device:

```bash
# Push to device temporary storage
adb -s DEVICE_ID push temp_prefs.xml /data/local/tmp/

# Copy to app's preferences directory
adb -s DEVICE_ID shell "run-as com.example.imtbf.debug cp /data/local/tmp/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml"
```

### Step 3: Verify Preferences are Set

```bash
adb -s DEVICE_ID shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml | grep target_url"
```

### Step 4: Start the App

```bash
adb -s DEVICE_ID shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity"
```

### Step 5: Confirm the App is Running

```bash
adb -s DEVICE_ID shell "pidof com.example.imtbf.debug"
```

## Example for a Specific Instagram URL

For the Instagram URL:
`https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA`

1. Create `temp_prefs.xml` with the URL and settings
2. Use the manual steps above to apply it to all devices

## Improving Future Reliability

1. **Use the Direct Preferences Method**:
   The API's direct preferences modification method is generally reliable, but sometimes manual intervention is needed.

2. **Restart the App After Setting**:
   Always force-stop and restart the app after setting complex URLs.

3. **Simplify URLs When Possible**:
   If you control the URL source, consider using a URL shortener for very complex URLs.

4. **In Scripts, Escape Special Characters**:
   Use proper escaping when using these URLs in shell scripts.

## Using the Improved API with Manual Verification

1. Use the improved API to set the URL
2. Even if verification fails, manually verify with:
   ```bash
   adb -s DEVICE_ID shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml | grep target_url"
   ```
3. If the URL is correctly set in preferences, consider the operation successful

## Future Enhancements

We are continuously improving the API to better handle these complex URLs. Future versions will include:

1. More robust URL handling
2. Better verification for complex URLs
3. Alternative verification methods
4. Enhanced logging for debugging

For now, the manual method described above should reliably handle even the most complex Instagram redirect URLs. 