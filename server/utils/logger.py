import logging
import os
import sys
from pathlib import Path
from logging.handlers import RotatingFileHandler

from config.settings import LOG_LEVEL, LOG_FILE

def setup_logging():
    """Configure logging for the application"""
    # Create logs directory if it doesn't exist
    log_dir = os.path.dirname(LOG_FILE)
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(LOG_LEVEL)
    
    # Clear any existing handlers to avoid duplicate logs
    if root_logger.handlers:
        root_logger.handlers.clear()
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    console_handler.setLevel(LOG_LEVEL)
    root_logger.addHandler(console_handler)
    
    # File handler with rotation (max 10MB per file, keep 5 backup files)
    file_handler = RotatingFileHandler(
        LOG_FILE,
        maxBytes=10*1024*1024,
        backupCount=5
    )
    file_handler.setFormatter(formatter)
    file_handler.setLevel(LOG_LEVEL)
    root_logger.addHandler(file_handler)
    
    # Suppress noisy loggers
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    
    logging.info(f"Logging initialized at level {LOG_LEVEL}")
    logging.info(f"Log file: {LOG_FILE}")
    
    return root_logger 