#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - System Restoration Script
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <path_to_backup_archive.tar.gz>${NC}"
    echo "Available backups in backups/:"
    ls -lh "${PROJECT_ROOT}/backups"/*.tar.gz 2>/dev/null || echo "No backups found."
    exit 1
fi

BACKUP_TAR="$1"

if [ ! -f "$BACKUP_TAR" ]; then
    echo -e "${RED}Error: Backup file does not exist: $BACKUP_TAR${NC}"
    exit 1
fi

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Restoring AI Platform from Archive                           ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "Archive: ${GREEN}${BACKUP_TAR}${NC}"

# Check integrity if sha256 file exists
if [ -f "${BACKUP_TAR}.sha256" ]; then
    echo -e "${YELLOW}Verifying archive SHA256 checksum...${NC}"
    if sha256sum -c "${BACKUP_TAR}.sha256"; then
        echo -e "${GREEN}Checksum verification passed.${NC}"
    else
        echo -e "${RED}Checksum verification FAILED! Aborting restore.${NC}"
        exit 1
    fi
fi

# Confirmation prompt
echo -e "\n${RED}WARNING: Restoration will overwrite existing Open WebUI and Caddy data!${NC}"
read -rp "Are you absolutely sure you want to proceed? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Restoration cancelled by user."
    exit 0
fi

TEMP_RESTORE_DIR=$(mktemp -d "/tmp/ai_restore_XXXXXX")
cleanup() {
    rm -rf "$TEMP_RESTORE_DIR"
}
trap cleanup EXIT

echo -e "${YELLOW}Extracting archive...${NC}"
tar -xzf "$BACKUP_TAR" -C "$TEMP_RESTORE_DIR"

echo -e "${YELLOW}Stopping existing containers...${NC}"
cd "$PROJECT_ROOT"
docker compose down || true

echo -e "${YELLOW}Restoring configurations...${NC}"
if [ -f "${TEMP_RESTORE_DIR}/.env" ]; then
    cp "${TEMP_RESTORE_DIR}/.env" "${PROJECT_ROOT}/.env"
    chmod 600 "${PROJECT_ROOT}/.env"
fi
cp "${TEMP_RESTORE_DIR}/compose.yaml" "${PROJECT_ROOT}/compose.yaml"
cp "${TEMP_RESTORE_DIR}/Caddyfile" "${PROJECT_ROOT}/Caddyfile"

echo -e "${YELLOW}Restoring Open WebUI volume...${NC}"
if [ -f "${TEMP_RESTORE_DIR}/open_webui_data/webui_volume.tar.gz" ]; then
    docker volume create oracle_ai_webui_data >/dev/null
    docker run --rm \
        -v oracle_ai_webui_data:/target \
        -v "${TEMP_RESTORE_DIR}/open_webui_data":/source:ro \
        alpine sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null || true; tar -xzf /source/webui_volume.tar.gz -C /target"
    echo -e "${GREEN}Open WebUI volume restored.${NC}"
fi

echo -e "${YELLOW}Restoring Caddy volume...${NC}"
if [ -f "${TEMP_RESTORE_DIR}/caddy_data/caddy_volume.tar.gz" ]; then
    docker volume create oracle_ai_caddy_data >/dev/null
    docker run --rm \
        -v oracle_ai_caddy_data:/target \
        -v "${TEMP_RESTORE_DIR}/caddy_data":/source:ro \
        alpine sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null || true; tar -xzf /source/caddy_volume.tar.gz -C /target"
    echo -e "${GREEN}Caddy volume restored.${NC}"
fi

echo -e "${YELLOW}Starting restored services...${NC}"
docker compose up -d

echo -e "\n${GREEN}Restoration complete! Services are coming online.${NC}"
echo "Run ./scripts/health-check.sh to verify platform health."

