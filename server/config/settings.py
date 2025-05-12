import os
from dotenv import load_dotenv
from pathlib import Path
import logging
import sys

# Load environment variables from .env file if it exists
load_dotenv()

# Ensure BASE_DIR is correctly defined
BASE_DIR = Path(__file__).resolve().parent.parent

# Android app directory (where drono_control.sh is located)
ANDROID_APP_DIR = os.path.join(BASE_DIR.parent, "android-app")

# Path to drono_control.sh
DRONO_CONTROL_SCRIPT = os.path.join(ANDROID_APP_DIR, "drono_control.sh")

# Server settings
SERVER_HOST = os.getenv("SERVER_HOST", "0.0.0.0")
SERVER_PORT = int(os.getenv("SERVER_PORT", 8000))
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

# Security settings
SECRET_KEY = os.getenv("SECRET_KEY", "development_secret_key_change_in_production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 60))

# ADB settings
ADB_PATH = os.getenv("ADB_PATH", "adb")  # Default to adb in PATH

# Create logs directory if it doesn't exist
logs_dir = os.path.join(BASE_DIR, "logs")
os.makedirs(logs_dir, exist_ok=True)

# Default preset configurations
PRESETS = {
    "veewoy": {
        "url": "https://veewoy.com/ip-text",
        "iterations": 500,
        "min_interval": 1,
        "max_interval": 2,
        "features": {
            "rotate_ip": True,
            "webview_mode": True,
            "random_devices": True
        }
    },
    "performance": {
        "url": "https://instagram.com",
        "iterations": 50,
        "min_interval": 3,
        "max_interval": 10,
        "features": {
            "rotate_ip": True,
            "webview_mode": False,
            "random_devices": True
        }
    },
    "stealth": {
        "url": "https://instagram.com",
        "iterations": 30,
        "min_interval": 10,
        "max_interval": 20,
        "features": {
            "rotate_ip": True,
            "webview_mode": True,
            "random_devices": True,
            "aggressive_clearing": True
        }
    }
}

# Logging configuration
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FILE = os.getenv("LOG_FILE", os.path.join(logs_dir, "server.log"))

# Configure logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
