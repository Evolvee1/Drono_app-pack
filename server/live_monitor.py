#!/usr/bin/env python3

"""
Drono Live Monitor - Rich terminal UI for monitoring Android device simulations
"""

import asyncio
import argparse
import re
import time
import sys
import os
from datetime import datetime, timedelta

try:
    import rich
    from rich.console import Console
    from rich.live import Live
    from rich.panel import Panel
    from rich.progress import Progress, BarColumn, TextColumn, SpinnerColumn
    from rich.table import Table
    from rich.text import Text
    from rich.layout import Layout
except ImportError:
    print("This script requires the 'rich' library. Please install it with:")
    print("pip install rich")
    sys.exit(1)

console = Console()

class DronoMonitor:
    def __init__(self, device_id=None, server_url=None, refresh_rate=0.5):
        self.device_id = device_id
        self.server_url = server_url or "http://localhost:8000"
        self.refresh_rate = refresh_rate
        self.start_time = datetime.now()
        self.last_iteration = 0
        self.iterations_per_min = 0
        self.auth_token = None
        self.username = "admin"
        self.password = "adminpassword"
        
        # Initialize ADB controller
        try:
            from core.adb_controller import AdbController
            self.adb = AdbController()
        except ImportError:
            # Create a simple ADB controller
            class SimpleAdbController:
                def __init__(self):
                    self.adb_path = "adb"
                    
                async def execute_adb_command(self, device_id, command):
                    cmd = [self.adb_path, "-s", device_id] + command
                    process = await asyncio.create_subprocess_exec(
                        *cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    stdout, stderr = await process.communicate()
                    if process.returncode != 0:
                        stderr_str = stderr.decode('utf-8', errors='replace')
                        raise RuntimeError(f"ADB command failed: {stderr_str}")
                    return stdout.decode('utf-8', errors='replace')
            
            self.adb = SimpleAdbController()
    
    async def login(self):
        """Log in to the server and get an auth token"""
        try:
            import aiohttp
            async with aiohttp.ClientSession() as session:
                data = {
                    'username': self.username,
                    'password': self.password
                }
                async with session.post(f"{self.server_url}/auth/token", data=data) as response:
                    if response.status == 200:
                        result = await response.json()
                        self.auth_token = result.get('access_token')
                        return True
                    else:
                        console.print(f"[red]Login failed: {response.status} {await response.text()}")
                        return False
        except Exception as e:
            console.print(f"[red]Login error: {e}")
            return False
    
    async def get_device_status(self):
        """Get device status from the server"""
        try:
            if not self.auth_token:
                if not await self.login():
                    return None
            
            import aiohttp
            headers = {"Authorization": f"Bearer {self.auth_token}"}
            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(f"{self.server_url}/devices/{self.device_id}/status") as response:
                    if response.status == 200:
                        return await response.json()
                    elif response.status == 401:
                        # Token expired, try to login again
                        if await self.login():
                            return await self.get_device_status()
                    else:
                        console.print(f"[yellow]Server status check failed: {response.status}")
                        return None
        except Exception as e:
            # Fall back to ADB if server fails
            console.print(f"[yellow]Server error: {e}")
            return None
    
    async def get_progress_from_logcat(self):
        """Get progress directly from logcat"""
        try:
            # Try to get the current progress from logcat
            logcat_output = await self.adb.execute_adb_command(
                self.device_id, 
                ["logcat", "-d", "-t", "30", "|", "grep", "Progress:"]
            )
            
            # Look for patterns like "Progress: 5/100"
            progress_matches = re.findall(r"Progress: (\d+)/(\d+)", logcat_output)
            if progress_matches:
                current = int(progress_matches[-1][0])  # Get the most recent match
                total = int(progress_matches[-1][1])
                return {
                    "current_iteration": current,
                    "iterations": total,
                    "is_running": True
                }
        except Exception as e:
            console.print(f"[yellow]Logcat error: {e}")
        
        return None

    async def get_combined_status(self):
        """Get combined status from server and logcat"""
        # First try server for complete info
        server_status = await self.get_device_status()
        
        # Then try logcat for most up-to-date progress
        logcat_progress = await self.get_progress_from_logcat()
        
        if server_status:
            # We have server status, check if we should update with logcat data
            device_info = server_status.get("device", {})
            sim_info = server_status.get("simulation", {})
            
            if logcat_progress and logcat_progress["current_iteration"] > sim_info.get("current_iteration", 0):
                # Logcat has newer data, update simulation info
                sim_info.update(logcat_progress)
                server_status["simulation"] = sim_info
            
            return server_status
        elif logcat_progress:
            # No server data but we have logcat data
            return {
                "device": {
                    "id": self.device_id,
                    "running": True,
                    "current_iteration": logcat_progress["current_iteration"],
                    "last_updated": datetime.now().isoformat()
                },
                "simulation": logcat_progress
            }
        
        # No data from either source
        return None
    
    def create_dashboard(self, status):
        """Create a rich dashboard for displaying device status"""
        layout = Layout()
        
        # Main header
        header = Panel(
            Text(f"Drono Live Monitor - Device: {self.device_id}", style="bold white"),
            style="blue"
        )
        
        # Device info section
        device_info = status.get("device", {})
        sim_info = status.get("simulation", {})
        
        is_running = device_info.get("running", False) or sim_info.get("is_running", False)
        status_color = "green" if is_running else "red"
        status_text = "RUNNING" if is_running else "STOPPED"
        
        device_table = Table(show_header=False, box=rich.box.SIMPLE)
        device_table.add_column("Property")
        device_table.add_column("Value")
        
        device_table.add_row("Status", f"[{status_color}]{status_text}[/{status_color}]")
        device_table.add_row("Model", device_info.get("model", "Unknown"))
        device_table.add_row("Last Updated", 
                            datetime.fromisoformat(device_info.get("last_updated", datetime.now().isoformat()))
                            .strftime("%H:%M:%S"))
        
        if "url" in sim_info:
            device_table.add_row("URL", sim_info.get("url", ""))
        
        device_panel = Panel(device_table, title="Device Information", style="cyan")
        
        # Progress section
        if is_running:
            current = sim_info.get("current_iteration", 0) or device_info.get("current_iteration", 0)
            total = sim_info.get("iterations", 1000)
            
            if current > 0 and total > 0:
                percentage = round((current / total) * 100, 1)
                
                # Calculate elapsed time
                elapsed = (datetime.now() - self.start_time).total_seconds()
                
                # Calculate iterations per minute
                if self.last_iteration > 0 and current > self.last_iteration:
                    iter_diff = current - self.last_iteration
                    time_diff_min = elapsed / 60
                    if time_diff_min > 0:
                        self.iterations_per_min = iter_diff / time_diff_min
                
                # Update last iteration
                self.last_iteration = current
                
                # Create progress bar
                progress = Progress(
                    SpinnerColumn(),
                    TextColumn("[bold blue]{task.description}"),
                    BarColumn(bar_width=40),
                    TextColumn("[bold]{task.percentage:.1f}%"),
                    TextColumn("[bold]{task.fields[current]}/{task.fields[total]}")
                )
                
                task_id = progress.add_task("Progress", total=total, completed=current, 
                                          current=current, total=total)
                
                # Time remaining calculation
                time_info = Table(show_header=False, box=rich.box.SIMPLE)
                time_info.add_column("Metric")
                time_info.add_column("Value")
                
                elapsed_formatted = str(timedelta(seconds=int(elapsed)))
                time_info.add_row("Elapsed Time", elapsed_formatted)
                
                if self.iterations_per_min > 0:
                    time_info.add_row("Current Pace", f"{self.iterations_per_min:.1f} iterations/minute")
                    
                    # Calculate remaining time
                    remaining_iterations = total - current
                    remaining_minutes = remaining_iterations / self.iterations_per_min
                    remaining_seconds = remaining_minutes * 60
                    
                    remaining_formatted = str(timedelta(seconds=int(remaining_seconds)))
                    time_info.add_row("Est. Remaining", remaining_formatted)
                    
                    # Calculate completion time
                    completion_time = datetime.now() + timedelta(seconds=remaining_seconds)
                    time_info.add_row("Est. Completion", completion_time.strftime("%H:%M:%S"))
                
                progress_panel = Panel(progress, title="Simulation Progress", style="green")
                timing_panel = Panel(time_info, title="Timing Information", style="magenta")
                
                # Recent logs
                logs_panel = self.create_logs_panel()
                
                # Layout everything
                layout.split(
                    Layout(header, size=3),
                    Layout(device_panel, size=8),
                    Layout(progress_panel, size=5),
                    Layout(timing_panel, size=8),
                    Layout(logs_panel)
                )
            else:
                # Running but no progress data yet
                waiting_text = Text("Waiting for progress data...", style="yellow")
                progress_panel = Panel(waiting_text, title="Simulation Progress", style="yellow")
                
                # Layout with minimal info
                layout.split(
                    Layout(header, size=3),
                    Layout(device_panel, size=8),
                    Layout(progress_panel, size=5),
                    Layout(self.create_logs_panel())
                )
        else:
            # Not running
            status_text = Text("No active simulation", style="red")
            status_panel = Panel(status_text, title="Status", style="red")
            
            # Layout with minimal info
            layout.split(
                Layout(header, size=3),
                Layout(device_panel, size=8),
                Layout(status_panel, size=5),
                Layout(self.create_logs_panel())
            )
        
        return layout
    
    def create_logs_panel(self):
        """Create a panel with recent logs"""
        try:
            # Get most recent logcat entries
            logcat_cmd = f"adb -s {self.device_id} logcat -d -t 10"
            logs = os.popen(logcat_cmd).read().strip().split('\n')
            
            log_table = Table(show_header=False, box=rich.box.SIMPLE, expand=True)
            log_table.add_column("Log", ratio=1)
            
            for log in logs[-5:]:  # Show last 5 lines
                log_table.add_row(log)
            
            return Panel(log_table, title="Recent Logs", style="dim")
        except Exception as e:
            error_text = Text(f"Error getting logs: {e}", style="red")
            return Panel(error_text, title="Recent Logs", style="dim red")
    
    async def monitor(self):
        """Main monitoring loop with rich UI"""
        console.clear()
        console.print("[bold blue]Starting Drono monitoring...[/bold blue]")
        
        # Auto-detect device if not specified
        if not self.device_id:
            try:
                devices_cmd = "adb devices"
                devices_output = os.popen(devices_cmd).read()
                device_lines = devices_output.strip().split('\n')[1:]
                
                for line in device_lines:
                    parts = line.strip().split('\t')
                    if len(parts) == 2 and parts[1] == 'device':
                        self.device_id = parts[0]
                        break
                
                if not self.device_id:
                    console.print("[bold red]No devices found. Please connect a device or specify device ID.[/bold red]")
                    return
                
                console.print(f"[green]Auto-detected device: {self.device_id}[/green]")
            except Exception as e:
                console.print(f"[bold red]Error finding devices: {e}[/bold red]")
                return
        
        # Try to clear logcat
        try:
            await self.adb.execute_adb_command(self.device_id, ["logcat", "-c"])
            console.print("[green]Cleared logcat buffer[/green]")
        except Exception as e:
            console.print(f"[yellow]Failed to clear logcat: {e}[/yellow]")
        
        # Start monitoring
        with Live(console=console, screen=True, refresh_per_second=4) as live:
            while True:
                try:
                    status = await self.get_combined_status()
                    
                    if status:
                        dashboard = self.create_dashboard(status)
                        live.update(dashboard)
                    else:
                        # No status data - show error
                        error_text = Text("No status data available. Retrying...", style="red")
                        live.update(Panel(error_text, style="red"))
                    
                    await asyncio.sleep(self.refresh_rate)
                except KeyboardInterrupt:
                    console.print("[bold yellow]Monitoring stopped by user[/bold yellow]")
                    break
                except Exception as e:
                    console.print(f"[bold red]Error: {e}[/bold red]")
                    await asyncio.sleep(2)  # Longer delay on error

async def main():
    parser = argparse.ArgumentParser(description="Drono Live Monitor - Rich terminal UI for monitoring Android simulations")
    parser.add_argument("-d", "--device", help="Device ID to monitor")
    parser.add_argument("-s", "--server", help="Server URL (default: http://localhost:8000)")
    parser.add_argument("-r", "--refresh", type=float, default=0.5, help="Refresh rate in seconds (default: 0.5)")
    args = parser.parse_args()
    
    monitor = DronoMonitor(
        device_id=args.device,
        server_url=args.server,
        refresh_rate=args.refresh
    )
    
    await monitor.monitor()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        console.print("[bold yellow]Monitoring stopped by user[/bold yellow]")
    except Exception as e:
        console.print(f"[bold red]Error: {e}[/bold red]") 