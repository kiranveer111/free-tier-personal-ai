#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Docker Engine Setup (ARM64 Ubuntu 24.04)
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Installing / Verifying Docker Engine & Compose on ARM64       ${NC}"
echo -e "${BLUE}================================================================${NC}"

# Check for root or sudo privileges
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo -e "${GREEN}Docker is already installed:${NC}"
    docker --version
    docker compose version
    exit 0
fi

echo -e "${YELLOW}Step 1: Removing outdated packages if present...${NC}"
$SUDO apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc 2>/dev/null || true

echo -e "${YELLOW}Step 2: Installing repository prerequisites...${NC}"
$SUDO apt-get update -y
$SUDO apt-get install -y ca-certificates curl gnupg lsb-release

echo -e "${YELLOW}Step 3: Setting up official Docker GPG keyring...${NC}"
$SUDO install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO tee /etc/apt/keyrings/docker.asc > /dev/null
    $SUDO chmod a+r /etc/apt/keyrings/docker.asc
fi

echo -e "${YELLOW}Step 4: Adding Docker repository for Ubuntu ARM64...${NC}"
UBUNTU_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

echo -e "${YELLOW}Step 5: Installing Docker Engine, CLI, and Compose Plugin...${NC}"
$SUDO apt-get update -y
$SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo -e "${YELLOW}Step 6: Configuring Docker daemon (log rotation & IPv6-safe bridge)...${NC}"
$SUDO mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
    cat <<EOF | $SUDO tee /etc/docker/daemon.json > /dev/null
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF
fi

echo -e "${YELLOW}Step 7: Enabling and starting Docker daemon...${NC}"
$SUDO systemctl daemon-reload
$SUDO systemctl enable docker.service
$SUDO systemctl restart docker.service

echo -e "${YELLOW}Step 8: Adding current user to docker group...${NC}"
CURRENT_USER="${SUDO_USER:-$(whoami)}"
if [ "$CURRENT_USER" != "root" ]; then
    $SUDO usermod -aG docker "$CURRENT_USER" || true
    echo -e "${GREEN}Added user '$CURRENT_USER' to docker group.${NC}"
fi

echo -e "\n${GREEN}Docker installation complete!${NC}"
docker --version
docker compose version

