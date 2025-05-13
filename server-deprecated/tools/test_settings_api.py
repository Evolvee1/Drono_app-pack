import argparse
import requests

API_BASE_URL = "http://localhost:8000"  # Replace with your API base URL

def direct_url_command(
    url, 
    devices=None, 
    all_devices=False, 
    iterations=1000,
    min_interval=1,
    max_interval=2,
    webview_mode=True,
    rotate_ip=True,
    random_devices=True,
    new_webview_per_request=True,
    restore_on_exit=False,
    use_proxy=False,
    proxy_address="",
    proxy_port=0,
    parallel=True
):
    """Set URL with maximum compatibility using the direct-url endpoint"""
    if not url:
        print("Error: URL is required for direct URL command")
        return
    
    if not devices and not all_devices:
        print("Error: Either specify devices with --devices or use --all-devices")
        return
    
    target_devices = []
    if all_devices:
        print("Getting all connected devices...")
        response = requests.get(f"{API_BASE_URL}/devices")
        if response.status_code == 200:
            data = response.json()
            target_devices = [device["id"] for device in data["devices"]]
        else:
            print(f"Error: Failed to get devices: {response.status_code}")
            return
    else:
        target_devices = devices
    
    print(f"Setting URL directly on {target_devices} using direct command:")
    print(f"URL: {url}")
    print(f"Iterations: {iterations}")
    print(f"Min Interval: {min_interval}s, Max Interval: {max_interval}s")
    print(f"Webview mode: {webview_mode}")
    print(f"Rotate IP: {rotate_ip}")
    print(f"Random devices: {random_devices}")
    print(f"New webview per request: {new_webview_per_request}")
    print(f"Restore on exit: {restore_on_exit}")
    if use_proxy:
        print(f"Using proxy: {proxy_address}:{proxy_port}")
    
    payload = {
        "url": url,
        "devices": devices if not all_devices else None,
        "all_devices": all_devices,
        "iterations": iterations,
        "min_interval": min_interval,
        "max_interval": max_interval,
        "webview_mode": webview_mode,
        "rotate_ip": rotate_ip,
        "random_devices": random_devices,
        "new_webview_per_request": new_webview_per_request,
        "restore_on_exit": restore_on_exit,
        "use_proxy": use_proxy,
        "proxy_address": proxy_address,
        "proxy_port": proxy_port,
        "parallel": parallel
    }
    
    response = requests.post(f"{API_BASE_URL}/direct-url", json=payload)
    
    if response.status_code == 200:
        data = response.json()
        print(f"Status: {data['status']}")
        print(f"Applied to {data['count']} devices")
        
        if 'success_count' in data:
            print(f"Success count: {data['success_count']}")
        
        if 'results' in data:
            print("\nDetailed results:")
            for device_id, result in data['results'].items():
                status = result['status']
                status_icon = "✅" if status == "success" else "⚠️" if status == "possible_success" else "❌"
                print(f"{status_icon} {device_id}: {status}")
                
                # Show details with verbose flag
                if args.verbose and 'details' in result:
                    print(f"  Details: {result['details'][:100]}...")
    else:
        print(f"Error: {response.status_code}")
        print(response.text)

# ... existing code ...

