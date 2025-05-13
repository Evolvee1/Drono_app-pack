# Direct Command - Use ADB commands directly without relying on bash scripts
# This provides a direct PowerShell implementation of the core functionality

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Device = "",
    
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Commands
)

# Add reference to System.Web for URL encoding
Add-Type -AssemblyName System.Web

# Parse device ID and/or commands
if ([string]::IsNullOrEmpty($Device) -or $Device -notmatch '^R') {
    # If no device ID provided or it doesn't look like a device ID
    if (-not [string]::IsNullOrEmpty($Device)) {
        # Insert the first parameter as a command if it's not a device ID
        $Commands = @($Device) + $Commands
    }
    
    # Get the first available device
    $deviceList = adb devices
    $deviceMatch = $deviceList | Select-String -Pattern '(\S+)\s+device$'
    
    if ($deviceMatch.Count -eq 0) {
        Write-Host "No devices connected!"
        exit 1
    }
    
    # Extract device ID from the first match
    $Device = $deviceMatch[0].Matches.Groups[1].Value
    Write-Host "Using device: $Device"
}

# Process commands
$url = $null
$iterations = 100
$min_interval = 1
$max_interval = 2
$should_start = $false
$use_webview = $true
$rotate_ip = $true

# Parse commands
for ($i = 0; $i -lt $Commands.Count; $i++) {
    $cmd = $Commands[$i]
    
    switch ($cmd) {
        "url" {
            if ($i + 1 -lt $Commands.Count) {
                $url = $Commands[$i + 1]
                $i++
            }
        }
        "iterations" {
            if ($i + 1 -lt $Commands.Count) {
                $iterations = $Commands[$i + 1]
                $i++
            }
        }
        "min_interval" {
            if ($i + 1 -lt $Commands.Count) {
                $min_interval = $Commands[$i + 1]
                $i++
            }
        }
        "max_interval" {
            if ($i + 1 -lt $Commands.Count) {
                $max_interval = $Commands[$i + 1]
                $i++
            }
        }
        "start" {
            $should_start = $true
        }
        "toggle" {
            if ($i + 2 -lt $Commands.Count) {
                $feature = $Commands[$i + 1]
                $value = $Commands[$i + 2]
                
                switch ($feature) {
                    "webview_mode" {
                        $use_webview = ($value -eq "true")
                    }
                    "rotate_ip" {
                        $rotate_ip = ($value -eq "true")
                    }
                }
                
                $i += 2
            }
        }
    }
}

# Function to properly escape URL for XML content
function Escape-XmlString {
    param([string]$text)
    return $text.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;").Replace("'", "&apos;")
}

# Function to properly escape URL for ADB shell commands
function Escape-ForShell {
    param([string]$text)
    # First, escape single quotes for shell
    $escaped = $text.Replace("'", "'\'''")
    # Then wrap in single quotes
    return "'$escaped'"
}

# Function to check if we have write access to app shared_prefs directories
function Test-AppWriteAccess {
    param([string]$deviceId)
    
    # Try to create a temporary test file
    $testFile = "temp_write_test_$((Get-Date).Ticks).xml"
    $xmlContent = @"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="test">test</string>
</map>
"@
    Set-Content -Path $testFile -Value $xmlContent
    
    # Push to sdcard
    $pushResult = adb -s $deviceId push $testFile "/sdcard/$testFile" 2>&1
    
    # Try to copy from sdcard to app shared_prefs
    $copyResult = adb -s $deviceId shell "run-as com.example.imtbf.debug cp /sdcard/$testFile /data/data/com.example.imtbf.debug/shared_prefs/$testFile" 2>&1
    
    # Clean up
    Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
    adb -s $deviceId shell "rm /sdcard/$testFile" | Out-Null
    
    # Check if we could copy successfully
    if ($copyResult -match "Permission denied" -or $copyResult -match "Operation not permitted") {
        Write-Host "   ⚠️ No write access to shared_prefs directory"
        return $false
    }
    
    # Clean up the test file in the app directory
    adb -s $deviceId shell "run-as com.example.imtbf.debug rm /data/data/com.example.imtbf.debug/shared_prefs/$testFile" | Out-Null
    
    # If we got here, we have write access
    Write-Host "   ✅ Full write access to shared_prefs directory"
    return $true
}

# Step 1: Force stop the app first
Write-Host "Step 1: Stopping app on device $Device..."
adb -s $Device shell "am force-stop com.example.imtbf.debug"
Start-Sleep -Seconds 2

# Check if we have write access to the app directories
$hasWriteAccess = Test-AppWriteAccess -deviceId $Device
Write-Host "App write access: $(if ($hasWriteAccess) { "Available" } else { "Not available" })"

