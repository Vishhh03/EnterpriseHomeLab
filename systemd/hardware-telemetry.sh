#!/usr/bin/env bash
# ==============================================================================
# Bare-Metal Hardware Telemetry Agent
# Target: Actual local Linux home server
# Description: Scrapes real hardware temperatures (lm-sensors) and disk usage
#              and writes them to a Node-Exporter textfile collector.
# ==============================================================================

set -euo pipefail

METRIC_DIR="/var/lib/prometheus/node-exporter"
METRIC_FILE="$METRIC_DIR/baremetal_hardware.prom"

mkdir -p "$METRIC_DIR"

collect_metrics() {
    # 1. Real Hardware Thermal Scraping (Uses lm-sensors if installed)
    local core_temp=0
    if command -v sensors >/dev/null 2>&1; then
        # Grab the first Package id 0 / Core 0 temp available
        core_temp=$(sensors | grep -E 'Core 0:|Package id 0:' | awk '{print $3}' | tr -d '+°C' | head -n1 || echo "0")
    fi

    # 2. Root Disk Usage (%)
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

    # 3. Memory Usage (MB)
    local mem_used
    mem_used=$(free -m | awk 'NR==2 {print $3}')

    # Write in Prometheus Exposition Format
    cat <<EOF > "$METRIC_FILE.tmp"
# HELP baremetal_cpu_temperature_celsius Real hardware CPU temperature
# TYPE baremetal_cpu_temperature_celsius gauge
baremetal_cpu_temperature_celsius $core_temp

# HELP baremetal_root_disk_usage_percent Root partition disk usage
# TYPE baremetal_root_disk_usage_percent gauge
baremetal_root_disk_usage_percent $disk_usage

# HELP baremetal_memory_used_mb Real physical memory usage
# TYPE baremetal_memory_used_mb gauge
baremetal_memory_used_mb $mem_used
EOF

    # Atomic rename to prevent partial reads by Node Exporter
    mv "$METRIC_FILE.tmp" "$METRIC_FILE"
}

while true; do
    collect_metrics
    sleep 15
done
