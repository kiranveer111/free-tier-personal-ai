#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Core Service Deployment Script
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
echo -e "${BLUE}  Deploying Oracle Cloud Personal AI Server Stack              ${NC}"
echo -e "${BLUE}================================================================${NC}"

# Check .env existence
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found. Creating from .env.example...${NC}"
    cp .env.example .env
    chmod 600 .env
fi

# Ensure WEBUI_SECRET_KEY is generated if placeholder is present
if grep -q "replace_with_a_secure_random" .env || grep -q "WEBUI_SECRET_KEY=$" .env; then
    echo -e "${YELLOW}Generating cryptographically secure WEBUI_SECRET_KEY...${NC}"
    RANDOM_SECRET=$(openssl rand -hex 32)
    sed -i "s|WEBUI_SECRET_KEY=.*|WEBUI_SECRET_KEY=${RANDOM_SECRET}|" .env
fi

# Source .env
set -a
. .env
set +a

echo -e "Configured AI Domain: ${GREEN}${AI_DOMAIN}${NC}"
echo -e "Caddy TLS Mode:       ${GREEN}${CADDY_TLS_MODE}${NC}"

# Validate Compose configuration
echo -e "\n${YELLOW}Step 1: Validating Docker Compose syntax and variables...${NC}"
docker compose config --quiet
echo -e "${GREEN}Compose configuration is valid.${NC}"

# Pull container images
echo -e "\n${YELLOW}Step 2: Pulling container images (ARM64 native)...${NC}"
docker compose pull

# Launch containers
echo -e "\n${YELLOW}Step 3: Launching core stack containers...${NC}"
docker compose up -d --remove-orphans

# Monitor startup and health
echo -e "\n${YELLOW}Step 4: Awaiting container health confirmation...${NC}"
SERVICES=("ollama" "open-webui" "caddy")
TIMEOUT=90
ELAPSED=0

for SERVICE in "${SERVICES[@]}"; do
    echo -n "Waiting for $SERVICE to become healthy... "
    while true; do
        STATUS=$(docker inspect --format='{{json .State.Health.Status}}' "$SERVICE" 2>/dev/null || echo '"unknown"')
        if [ "$STATUS" = '"healthy"' ]; then
            echo -e "${GREEN}HEALTHY!${NC}"
            break
        elif [ "$STATUS" = '"unhealthy"' ]; then
            echo -e "${RED}UNHEALTHY!${NC}"
            echo -e "${YELLOW}Recent logs for $SERVICE:${NC}"
            docker compose logs --tail=20 "$SERVICE"
            exit 1
        fi
        
        sleep 3
        ELAPSED=$((ELAPSED + 3))
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
            echo -e "${RED}TIMEOUT waiting for $SERVICE${NC}"
            echo -e "${YELLOW}Recent logs for $SERVICE:${NC}"
            docker compose logs --tail=20 "$SERVICE"
            exit 1
        fi
        echo -n "."
    done
done

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${GREEN}Deployment successfully verified and operational!${NC}"
echo -e "Access your AI Server:"
if [ "$CADDY_TLS_MODE" = "internal" ]; then
    echo -e "  URL: ${BLUE}https://${AI_DOMAIN}${NC} (self-signed cert, accept browser prompt)"
else
    echo -e "  URL: ${BLUE}https://${AI_DOMAIN}${NC}"
fi
echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e " 1. Open the URL in your browser and register your Admin account."
echo -e " 2. Once registered, disable signups by editing .env (ENABLE_SIGNUP=false) and running ./scripts/deploy.sh."
echo -e " 3. Run ${BLUE}./scripts/install-models.sh${NC} to download Qwen and BGE-M3 models."
echo -e "${BLUE}================================================================${NC}"

