#!/usr/bin/env python3
"""
Fleet Operations Health Checker
Target: Bare-Metal Linux Home Server
Description: Operational tooling written in Python to programmatically verify
             systemd service health, Docker container states, and critical
             storage mount points across the fleet. Reduces manual intervention
             by integrating into CI/CD or cron for automated incident detection.
"""

import subprocess
import sys
import os
from typing import List, Dict

# Fleet requirements
REQUIRED_SERVICES = ['sshd', 'docker', 'hardware-telemetry']
CRITICAL_MOUNTS = ['/']  # In production, this might include ['/mnt/oracle_data', '/var/lib/docker']
REQUIRED_CONTAINERS = ['homelab-prometheus', 'homelab-grafana', 'homelab-ingress-proxy']


def run_cmd(cmd: List[str]) -> str:
    """Helper to run shell commands safely and return output."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def check_systemd_services() -> bool:
    print("[*] Checking Systemd Service Health...")
    all_healthy = True
    for service in REQUIRED_SERVICES:
        status = run_cmd(['systemctl', 'is-active', service])
        if status == 'active':
            print(f"  [+] {service}.service is running.")
        else:
            print(f"  [-] {service}.service is OFFLINE or missing!")
            all_healthy = False
    return all_healthy


def check_docker_containers() -> bool:
    print("\n[*] Checking Docker Container Fleet State...")
    if not run_cmd(['command', '-v', 'docker']):
        print("  [?] Docker not installed. Skipping container check.")
        return True

    all_healthy = True
    running_containers = run_cmd(['docker', 'ps', '--format', '{{.Names}}']).split('\n')

    for container in REQUIRED_CONTAINERS:
        if container in running_containers:
            print(f"  [+] Container '{container}' is running.")
        else:
            print(f"  [-] Container '{container}' is NOT running!")
            all_healthy = False
    return all_healthy


def check_storage_mounts() -> bool:
    print("\n[*] Checking Critical Storage Mounts & Capacity...")
    all_healthy = True
    df_output = run_cmd(['df', '-h']).split('\n')

    # Parse df output (lazy parsing for demo purposes)
    mount_map: Dict[str, str] = {}
    for line in df_output[1:]:
        parts = line.split()
        if len(parts) >= 6:
            mount_point = parts[5]
            usage_pct = parts[4].replace('%', '')
            mount_map[mount_point] = usage_pct

    for mount in CRITICAL_MOUNTS:
        if mount in mount_map:
            usage = int(mount_map[mount])
            if usage > 90:
                print(f"  [-] WARNING: Mount '{mount}' is critically full at {usage}%!")
                all_healthy = False
            else:
                print(f"  [+] Mount '{mount}' is healthy ({usage}% used).")
        else:
            print(f"  [-] ERROR: Critical mount '{mount}' is NOT MOUNTED!")
            all_healthy = False

    return all_healthy


def main():
    print("=== Fleet Operations Health Check ===")

    if os.geteuid() != 0:
        print("Warning: Script is not running as root. Some systemd/docker checks may fail.")

    services_ok = check_systemd_services()
    containers_ok = check_docker_containers()
    storage_ok = check_storage_mounts()

    print("\n=== Summary ===")
    if services_ok and containers_ok and storage_ok:
        print("STATUS: HEALTHY - Fleet Node is operating normally.")
        sys.exit(0)
    else:
        print("STATUS: DEGRADED - Node requires intervention!")
        sys.exit(1)


if __name__ == '__main__':
    main()
