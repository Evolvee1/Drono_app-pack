#!/bin/bash
# Installation script for the improved Device Settings API

# Exit on error
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
BACKUP_DIR="$SCRIPT_DIR/backup_$(date +%Y%m%d%H%M%S)"

echo "=== Improved Device Settings API Installation ==="
echo ""

# Check Python version
echo "Checking Python version..."
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 7 ]); then
  echo "Error: Python 3.7+ is required (found $PYTHON_VERSION)"
  echo "Please upgrade your Python installation"
  exit 1
fi

echo "✅ Python $PYTHON_VERSION detected"

# Install required packages
echo ""
echo "Installing required packages..."
pip3 install --quiet fastapi uvicorn pydantic requests
echo "✅ Packages installed successfully"

# Create log directory if it doesn't exist
echo ""
echo "Setting up directories..."
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"
echo "✅ Directories created"

# Backup existing files
echo ""
echo "Backing up existing files..."
if [ -f "$SCRIPT_DIR/settings_api_server.py" ]; then
  cp "$SCRIPT_DIR/settings_api_server.py" "$BACKUP_DIR/"
  echo "- Backed up settings_api_server.py"
fi

if [ -f "$SCRIPT_DIR/test_settings_api.py" ]; then
  cp "$SCRIPT_DIR/test_settings_api.py" "$BACKUP_DIR/"
  echo "- Backed up test_settings_api.py"
fi
echo "✅ Backup completed to $BACKUP_DIR"

# Verify that all new files exist
echo ""
echo "Verifying new API files..."
if [ ! -f "$SCRIPT_DIR/unified_command_api.py" ] || \
   [ ! -f "$SCRIPT_DIR/improved_settings_api.py" ] || \
   [ ! -f "$SCRIPT_DIR/improved_test_api.py" ]; then
  echo "Error: One or more required files are missing"
  echo "Please ensure the following files exist in $SCRIPT_DIR:"
  echo "- unified_command_api.py"
  echo "- improved_settings_api.py"
  echo "- improved_test_api.py"
  exit 1
fi
echo "✅ All required files are present"

# Make scripts executable
echo ""
echo "Setting file permissions..."
chmod +x "$SCRIPT_DIR/unified_command_api.py"
chmod +x "$SCRIPT_DIR/improved_settings_api.py"
chmod +x "$SCRIPT_DIR/improved_test_api.py"
echo "✅ File permissions set"

# Create symbolic links (optional)
echo ""
echo "Creating symbolic links for convenience..."
ln -sf "$SCRIPT_DIR/improved_settings_api.py" "$SCRIPT_DIR/settings_api.py"
ln -sf "$SCRIPT_DIR/improved_test_api.py" "$SCRIPT_DIR/test_api.py"
echo "✅ Symbolic links created"

# Verify device connectivity
echo ""
echo "Checking device connectivity..."
ADB_DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l)
if [ "$ADB_DEVICES" -eq 0 ]; then
  echo "⚠️ Warning: No Android devices detected"
  echo "Please connect at least one device to test the API"
else
  echo "✅ Detected $ADB_DEVICES connected device(s)"
fi

# Installation complete
echo ""
echo "=== Installation Complete ==="
echo ""
echo "To start the API server:"
echo "python3 $SCRIPT_DIR/improved_settings_api.py"
echo ""
echo "To test the API:"
echo "python3 $SCRIPT_DIR/improved_test_api.py list"
echo ""
echo "For more information, see:"
echo "- $SCRIPT_DIR/IMPROVED_API_README.md"
echo "- $SCRIPT_DIR/MIGRATION_GUIDE.md"
echo ""
echo "Thank you for installing the improved Device Settings API!"
echo "==============================================="

# Ask if user wants to start the server now
read -p "Would you like to start the API server now? (y/n): " START_SERVER
if [[ $START_SERVER == "y" || $START_SERVER == "Y" ]]; then
  echo "Starting the API server..."
  python3 "$SCRIPT_DIR/improved_settings_api.py"
fi 