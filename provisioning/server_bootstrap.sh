#!/usr/bin/env bash
# ==============================================================================
# Bare-Metal Home Server Bootstrap Script
# Target: Actual local Linux home server
# Description: Automates initial host configuration, networking tuning, and
#              installs actual bare-metal utilities (lm-sensors, smartmontools).
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/baremetal-bootstrap.log"

log_info() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')] [INFO] $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')] [ERROR] $*" | tee -a "$LOG_FILE" >&2; }
fatal() { log_error "$*"; exit 1; }

# Trap unexpected exits
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Bootstrap failed with exit code $exit_code."
    else
        log_info "Bootstrap completed successfully."
    fi
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# System Dependencies & Bare-Metal Hardware Tools
# ------------------------------------------------------------------------------
setup_dependencies() {
    log_info "Installing core bare-metal dependencies..."
    
    if [[ $EUID -ne 0 ]]; then
        fatal "This script must be run as root."
    fi

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    
    # Install essential admin tools, hardware sensors, and disk health tools
    apt-get install -yq \
        curl wget jq vim htop \
        net-tools dnsutils tcpdump \
        auditd fail2ban ufw \
        lm-sensors smartmontools \
        apt-transport-https ca-certificates gnupg lsb-release

    log_info "Detecting hardware sensors..."
    # yes "" | sensors-detect --auto  # Uncomment to auto-detect sensors safely
}

# ------------------------------------------------------------------------------
# Docker CE Runtime Provisioning
# ------------------------------------------------------------------------------
install_docker() {
    if ! command -v docker &> /dev/null; then
        log_info "Provisioning Docker CE runtime..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        
        apt-get update -qq
        apt-get install -yq docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        systemctl enable docker
        systemctl start docker
    else
        log_info "Docker is already installed. Skipping."
    fi
}

main() {
    log_info "Starting Bare-Metal Server Bootstrap Sequence..."
    setup_dependencies
    install_docker
    log_info "Server is prepped for infrastructure deployment!"
}

main "$@"
