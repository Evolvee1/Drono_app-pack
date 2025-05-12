#!/usr/bin/env python3
import subprocess
import shlex
import sys
import os
import argparse
import threading


def run_on_device(device_id, args, results, idx):
    env = dict(os.environ)
    env["ADB_DEVICE_ID"] = device_id
    # Use the args as-is, preserving quoting for complex values
    cmd = ["./android-app/drono_control.sh"] + args
    print(f"[Device {device_id}] Running: {' '.join(shlex.quote(a) for a in cmd)}")
    result = subprocess.run(cmd, env=env, capture_output=True, text=True)
    results[idx] = (device_id, result.returncode, result.stdout, result.stderr)


def main():
    parser = argparse.ArgumentParser(description="Batch Drono Control Dispatcher")
    parser.add_argument("--devices", nargs="+", required=True, help="Device IDs to target")
    parser.add_argument("--args", nargs=argparse.REMAINDER, required=True, help="Arguments for drono_control.sh (quote as needed)")
    args = parser.parse_args()

    threads = []
    results = [None] * len(args.devices)
    for idx, device in enumerate(args.devices):
        t = threading.Thread(target=run_on_device, args=(device, args.args, results, idx))
        t.start()
        threads.append(t)
    for t in threads:
        t.join()

    print("\n=== Batch Results ===")
    for device_id, code, out, err in results:
        print(f"\n[Device {device_id}] Return code: {code}")
        print(f"[Device {device_id}] STDOUT:\n{out.strip()}")
        if err.strip():
            print(f"[Device {device_id}] STDERR:\n{err.strip()}")

if __name__ == "__main__":
    main() 
 