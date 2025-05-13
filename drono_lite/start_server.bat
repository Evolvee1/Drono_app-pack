@echo off
title Drono Lite Control Server

REM Check if Python is installed
where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Python not found. Please install Python 3.8 or higher.
    pause
    exit /b 1
)

REM Check if ADB is installed
where adb >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ADB not found. Please install Android Debug Bridge and add it to your PATH.
    pause
    exit /b 1
)

REM Check if virtual environment exists, create if not
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment and install dependencies
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Install dependencies if needed
if not exist venv\Lib\site-packages\fastapi (
    echo Installing dependencies...
    pip install -r requirements.txt
)

REM Start the server
echo Starting Drono Lite Control Server...
echo Server will be available at http://localhost:8000
python main.py

pause 