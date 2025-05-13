# Drono Lite Installation Guide

This guide provides step-by-step instructions for installing and running the Drono Lite control server.

## Prerequisites

- Python 3.8 or higher
- ADB (Android Debug Bridge) installed and in PATH
- Android devices with:
  - USB debugging enabled
  - Root access enabled
  - IMadeThatBitchFamous app installed

## Installation Steps

### 1. Install Python Dependencies

```bash
# Create and activate a virtual environment
# Windows
python -m venv venv
venv\Scripts\activate

# Linux/macOS
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Verify ADB Installation

Ensure ADB is properly installed and accessible:

```bash
adb version
```

You should see output similar to:
```
Android Debug Bridge version 1.0.41
Version 31.0.3-7562133
```

### 3. Connect Devices

1. Enable USB debugging on all devices
2. Enable root access on all devices
3. Connect devices via USB
4. Verify connections:

```bash
adb devices -l
```

You should see your devices listed as "device" status.

### 4. Verify ROOT Access

For each device, check that root access works:

```bash
adb -s <DEVICE_ID> shell su -c "id"
```

You should see output containing `uid=0(root)`.

## Starting the Server

### Windows

```bash
# Navigate to the drono_lite directory
cd drono_lite

# Start the server using the batch script
start_server.bat
```

### Linux/macOS

```bash
# Navigate to the drono_lite directory
cd drono_lite

# Make the start script executable
chmod +x start_server.sh

# Start the server
./start_server.sh
```

## Manual Server Start

If the start scripts don't work, you can start the server manually:

```bash
# Activate virtual environment (if not already activated)
# Windows
venv\Scripts\activate
# Linux/macOS
source venv/bin/activate

# Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Accessing the Dashboard

Once the server is running, open your browser and navigate to:

```
http://localhost:8000
```

## Troubleshooting

### Server Won't Start

If you see an error like `The term 'uvicorn' is not recognized`, ensure:

1. Your virtual environment is activated
2. Dependencies are installed in the active environment:
   ```bash
   pip install -r requirements.txt
   ```

### Devices Not Detected

If devices aren't appearing in the dashboard:

1. Check physical USB connections
2. Ensure USB debugging is enabled
3. Accept any USB debugging prompts on the device
4. Verify with `adb devices -l` that devices are connected
5. Restart ADB server:
   ```bash
   adb kill-server
   adb start-server
   ```

### Permission Issues

If ROOT MODE isn't working properly:

1. Verify devices have root access
2. Check that the su binary is available and functioning
3. Make sure the device has granted su permissions to ADB
4. Verify the app package is correctly installed:
   ```bash
   adb -s <DEVICE_ID> shell pm list packages | grep imtbf
   ```

## Getting Help

Check the server logs for detailed error information:
```
drono_lite/drono_lite.log
``` 