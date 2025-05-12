# Setup Guide for ADB Settings Management Solution

This document provides detailed instructions on how to set up and configure the ADB Settings Management Solution for Instagram traffic simulations.

## Prerequisites

- Python 3.6 or higher
- ADB (Android Debug Bridge) installed and properly configured
- Connected Android devices with USB debugging enabled
- Network connectivity between server and devices

## Installation Steps

### 1. Install Required Packages

```bash
pip install fastapi uvicorn[standard] pydantic requests
```

### 2. Configure ADB for Connected Devices

Ensure that all devices are properly connected and detected by ADB:

```bash
adb devices
```

This should list all connected devices. If you don't see your devices, check the USB connection and ensure that USB debugging is enabled on each device.

### 3. Confirm Application Installation

Ensure that the target application (`com.example.imtbf.debug`) is installed on all target devices. You can check this with:

```bash
adb -s <device_id> shell pm list packages | grep imtbf
```

### 4. Set Up Directory Structure

Create the necessary directory structure if not already exists:

```bash
mkdir -p server/tools/logs
```

### 5. Make the Shell Scripts Executable

```bash
chmod +x server/tools/direct_url_command.sh
chmod +x server/tools/enhanced_insta_sim.sh
chmod +x server/tools/direct_url_setter.sh
```

## Starting the Services

### 1. Start the Settings API Server

```bash
cd server/tools
python settings_api_server.py
```

The server will be available at http://localhost:8000.

### 2. Test API Connectivity

You can test connectivity to the API by opening the following URL in your browser:

```
http://localhost:8000
```

You should see a JSON response indicating the server is running.

### 3. Use the Test Client

The test client script can be used to interact with the API:

```bash
python test_settings_api.py list  # List connected devices
```

## Configuration Reference

### Server Configuration

The settings API server uses the following default configuration:

- Host: 0.0.0.0 (available on all network interfaces)
- Port: 8000
- Logs Directory: server/tools/logs

### Client Configuration

The test_settings_api.py script connects to the server at:

- API Base URL: http://localhost:8000

To change this, modify the `API_BASE_URL` variable in the script.

## Troubleshooting

### Common Issues

1. **Devices Not Detected**
   - Ensure USB debugging is enabled on the device
   - Try different USB cables
   - Restart ADB server: `adb kill-server && adb start-server`

2. **Permission Issues**
   - Ensure the shell scripts are executable
   - On some systems, you may need to run the server with appropriate permissions

3. **URL Setting Fails**
   - Check that the device is properly connected
   - Verify that the application is installed and running
   - Try using the direct URL command with the `cmd` option for maximum compatibility

4. **Server Fails to Start**
   - Check that required packages are installed
   - Verify that port 8000 is not in use by another application

## Next Steps

Once the setup is complete, refer to the [API Documentation](api.md) for information on how to use the API endpoints, and the [Architecture Overview](architecture.md) for details on how the solution works.
