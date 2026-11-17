#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Preflight Verification Script
# ==============================================================================
set -euo pipefail

# ANSI color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Oracle Cloud AI Server - System Preflight Verification        ${NC}"
echo -e "${BLUE}================================================================${NC}"

FAILURES=0
WARNINGS=0

pass() {
    echo -e " [${GREEN}PASS${NC}] $1"
}

warn() {
    echo -e " [${YELLOW}WARN${NC}] $1"
    WARNINGS=$((WARNINGS + 1))
}

fail() {
    echo -e " [${RED}FAIL${NC}] $1"
    FAILURES=$((FAILURES + 1))
}

# 1. Verify OS (Ubuntu 24.04 LTS)
echo -e "\n${BLUE}1. Operating System Check:${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "${ID:-}" = "ubuntu" ]; then
        if [[ "${VERSION_ID:-}" =~ ^24\.04 ]]; then
            pass "Ubuntu 24.04 LTS detected (${PRETTY_NAME})"
        else
            warn "Detected Ubuntu ${VERSION_ID}, but 24.04 LTS is recommended."
        fi
    else
        fail "Non-Ubuntu operating system: ${PRETTY_NAME:-unknown}"
    fi
else
    fail "Could not determine operating system (/etc/os-release missing)"
fi

# 2. Verify Architecture (ARM64 / aarch64)
echo -e "\n${BLUE}2. CPU Architecture Check:${NC}"
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    pass "ARM64 / aarch64 architecture confirmed ($ARCH)"
else
    fail "Unsupported architecture: $ARCH (Ampere A1 aarch64 required)"
fi

# 3. Verify CPU Cores
echo -e "\n${BLUE}3. CPU Cores Check:${NC}"
CPUS=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
if [ "$CPUS" -ge 4 ]; then
    pass "$CPUS CPU cores detected (optimal for Ampere A1 4 OCPU)"
elif [ "$CPUS" -ge 2 ]; then
    warn "$CPUS CPU cores detected (2+ is minimal, 4 OCPU recommended)"
else
    fail "Insufficient CPU cores: $CPUS (minimum 2 required)"
fi

# 4. Verify System Memory (RAM)
echo -e "\n${BLUE}4. Memory (RAM) Check:${NC}"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
TOTAL_RAM_GB=$((TOTAL_RAM_MB / 1024))

if [ "$TOTAL_RAM_MB" -ge 20480 ]; then
    pass "${TOTAL_RAM_GB} GB RAM detected (Ampere A1 24GB allocation)"
elif [ "$TOTAL_RAM_MB" -ge 7168 ]; then
    warn "${TOTAL_RAM_GB} GB RAM detected (functional, but limit parallel models)"
else
    fail "Insufficient RAM: ${TOTAL_RAM_GB} GB (minimum 8 GB required for local LLMs)"
fi

# 5. Verify Disk Space
echo -e "\n${BLUE}5. Disk Space Check:${NC}"
AVAIL_DISK_MB=$(df -m / | awk 'NR==2 {print $4}')
AVAIL_DISK_GB=$((AVAIL_DISK_MB / 1024))

if [ "$AVAIL_DISK_MB" -ge 30720 ]; then
    pass "${AVAIL_DISK_GB} GB free disk space available"
elif [ "$AVAIL_DISK_MB" -ge 15360 ]; then
    warn "${AVAIL_DISK_GB} GB free disk space available (keep model downloads selective)"
else
    fail "Low disk space: only ${AVAIL_DISK_GB} GB available (minimum 15 GB required)"
fi

# 6. Check Network Connectivity and DNS
echo -e "\n${BLUE}6. Network Connectivity Check:${NC}"
if curl -s -m 5 https://registry-1.docker.io/v2/ >/dev/null 2>&1 || curl -s -m 5 https://github.com >/dev/null 2>&1; then
    pass "Outbound internet access verified (Docker registry / GitHub reachable)"
else
    fail "No outbound internet access to Docker Registry or GitHub"
fi

# 7. Check Port Availability (80 & 443)
echo -e "\n${BLUE}7. Host Port Availability Check:${NC}"
for PORT in 80 443; do
    if ss -tuln | grep -q ":${PORT} "; then
        OCCUPIED_BY=$(ss -tulnp 2>/dev/null | grep ":${PORT} " | awk '{print $NF}' || echo "process")
        warn "Port ${PORT} is currently in use (${OCCUPIED_BY}). Caddy needs port ${PORT}."
    else
        pass "Port ${PORT} is open and available for Caddy"
    fi
done

# Summary
echo -e "\n${BLUE}================================================================${NC}"
if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}Preflight verification successful!${NC} ($WARNINGS warning(s))"
    echo -e "System is ready for Docker and AI Server deployment."
    exit 0
else
    echo -e "${RED}Preflight verification failed with $FAILURES error(s) and $WARNINGS warning(s).${NC}"
    echo -e "Please address the failures above before proceeding."
    exit 1
fi

