#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Safe Teardown Script
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

echo -e "${RED}================================================================${NC}"
echo -e "${RED}  WARNING: AI Platform Decommission & Teardown                  ${NC}"
echo -e "${RED}================================================================${NC}"

read -rp "Are you sure you want to stop and remove all AI server containers? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Teardown aborted."
    exit 0
fi

read -rp "Do you also want to permanently delete all persistent volumes (MODELS, CHATS, DB)? [y/N]: " DEL_VOLUMES

echo -e "\n${YELLOW}Stopping and removing containers...${NC}"
if [[ "$DEL_VOLUMES" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Removing containers AND persistent volumes...${NC}"
    docker compose down -v
    echo -e "${GREEN}Containers and volumes removed.${NC}"
else
    docker compose down
    echo -e "${GREEN}Containers stopped. Persistent data volumes PRESERVED.${NC}"
fi

echo -e "${GREEN}Teardown complete.${NC}"

