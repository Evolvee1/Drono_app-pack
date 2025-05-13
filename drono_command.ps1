# Drono Command - PowerShell wrapper for drono_control.sh
# This script ensures proper command execution across devices

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Device = "",
    
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Commands
)

# Function to get connected devices
function Get-ConnectedDevices {
    $output = adb devices
    $devices = @()
    
    foreach ($line in $output) {
        if ($line -match '(\S+)\s+device$') {
            $devices += $matches[1]
        }
    }
    
    return $devices
}

# Function to execute drono_control.sh with the given device and commands
function Execute-DronoControl {
    param(
        [string]$DeviceId,
        [string[]]$CommandArgs
    )
    
    # Set the ADB_DEVICE_ID environment variable and execute the script
    Write-Host "Executing drono_control.sh for device: $DeviceId"
    Write-Host "Commands: $($CommandArgs -join ' ')"
    
    # Convert command arguments to a single string
    $commandString = $CommandArgs -join " "
    
    # Check if WSL is available
    $useWsl = $false
    try {
        $wslCheck = wsl --version 2>&1
        if (-not $LASTEXITCODE) {
            $useWsl = $true
        }
    } catch {
        $useWsl = $false
    }
    
    # Path to the drono_control.sh script
    $scriptPath = Join-Path -Path (Get-Location).Path -ChildPath "android-app/drono_control.sh"
    
    # Construct and execute the command
    if ($useWsl) {
        Write-Host "Using WSL to execute bash script..."
        # Use WSL to execute the bash script
        $result = wsl -e bash -c "export ADB_DEVICE_ID='$DeviceId' && '$scriptPath' -settings $commandString"
    } else {
        # Try using Git Bash if available
        try {
            $gitBashPath = "C:\Program Files\Git\bin\bash.exe"
            if (Test-Path $gitBashPath) {
                Write-Host "Using Git Bash to execute script..."
                $env:ADB_DEVICE_ID = $DeviceId
                $result = & $gitBashPath -c "export ADB_DEVICE_ID='$DeviceId' && '$scriptPath' -settings $commandString"
            } else {
                throw "Git Bash not found"
            }
        } catch {
            # Fallback to using ADB commands directly if bash is not available
            Write-Host "No bash found, using direct ADB commands..."
            
            # Kill the app first
            Write-Host "Stopping app on device $DeviceId..."
            adb -s $DeviceId shell "am force-stop com.example.imtbf.debug"
            Start-Sleep -Seconds 2
            
            # Extract URL if present
            $url = $null
            for ($i = 0; $i -lt $CommandArgs.Length; $i++) {
                if ($CommandArgs[$i] -eq "url" -and $i+1 -lt $CommandArgs.Length) {
                    $url = $CommandArgs[$i+1]
                    break
                }
            }
            
            if ($url) {
                # Create the preferences file
                Write-Host "Setting URL to: $url"
                
                # Push URL via direct intent
                adb -s $DeviceId shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity --es custom_url ""$url"""
                Start-Sleep -Seconds 2
                
                # Send broadcast to update URL
                adb -s $DeviceId shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es value ""$url"" -p com.example.imtbf.debug"
                Start-Sleep -Seconds 1
            }
            
            # Start the simulation if requested
            if ($CommandArgs -contains "start") {
                Write-Host "Starting simulation..."
                adb -s $DeviceId shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p com.example.imtbf.debug"
            }
        }
    }
    
    return $result
}

# Main execution logic

# If no device specified, get connected devices
if ([string]::IsNullOrEmpty($Device)) {
    Write-Host "No device specified, getting connected devices..."
    $devicesOutput = adb devices
    $devices = @()
    
    foreach ($line in $devicesOutput) {
        if ($line -match '(\S+)\s+device$') {
            $devices += $matches[1]
        }
    }
    
    if ($devices.Count -eq 0) {
        Write-Host "No devices connected!"
        exit 1
    } elseif ($devices.Count -eq 1) {
        $Device = $devices[0]
        Write-Host "Using device: $Device"
    } else {
        Write-Host "Multiple devices found. Please specify a device ID."
        Write-Host "Connected devices:"
        foreach ($dev in $devices) {
            Write-Host "  $dev"
        }
        exit 1
    }
} elseif ($Device -notmatch '^R') {
    # If the first argument doesn't look like a device ID, it's probably a command
    # Insert it at the beginning of the Commands array
    $Commands = @($Device) + $Commands
    
    # Get first available device
    $devicesOutput = adb devices
    $devices = @()
    
    foreach ($line in $devicesOutput) {
        if ($line -match '(\S+)\s+device$') {
            $devices += $matches[1]
        }
    }
    
    if ($devices.Count -eq 0) {
        Write-Host "No devices connected!"
        exit 1
    }
    
    $Device = $devices[0]
    Write-Host "Using device: $Device"
}

# Execute drono_control.sh with the given commands
$result = Execute-DronoControl -DeviceId $Device -CommandArgs $Commands

# Return the result
$result 