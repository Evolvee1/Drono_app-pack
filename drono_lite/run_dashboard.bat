@echo off
echo Drono Lite Dashboard Server Launcher
echo ====================================

:: Set UTF-8 encoding for the console
chcp 65001 >nul

:: Activate virtual environment
call venv\Scripts\activate.bat

:: Check if port is specified
set PORT=8080
if not "%1"=="" (
    set PORT=%1
)

echo Starting server on port %PORT%...
echo Access the dashboard at: http://localhost:%PORT%
echo.
echo Press Ctrl+C to stop the server
echo.

:: Run the server
python -m uvicorn main:app --host 0.0.0.0 --port %PORT%

:: Deactivate virtual environment if needed
call deactivate

pause 