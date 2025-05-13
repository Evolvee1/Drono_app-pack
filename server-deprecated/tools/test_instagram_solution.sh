#!/bin/bash
# Test script for Instagram Manager solution

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"
TEST_SCRIPT="$SCRIPT_DIR/test_instagram_manager.py"
CLI_SCRIPT="$SCRIPT_DIR/instagram_cli.py"

# Make scripts executable
chmod +x "$TEST_SCRIPT" 2>/dev/null
chmod +x "$CLI_SCRIPT" 2>/dev/null

# Create temp and logs directories if they don't exist
mkdir -p "$SERVER_DIR/temp" 2>/dev/null
mkdir -p "$SCRIPT_DIR/logs" 2>/dev/null

# ASCII art banner
echo "
╭───────────────────────────────────────╮
│  Instagram Manager Solution Test       │
│                                       │
│  A unified approach to setting         │
│  complex Instagram URLs on devices     │
╰───────────────────────────────────────╯
"

# Step 1: Print connected devices
echo "=== Step 1: Checking Connected Devices ==="
echo ""
python3 "$CLI_SCRIPT" list
echo ""

# Step 2: Run the test script
echo "=== Step 2: Running Comprehensive Tests ==="
echo ""
python3 "$TEST_SCRIPT"
TEST_RESULT=$?
echo ""

# Step 3: Try setting a real Instagram URL
echo "=== Step 3: Setting Real Instagram URL ==="
echo ""
python3 "$CLI_SCRIPT" set-url --url "https://www.instagram.com/p/real-test-url-$(date +%s)" --iterations 10
URL_RESULT=$?
echo ""

# Step 4: Show summary
echo "=== Test Summary ==="
if [ $TEST_RESULT -eq 0 ]; then
  echo "✅ Core functionality test: PASSED"
else
  echo "❌ Core functionality test: FAILED"
fi

if [ $URL_RESULT -eq 0 ]; then
  echo "✅ Instagram URL setting: PASSED"
else
  echo "❌ Instagram URL setting: FAILED"
fi

# Final result
if [ $TEST_RESULT -eq 0 ] && [ $URL_RESULT -eq 0 ]; then
  echo ""
  echo "🎉 All tests PASSED! The Instagram Manager solution is working correctly."
  exit 0
else
  echo ""
  echo "⚠️ Some tests FAILED. Please check the output for details."
  exit 1
fi 