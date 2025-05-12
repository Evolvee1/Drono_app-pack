# Instagram URL Guide - Improved Device Settings API

This quick reference guide focuses specifically on handling Instagram URLs with the improved Device Settings API, including complex redirect links and tracking parameters.

## Instagram URL Types

Instagram has several URL formats that require special handling:

1. **Profile URLs**: `https://instagram.com/username`
2. **Post URLs**: `https://www.instagram.com/p/CODE/`
3. **Story URLs**: `https://www.instagram.com/stories/username/ID/`
4. **Redirect URLs**: `https://l.instagram.com/?u=ENCODED_URL&e=TRACKING_CODE`
5. **Shortened URLs**: `https://igshid.com/SHORTENED_CODE`

## Setting Instagram URLs

### Command Line Interface

```bash
# Basic profile URL
python3 improved_test_api.py set-url --url "https://instagram.com/username" --all-devices

# Post URL
python3 improved_test_api.py set-url --url "https://www.instagram.com/p/Cxyz123456/" --devices DEVICE_ID

# Complex redirect URL
python3 improved_test_api.py set-url --url "https://l.instagram.com/?u=https%3A%2F%2Fexample.com%2Fpath&e=TRACKING_CODE" --all-devices --webview-mode --new-webview-per-request
```

### REST API

```bash
# Using curl for a complex Instagram URL
curl -X POST http://localhost:8000/set-url \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://l.instagram.com/?u=https%3A%2F%2Fexample.com%2Fpath&e=TRACKING_CODE",
    "all_devices": true,
    "webview_mode": true,
    "new_webview_per_request": true
  }'

# Using the backward-compatible endpoint
curl -X POST http://localhost:8000/instagram-settings \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://instagram.com/profile/username",
    "all_devices": true
  }'
```

## Handling Very Long Instagram Redirect URLs

Instagram redirect URLs can be extremely long and complex. The example below shows how to handle them:

```bash
# Very long Instagram redirect URL with tracking parameters
python3 improved_test_api.py set-url --url "https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA" \
  --all-devices \
  --webview-mode \
  --new-webview-per-request
```

## Recommended Settings for Instagram URLs

For optimal performance with Instagram URLs, we recommend these settings:

```bash
python3 improved_test_api.py set-url --url "YOUR_INSTAGRAM_URL" \
  --webview-mode \           # Enable webview mode for better rendering
  --new-webview-per-request \ # Create fresh webview each time
  --rotate-ip \              # Rotate IP to avoid rate limiting
  --random-devices \         # Use random device profiles
  --min-interval 2 \         # Minimum 2 seconds between requests
  --max-interval 5           # Maximum 5 seconds between requests
```

## Instagram-Specific Considerations

1. **URL Encoding**
   - Instagram redirect URLs are already URL-encoded
   - The API preserves existing encoding in URLs
   - Special characters in non-encoded URLs will be automatically encoded

2. **Tracking Parameters**
   - Instagram often includes tracking parameters (`fbclid`, `igshid`, etc.)
   - These should be preserved exactly as they appear
   - Do not attempt to decode these parameters manually

3. **Verification Challenges**
   - Very long Instagram URLs may result in "URL set but verification failed"
   - This is normal and doesn't mean the URL wasn't set correctly
   - The API prioritizes direct preference file modification for these URLs

4. **WebView Configuration**
   - Instagram URLs work best with WebView mode enabled
   - For redirect URLs, enable `new-webview-per-request` to ensure proper loading

5. **Cookie Handling**
   - Instagram may use cookies for tracking
   - To clear cookies between operations, use the `force-stop` option before setting a new URL:
     ```bash
     adb -s DEVICE_ID shell am force-stop com.example.imtbf.debug
     python3 improved_test_api.py set-url --url "INSTAGRAM_URL" --devices DEVICE_ID
     ```

## Debugging Instagram URL Issues

If you encounter issues with Instagram URLs:

1. **Check URL Encoding**
   - Ensure all special characters are properly encoded
   - The URL should include `%` encoding for special characters

2. **Verify Preference Files**
   - Connect to the device and check the preference file:
     ```bash
     adb -s DEVICE_ID shell run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml | grep target_url
     ```

3. **Monitor App Logs**
   - Watch app logs during URL setting:
     ```bash
     adb -s DEVICE_ID logcat | grep -i "imtbf"
     ```

4. **Check Command API Logs**
   - Examine the API logs for detailed debugging information:
     ```bash
     tail -f logs/unified_command.log
     ```

## Example: Real-World Instagram URL Setting

This example demonstrates setting a complex Instagram redirect URL with all recommended settings:

```bash
python3 improved_test_api.py set-url \
  --url "https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA" \
  --all-devices \
  --iterations 500 \
  --min-interval 2 \
  --max-interval 5 \
  --webview-mode \
  --rotate-ip \
  --random-devices \
  --new-webview-per-request
```

Remember that while verification might fail for very complex URLs, the preference-based method ensures the URL is set correctly on the device. 