# Update the cmd_parser in parse_args()
def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Test script for the Settings API')
    
    # Global options
    parser.add_argument('--verbose', '-v', action='store_true', help='Show verbose output')
    
    # Create subparsers for different commands
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # List devices command
    list_parser = subparsers.add_parser('list', help='List all connected devices')
    
    # Apply settings command
    apply_parser = subparsers.add_parser('apply', help='Apply settings to devices')
    apply_parser.add_argument('--url', required=True, help='Target URL')
    device_group = apply_parser.add_mutually_exclusive_group(required=True)
    device_group.add_argument('--all-devices', action='store_true', help='Apply to all connected devices')
    device_group.add_argument('--devices', nargs='+', help='Specific device IDs to target')
    apply_parser.add_argument('--parallel', action='store_true', help='Apply settings in parallel')
    
    # Instagram-specific settings command
    instagram_parser = subparsers.add_parser('instagram', help='Apply Instagram-specific settings')
    instagram_parser.add_argument('--url', required=True, help='Instagram URL (handles complex URLs better)')
    insta_device_group = instagram_parser.add_mutually_exclusive_group(required=True)
    insta_device_group.add_argument('--all-devices', action='store_true', help='Apply to all connected devices')
    insta_device_group.add_argument('--devices', nargs='+', help='Specific device IDs to target')
    instagram_parser.add_argument('--parallel', action='store_true', help='Apply settings in parallel')
    
    # Direct URL setting command - uses compatibility approach via Instagram endpoint 
    direct_parser = subparsers.add_parser('direct', help='Set URL directly with compatibility layer')
    direct_parser.add_argument('--url', required=True, help='Target URL to set')
    direct_device_group = direct_parser.add_mutually_exclusive_group(required=True)
    direct_device_group.add_argument('--all-devices', action='store_true', help='Apply to all connected devices')
    direct_device_group.add_argument('--devices', nargs='+', help='Specific device IDs to target')
    direct_parser.add_argument('--parallel', action='store_true', help='Apply settings in parallel')
    
    # Maximum compatibility command - uses direct URL command
    cmd_parser = subparsers.add_parser('cmd', help='Set URL with maximum compatibility (recommended)')
    cmd_parser.add_argument('--url', required=True, help='Target URL to set')
    cmd_device_group = cmd_parser.add_mutually_exclusive_group(required=True)
    cmd_device_group.add_argument('--all-devices', action='store_true', help='Apply to all connected devices')
    cmd_device_group.add_argument('--devices', nargs='+', help='Specific device IDs to target')
    cmd_parser.add_argument('--iterations', type=int, default=1000, help='Number of iterations to run')
    cmd_parser.add_argument('--min-interval', type=int, default=1, help='Minimum interval between requests (seconds)')
    cmd_parser.add_argument('--max-interval', type=int, default=2, help='Maximum interval between requests (seconds)')
    cmd_parser.add_argument('--webview-mode', action='store_true', default=True, help='Use webview mode')
    cmd_parser.add_argument('--no-webview-mode', dest='webview_mode', action='store_false', help='Disable webview mode')
    cmd_parser.add_argument('--rotate-ip', action='store_true', default=True, help='Rotate IP between requests')
    cmd_parser.add_argument('--no-rotate-ip', dest='rotate_ip', action='store_false', help='Disable IP rotation')
    cmd_parser.add_argument('--random-devices', action='store_true', default=True, help='Use random device profiles')
    cmd_parser.add_argument('--no-random-devices', dest='random_devices', action='store_false', help='Disable random device profiles')
    cmd_parser.add_argument('--new-webview-per-request', action='store_true', default=True, help='Create new webview for each request')
    cmd_parser.add_argument('--no-new-webview-per-request', dest='new_webview_per_request', action='store_false', help='Disable new webview per request')
    cmd_parser.add_argument('--restore-on-exit', action='store_true', default=False, help='Restore IP on exit')
    cmd_parser.add_argument('--no-restore-on-exit', dest='restore_on_exit', action='store_false', help='Do not restore IP on exit')
    cmd_parser.add_argument('--use-proxy', action='store_true', default=False, help='Use proxy for connections')
    cmd_parser.add_argument('--proxy-address', type=str, default='', help='Proxy server address')
    cmd_parser.add_argument('--proxy-port', type=int, default=0, help='Proxy server port')
    cmd_parser.add_argument('--parallel', action='store_true', default=True, help='Apply settings in parallel')
    cmd_parser.add_argument('--sequential', dest='parallel', action='store_false', help='Apply settings sequentially')
    
    # Help command
    help_parser = subparsers.add_parser('help', help='Show help guide')
    
    return parser.parse_args()

# ... existing code ...

def main():
    """Main function."""
    global args
    args = parse_args()
    
    if args.command == 'list':
        list_devices()
    elif args.command == 'apply':
        apply_settings(args.url, args.devices, args.all_devices, args.parallel)
    elif args.command == 'instagram':
        instagram_settings(args.url, args.devices, args.all_devices, args.parallel)
    elif args.command == 'direct':
        direct_url_setting(args.url, args.devices, args.all_devices, args.parallel)
    elif args.command == 'cmd':
        direct_url_command(
            args.url, 
            args.devices, 
            args.all_devices, 
            args.iterations,
            args.min_interval,
            args.max_interval,
            args.webview_mode,
            args.rotate_ip,
            args.random_devices,
            args.new_webview_per_request,
            args.restore_on_exit,
            args.use_proxy,
            args.proxy_address,
            args.proxy_port,
            args.parallel
        )
    elif args.command == 'help':
        show_help_guide()
    else:
        print("Error: No command specified")
        show_help_guide()
        return 1
    
    return 0