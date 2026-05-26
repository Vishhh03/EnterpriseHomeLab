#!/usr/bin/env bash
# ==============================================================================
# Bare-Metal OS Hardening & Network Tuning
# Target: Actual local Linux home server
# Description: Applies strict OS tuning and sets up a default-deny UFW firewall.
#              CRITICAL: Dynamically detects and whitelists your local LAN 
#              to prevent locking you out of SSH.
# ==============================================================================

set -euo pipefail

LOG_FILE="/var/log/baremetal-hardening.log"
log_info() { echo "[INFO] $*" | tee -a "$LOG_FILE"; }

# ------------------------------------------------------------------------------
# Kernel Parameter Tuning (sysctl)
# ------------------------------------------------------------------------------
tune_sysctl() {
    log_info "Applying High-Throughput Kernel Tuning..."
    local sysctl_conf="/etc/sysctl.d/99-homelab-tuning.conf"
    
    cat <<EOF > "$sysctl_conf"
# Spoofing protection
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1

# TCP/IP Stack Hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

# BBR Congestion Control for faster home network routing
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Max file descriptors for intensive Docker workloads
fs.file-max = 2097152
EOF

    sysctl -p "$sysctl_conf"
}

# ------------------------------------------------------------------------------
# Safe Firewall (UFW) Configuration for Home LAN
# ------------------------------------------------------------------------------
configure_firewall() {
    log_info "Configuring Default-Deny Firewall Rules safely..."
    
    # 1. Dynamically find the active network interface and its subnet
    # Example output: 192.168.1.0/24
    local active_iface
    active_iface=$(ip route get 1.1.1.1 | awk '{print $5}')
    
    local lan_subnet
    lan_subnet=$(ip -o -f inet addr show "$active_iface" | awk '{print $4}' | head -n1)
    # Convert IP/CIDR to Subnet/CIDR (basic approximation for most home routers)
    lan_subnet=$(echo "$lan_subnet" | sed 's/\.[0-9]*\//.0\//')

    log_info "Detected Home LAN Subnet: $lan_subnet on interface $active_iface"

    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # 2. Whitelist the ENTIRE home LAN so you don't lock yourself out!
    ufw allow from "$lan_subnet" comment "Allow Home LAN"

    # 3. Explicitly limit SSH from the outside (if port-forwarded)
    ufw limit 22/tcp comment 'Rate-limit external SSH'
    
    # 4. Open Docker Ingress proxy ports
    ufw allow 80/tcp comment 'HTTP Proxy Ingress'
    ufw allow 443/tcp comment 'HTTPS Proxy Ingress'
    
    ufw --force enable
}

main() {
    log_info "Starting Safe OS Hardening..."
    tune_sysctl
    configure_firewall
    log_info "OS Hardening Completed securely."
}

main "$@"
