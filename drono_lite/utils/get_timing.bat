@echo off
REM Script to get detailed timing information from Android devices

REM Check if device ID is provided
if "%~1"=="" (
  echo Usage: %0 ^<device_id^>
  echo Example: %0 R9WR310F4GJ
  exit /b 1
)

set DEVICE_ID=%~1

REM Send command to get detailed status
echo Requesting detailed timing information from device %DEVICE_ID%...
adb -s %DEVICE_ID% shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command get_detailed_status -p com.example.imtbf.debug"

REM Wait a moment for the command to be processed
timeout /t 1 > nul

REM Get the logcat output with timing information
echo Retrieving timing information from logcat...
adb -s %DEVICE_ID% shell "logcat -d -v brief -t 100 MainActivity:D AdbCommandReceiver:I | grep -E 'Time elapsed|remaining|Progress'"

REM Try to get the status.json file
echo.
echo Attempting to get status.json file...
adb -s %DEVICE_ID% shell "su -c 'cat /data/data/com.example.imtbf.debug/files/status.json'" > status.json

REM Check if we got the file
for %%A in (status.json) do set filesize=%%~zA
if %filesize% gtr 0 (
  echo.
  echo Status file content:
  type status.json
  echo.
  echo Summary:
  echo Look at the status.json file for detailed timing information.
) else (
  echo Could not retrieve status.json file. Make sure the device is rooted and the app is running.
)

REM Clean up
if exist status.json del status.json

exit /b 0 