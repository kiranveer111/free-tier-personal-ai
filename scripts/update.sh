#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Safe Container Upgrade Script
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Controlled Platform Update & Rollback Protection             ${NC}"
echo -e "${BLUE}================================================================${NC}"

echo -e "${YELLOW}Step 1: Creating a pre-upgrade safety backup...${NC}"
"${SCRIPT_DIR}/backup.sh"

echo -e "\n${YELLOW}Step 2: Checking and pulling latest pinned image updates...${NC}"
docker compose pull

echo -e "\n${YELLOW}Step 3: Performing graceful recreation of containers...${NC}"
docker compose up -d --remove-orphans

echo -e "\n${YELLOW}Step 4: Verifying service health post-update...${NC}"
sleep 5
"${SCRIPT_DIR}/health-check.sh"

echo -e "\n${GREEN}Update completed successfully!${NC}"
echo -e "Your persistent volumes (models, webui data, TLS certs) are preserved."

