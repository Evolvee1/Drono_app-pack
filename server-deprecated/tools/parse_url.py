#!/usr/bin/env python3
"""
URL Parser utility for safely handling URLs with special characters
"""
import sys
import urllib.parse
import argparse

def escape_url_for_shell(url):
    """Escape a URL to make it safe for shell command execution"""
    # First, make sure the URL is properly parsed and encoded
    parsed = urllib.parse.urlparse(url)
    
    # Re-encode any components that might have special characters
    safe_parts = []
    safe_parts.append(parsed.scheme)
    safe_parts.append('://')
    safe_parts.append(parsed.netloc)
    safe_parts.append(parsed.path)
    
    # Handle query parameters carefully
    if parsed.query:
        safe_parts.append('?')
        safe_parts.append(parsed.query.replace('&', '\&'))
    
    # Handle fragments
    if parsed.fragment:
        safe_parts.append('#')
        safe_parts.append(parsed.fragment)
    
    return ''.join(safe_parts)

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Escape URLs for shell usage')
    parser.add_argument('url', help='The URL to escape')
    return parser.parse_args()

def main():
    """Main entry point"""
    args = parse_arguments()
    escaped_url = escape_url_for_shell(args.url)
    print(escaped_url)
    return 0

if __name__ == '__main__':
    sys.exit(main()) 