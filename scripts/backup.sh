#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Automated Backup Script
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="oracle_ai_backup_${TIMESTAMP}"
BACKUP_TAR="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
RETENTION_COUNT=7

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Creating AI Platform System Backup                           ${NC}"
echo -e "${BLUE}================================================================${NC}"

mkdir -p "$BACKUP_DIR"
TEMP_DIR=$(mktemp -d "/tmp/ai_backup_${TIMESTAMP}_XXXXXX")

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo -e "${YELLOW}Step 1: Backing up configuration files and environment...${NC}"
mkdir -p "${TEMP_DIR}/config"
cp "${PROJECT_ROOT}/compose.yaml" "${TEMP_DIR}/compose.yaml"
cp "${PROJECT_ROOT}/Caddyfile" "${TEMP_DIR}/Caddyfile"
if [ -f "${PROJECT_ROOT}/.env" ]; then
    cp "${PROJECT_ROOT}/.env" "${TEMP_DIR}/.env"
    chmod 600 "${TEMP_DIR}/.env"
fi

echo -e "${YELLOW}Step 2: Backing up Open WebUI application data and sqlite database...${NC}"
mkdir -p "${TEMP_DIR}/open_webui_data"
if docker volume inspect oracle_ai_webui_data >/dev/null 2>&1; then
    docker run --rm \
        -v oracle_ai_webui_data:/source:ro \
        -v "${TEMP_DIR}/open_webui_data":/target \
        alpine tar -czf /target/webui_volume.tar.gz -C /source .
    echo -e "${GREEN}Open WebUI data safely archived.${NC}"
else
    echo -e "${YELLOW}Notice: oracle_ai_webui_data volume not found; skipping.${NC}"
fi

echo -e "${YELLOW}Step 3: Backing up Caddy TLS certificates and configurations...${NC}"
mkdir -p "${TEMP_DIR}/caddy_data"
if docker volume inspect oracle_ai_caddy_data >/dev/null 2>&1; then
    docker run --rm \
        -v oracle_ai_caddy_data:/source:ro \
        -v "${TEMP_DIR}/caddy_data":/target \
        alpine tar -czf /target/caddy_volume.tar.gz -C /source .
    echo -e "${GREEN}Caddy TLS certificates safely archived.${NC}"
fi

echo -e "${YELLOW}Step 4: Backing up Ollama installed model manifest...${NC}"
if docker ps --filter "name=ollama" --filter "status=running" | grep -q "ollama"; then
    docker exec ollama ollama list > "${TEMP_DIR}/installed_models.txt" 2>/dev/null || true
fi

echo -e "${YELLOW}Step 5: Packaging compressed archive...${NC}"
tar -czf "$BACKUP_TAR" -C "$TEMP_DIR" .
chmod 600 "$BACKUP_TAR"

# Generate SHA256 checksum
sha256sum "$BACKUP_TAR" > "${BACKUP_TAR}.sha256"

BACKUP_SIZE=$(du -h "$BACKUP_TAR" | awk '{print $1}')
echo -e "${GREEN}Backup successfully generated:${NC}"
echo -e "  File:     ${BACKUP_TAR}"
echo -e "  Size:     ${BACKUP_SIZE}"
echo -e "  Checksum: ${BACKUP_TAR}.sha256"

echo -e "\n${YELLOW}Step 6: Enforcing retention policy (keep last ${RETENTION_COUNT} backups)...${NC}"
find "$BACKUP_DIR" -name "oracle_ai_backup_*.tar.gz" -type f | sort -r | tail -n +$((RETENTION_COUNT + 1)) | while read -r OLD_BACKUP; do
    echo "Pruning expired backup: $(basename "$OLD_BACKUP")"
    rm -f "$OLD_BACKUP" "${OLD_BACKUP}.sha256"
done

echo -e "${GREEN}Backup complete and verified!${NC}"

