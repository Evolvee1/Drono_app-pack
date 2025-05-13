# Drono Lite ROOT MODE Documentation

## Overview

This document explains the ROOT MODE operation of the Drono Lite control server, specifically designed to control Android devices running the IMadeThatBitchFamous app. ROOT MODE bypasses normal permission checks and uses root access for all device operations, which resolves permission issues on problematic devices.

## How ROOT MODE Works

The ADB controller always operates in ROOT MODE, which means:

1. All operations are executed with root privileges using `su -c` commands
2. The system assumes all devices have root access and bypasses regular permission checks
3. Settings are applied directly to system files using root privileges
4. Multiple fallback methods are implemented to ensure commands are executed successfully

## Key Features in ROOT MODE

- **Direct File Manipulation**: Settings are written directly to app preference files using root privileges
- **Permission Override**: Files are manually `chmod` and `chown` to ensure proper access
- **Directory Creation**: Required directories are created if missing
- **Multiple Application Methods**: ROOT commands, intents, and broadcasts are all used for redundancy
- **Deep Linking**: Uses URI schemes as an additional method to apply settings

## Handling Problematic Devices

ROOT MODE is specifically designed to handle devices with permission issues, such as device R9WR310F4GJ which previously had problems. By using only root commands, we bypass the standard permission system entirely.

## ROOT MODE Process Flow

1. **Device Detection**:
   - Devices are assumed to have root access
   - Device information is collected via root commands

2. **Settings Application**:
   ```
   1. Generate XML preference files
   2. Push files to device's sdcard
   3. Copy files to app's data directory using root (su -c)
   4. Set appropriate permissions with chmod/chown
   5. Verify settings were applied correctly
   ```

3. **App Control**:
   - Force stop the app if necessary using root
   - Apply settings using direct file manipulation
   - Start the app with intent parameters
   - Send broadcast commands to ensure settings are applied
   - Verify the app is running and settings are correct

## Common Commands

### Distributing URLs (ROOT MODE)

When distributing a URL to devices, the following steps are taken:

1. Force stop the app
2. Apply settings via direct file manipulation (root method)
3. Start the app with intent parameters
4. Send multiple broadcast intents as backup
5. Try deep linking as another fallback
6. Send a final start command

### Executing Commands

Commands are sent via broadcasts with root privileges:

- **start**: Start traffic simulation
- **stop**: Force stop the application
- **pause**: Pause traffic simulation
- **resume**: Resume traffic simulation
- **reload**: Reload URL configuration

## Troubleshooting in ROOT MODE

If issues persist even in ROOT MODE:

1. **Verify Root Access**: Ensure devices truly have root access and the su binary is available
2. **Check App Installation**: Confirm the IMadeThatBitchFamous app is properly installed
3. **Inspect Logs**: Check Drono Lite logs and device logcat for errors
4. **Check Device Status**: Use `adb devices -l` to verify device connection status
5. **Test Direct Commands**: Try manual su commands through adb shell to verify root functionality

## Implementation Details

The ADB controller uses multiple techniques to ensure settings are applied correctly:

1. **XML Preference Files**: Direct manipulation of app preference files
2. **Intent Command Chain**: Multiple intents to ensure settings are applied
3. **Broadcast Commands**: Standard Android broadcast mechanism
4. **Deep Linking**: URI scheme linking for additional compatibility

## Security Considerations

ROOT MODE requires devices to have root access enabled, which has security implications:

- Devices have unrestricted system access
- Device security may be compromised
- This mode should only be used in controlled environments

## Additional Notes

- The server automatically logs all operations in ROOT MODE
- All devices are assumed to have root access
- Operations that would normally require permission checks are bypassed
- This approach is designed for maximum compatibility with problematic devices 