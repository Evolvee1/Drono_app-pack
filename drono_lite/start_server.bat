@echo off
title Drono Lite Control Server
echo Drono Lite Control Server
echo ====================================

:: Set UTF-8 encoding for the console
chcp 65001 >nul

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

:: Check if port is specified
set PORT=8000
set QUIET_MODE=
set LOG_LEVEL=

:parse_args
if "%1"=="" goto end_parse_args
if "%1"=="--port" (
    set PORT=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--quiet" (
    set QUIET_MODE=--quiet
    shift
    goto parse_args
)
if "%1"=="--log-level" (
    set LOG_LEVEL=--log-level %2
    shift
    shift
    goto parse_args
)
if "%1"=="--help" (
    echo Usage: start_server.bat [--port PORT] [--quiet] [--log-level LEVEL]
    echo.
    echo Options:
    echo   --port PORT       Set the server port (default: 8000)
    echo   --quiet           Run in quiet mode (suppresses status messages)
    echo   --log-level LEVEL Set logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    exit /b 0
)
REM Skip other unknown args
shift
goto parse_args
:end_parse_args

echo Starting server on port %PORT%...
echo Access the dashboard at: http://localhost:%PORT%
echo.
echo Press Ctrl+C to stop the server
echo.

REM Start the server with the specified port and logging options
python -m uvicorn main:app --host 0.0.0.0 --port %PORT% %QUIET_MODE% %LOG_LEVEL%

REM Deactivate virtual environment
call deactivate

pause 