# Step 2: Set URL if specified
if ($url) {
    Write-Host "Step 2: Setting URL to: $url"
    
    # Create a timestamp
    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $timestamp = $timestamp * 1000
    
    # XML-escape the URL for preferences files
    $xmlEscapedUrl = Escape-XmlString $url
    
    # Create the XML content
    $xmlContent = @"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="$($use_webview.ToString().ToLower())" />
    <string name="device_id">$Device</string>
    <string name="current_session_id">session-$timestamp</string>
    <string name="target_url">$xmlEscapedUrl</string>
    <int name="iterations" value="$iterations" />
    <int name="min_interval" value="$min_interval" />
    <int name="max_interval" value="$max_interval" />
    <boolean name="rotate_ip" value="$($rotate_ip.ToString().ToLower())" />
    <boolean name="use_random_device_profile" value="true" />
    <boolean name="new_webview_per_request" value="true" />
    <long name="last_run_timestamp" value="$timestamp" />
    <boolean name="is_first_run" value="false" />
</map>
"@

    # Create URL config
    $urlXmlContent = @"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="saved_url">$xmlEscapedUrl</string>
    <long name="last_saved_timestamp" value="$timestamp" />
</map>
"@
    
    # If we have write access, try to use the file-based approach
    if ($hasWriteAccess) {
        # Save to local file
        Set-Content -Path "temp_prefs.xml" -Value $xmlContent
        
        # Push to device
        Write-Host "   Pushing settings file to device..."
        adb -s $Device push "temp_prefs.xml" "/sdcard/temp_prefs.xml"
        
        # Copy to application
        Write-Host "   Copying settings to application..."
        adb -s $Device shell "run-as com.example.imtbf.debug cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml"
        adb -s $Device shell "run-as com.example.imtbf.debug chmod 600 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml"
        
        # Save url config to local file
        Set-Content -Path "url_config.xml" -Value $urlXmlContent
        
        # Push to device
        Write-Host "   Pushing URL config to device..."
        adb -s $Device push "url_config.xml" "/sdcard/url_config.xml"
        
        # Copy to application
        adb -s $Device shell "run-as com.example.imtbf.debug cp /sdcard/url_config.xml /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml"
        adb -s $Device shell "run-as com.example.imtbf.debug chmod 600 /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml"
        
        # Remove temporary files
        Remove-Item -Path "temp_prefs.xml" -Force
        Remove-Item -Path "url_config.xml" -Force
        
        # Double-check if files were created properly
        Write-Host "   Verifying settings were applied..."
        $prefs_check = adb -s $Device shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml" 2>$null
        if ($prefs_check -match 'target_url') {
            if ($prefs_check -match [regex]::Escape($url) -or $prefs_check -match [regex]::Escape($xmlEscapedUrl)) {
                Write-Host "   ✅ URL setting verified in preferences file"
            } else {
                Write-Host "   ⚠️ URL in preferences file does not match target URL"
            }
        } else {
            Write-Host "   ⚠️ Could not verify preferences file"
        }
    } else {
        Write-Host "   No write access to app directories. Using intent methods only."
    }
}

# Step 3: Start the app if needed
if ($should_start) {
    Write-Host "Step 3: Starting app with URL: $url"
    
    # Escape URL for shell command
    $shellEscapedUrl = Escape-ForShell $url
    
    # Try multiple approaches to set the URL and start the app
    
    # Method 1: Start with intent using the correct syntax
    Write-Host "   Method 1: Starting app with custom_url intent..."
    adb -s $Device shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity --es custom_url $shellEscapedUrl --ez load_from_intent true"
    Start-Sleep -Seconds 2
    
    # Method 2: Try using different broadcast intents
    Write-Host "   Method 2: Sending multiple broadcast intents..."
    
    # Command broadcast
    adb -s $Device shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es value $shellEscapedUrl -p com.example.imtbf.debug"
    Start-Sleep -Seconds 1
    
    # Specific SET_URL action
    adb -s $Device shell "am broadcast -a com.example.imtbf.debug.SET_URL --es url $shellEscapedUrl -p com.example.imtbf.debug"
    Start-Sleep -Seconds 1
    
    # Load URL action
    adb -s $Device shell "am broadcast -a com.example.imtbf.debug.LOAD_URL --es url $shellEscapedUrl -p com.example.imtbf.debug"
    Start-Sleep -Seconds 1
    
    # Method 3: Try deep linking
    Write-Host "   Method 3: Trying deep linking..."
    # Encode the URL for the deep link (we need to double-encode)
    $encodedUrlForDeepLink = [System.Web.HttpUtility]::UrlEncode($url)
    
    adb -s $Device shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity -a android.intent.action.VIEW -d 'traffic-sim://load_url?url=$encodedUrlForDeepLink&force=true'"
    Start-Sleep -Seconds 2
    
    # Send broadcast to start simulation
    Write-Host "Step 4: Starting simulation..."
    adb -s $Device shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p com.example.imtbf.debug"
    
    # Verify the app is running
    $appCheck = adb -s $Device shell "pidof com.example.imtbf.debug"
    if ($appCheck) {
        Write-Host "✅ App is running with PID: $appCheck"
    } else {
        Write-Host "⚠️ Warning: Could not verify app is running"
    }
    
    # Verify the URL was set
    Write-Host "   Checking if URL was properly set..."
    $url_check = adb -s $Device shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml" 2>$null
    if ($url_check -match 'target_url') {
        $match = [regex]::Match($url_check, '<string name="target_url">(.*?)</string>')
        if ($match.Success) {
            $current_url = $match.Groups[1].Value
            Write-Host "   Current URL is: $current_url"
            
            # Check if URL doesn't match and try other settings files
            if ($current_url -ne $url -and $current_url -ne $xmlEscapedUrl -and $hasWriteAccess) {
                Write-Host "   URL not updated in main preferences. Checking other settings files..."
                
                # Try reading url_config.xml
                $url_config_check = adb -s $Device shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml" 2>$null
                if ($url_config_check -match 'saved_url') {
                    $config_match = [regex]::Match($url_config_check, '<string name="saved_url">(.*?)</string>')
                    if ($config_match.Success) {
                        $config_url = $config_match.Groups[1].Value
                        Write-Host "   URL in url_config.xml: $config_url"
                    }
                }
            }
        }
    } else {
        Write-Host "   ⚠️ Could not read current URL from preferences file"
    }
    
    # For devices without write access, try another broadcast after starting
    if (-not $hasWriteAccess) {
        Write-Host "   Additional attempt for devices without write access..."
        Start-Sleep -Seconds 2
        adb -s $Device shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command reload_url --es value $shellEscapedUrl -p com.example.imtbf.debug"
    }
}

Write-Host "Command sequence completed." 