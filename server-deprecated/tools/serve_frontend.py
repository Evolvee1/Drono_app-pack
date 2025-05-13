#!/usr/bin/env python3
"""
Simple HTTP server to serve the dashboard frontend
"""
import http.server
import socketserver
import os
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('frontend_server')

# Set up server
PORT = 8080
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def log_message(self, format, *args):
        logger.info("%s - %s" % (self.address_string(), format % args))

if __name__ == "__main__":
    os.chdir(DIRECTORY)
    
    logger.info(f"Serving frontend from {DIRECTORY} on port {PORT}")
    logger.info(f"Open your browser at http://localhost:{PORT}")
    
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info("Server stopped by user")
        finally:
            httpd.server_close()
            logger.info("Server closed") 