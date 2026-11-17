#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Master Automated Installation Script
# ==============================================================================
# Implements complete 12-step automated deployment workflow
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Oracle Cloud Personal AI Server - Automated Installation      ${NC}"
echo -e "${BLUE}================================================================${NC}"

# Steps 1 to 4: Preflight checks
echo -e "\n${CYAN}--- Step 1 to 4: System & Environment Preflight Check ---${NC}"
bash "${SCRIPT_DIR}/preflight-check.sh"

# Step 5: Install Docker and Docker Compose
echo -e "\n${CYAN}--- Step 5: Docker Engine & Compose Verification ---${NC}"
bash "${SCRIPT_DIR}/setup-docker.sh"

# Setup Host Firewall & Fail2ban
echo -e "\n${CYAN}--- Host Firewall (UFW) & Fail2ban Configuration ---${NC}"
bash "${SCRIPT_DIR}/setup-firewall.sh"

# Step 6: Prepare project directories
echo -e "\n${CYAN}--- Step 6: Preparing Project Directories & Permissions ---${NC}"
mkdir -p "${PROJECT_ROOT}/backups"
chmod 700 "${PROJECT_ROOT}/backups"
chmod +x "${PROJECT_ROOT}/scripts/"*.sh

# Step 7 & 8: Generate secrets and configure environment
echo -e "\n${CYAN}--- Steps 7 & 8: Environment & Secrets Configuration ---${NC}"
if [ ! -f "${PROJECT_ROOT}/.env" ]; then
    echo "Creating .env from .env.example..."
    cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
    chmod 600 "${PROJECT_ROOT}/.env"
fi

if grep -q "replace_with_a_secure_random" "${PROJECT_ROOT}/.env" || grep -q "WEBUI_SECRET_KEY=$" "${PROJECT_ROOT}/.env"; then
    echo "Generating cryptographically secure 256-bit WEBUI_SECRET_KEY..."
    SEC=$(openssl rand -hex 32)
    sed -i "s|WEBUI_SECRET_KEY=.*|WEBUI_SECRET_KEY=${SEC}|" "${PROJECT_ROOT}/.env"
fi

# Step 9: Validate Compose Configuration
echo -e "\n${CYAN}--- Step 9: Validating Docker Compose Specification ---${NC}"
docker compose config --quiet
echo -e "${GREEN}Docker Compose configuration verified successfully.${NC}"

# Step 10: Deploy Core Services
echo -e "\n${CYAN}--- Step 10: Deploying Core Containers (Ollama, WebUI, Caddy) ---${NC}"
bash "${SCRIPT_DIR}/deploy.sh"

# Step 11: Verify Containers and HTTPS
echo -e "\n${CYAN}--- Step 11: Verifying Health & Endpoints ---${NC}"
bash "${SCRIPT_DIR}/health-check.sh"

# Step 12: Model Installation Prompt
echo -e "\n${CYAN}--- Step 12: Next Steps & Model Installation ---${NC}"
echo -e "${GREEN}Base installation is COMPLETE!${NC}"
echo -e "You can now install AI models using the interactive manager:"
echo -e "  ${BLUE}${PROJECT_ROOT}/scripts/install-models.sh --recommended${NC}"
echo -e "Or interactively:"
echo -e "  ${BLUE}${PROJECT_ROOT}/scripts/install-models.sh${NC}"
echo -e "${BLUE}================================================================${NC}"

