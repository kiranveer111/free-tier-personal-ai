#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Health & Diagnostics Checker
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

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  AI Platform Health & Service Status Monitor                   ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 1. System Uptime & Load
echo -e "\n${CYAN}1. System Uptime & Load Average:${NC}"
uptime

# 2. CPU & Memory Usage
echo -e "\n${CYAN}2. System Resources (RAM & Swap):${NC}"
free -h

# 3. Disk Space
echo -e "\n${CYAN}3. Root Filesystem Storage:${NC}"
df -h / | awk 'NR==1 || NR==2'

# 4. Docker Service Status
echo -e "\n${CYAN}4. Docker Engine Status:${NC}"
if systemctl is-active --quiet docker; then
    echo -e "Docker Daemon: [${GREEN}ACTIVE${NC}]"
else
    echo -e "Docker Daemon: [${RED}INACTIVE / FAILED${NC}]"
fi

# 5. Core Containers Health & Restarts
echo -e "\n${CYAN}5. Container States and Health:${NC}"
SERVICES=("ollama" "open-webui" "caddy")
for SVC in "${SERVICES[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${SVC}$"; then
        STATE=$(docker inspect --format='{{.State.Status}}' "$SVC")
        HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$SVC")
        RESTARTS=$(docker inspect --format='{{.RestartCount}}' "$SVC")
        MEM_USAGE=$(docker stats --no-stream --format "{{.MemUsage}}" "$SVC" 2>/dev/null || echo "N/A")
        CPU_USAGE=$(docker stats --no-stream --format "{{.CPUPerc}}" "$SVC" 2>/dev/null || echo "N/A")

        if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "none" -a "$STATE" = "running" ]; then
            COLOR=$GREEN
        else
            COLOR=$RED
        fi
        echo -e "  Container [${GREEN}${SVC}${NC}]: State=${COLOR}${STATE}${NC} | Health=${COLOR}${HEALTH}${NC} | Restarts=${RESTARTS} | CPU=${CPU_USAGE} | MEM=${MEM_USAGE}"
    else
        echo -e "  Container [${RED}${SVC}${NC}]: [${RED}NOT RUNNING${NC}]"
    fi
done

# 6. Ollama API Reachability & Models
echo -e "\n${CYAN}6. Ollama Local LLM Engine:${NC}"
if docker ps --filter "name=ollama" --filter "status=running" | grep -q "ollama"; then
    OLLAMA_VERSION=$(docker exec ollama ollama --version 2>/dev/null || echo "Unknown")
    echo -e "  Ollama Binary: ${GREEN}${OLLAMA_VERSION}${NC}"
    echo -e "  Installed Models:"
    docker exec ollama ollama list | sed 's/^/    /'
else
    echo -e "  [${RED}Ollama container not accessible${NC}]"
fi

# 7. Open WebUI Endpoint Health
echo -e "\n${CYAN}7. Open WebUI Health Endpoint:${NC}"
if docker ps --filter "name=open-webui" --filter "status=running" | grep -q "open-webui"; then
    HTTP_CODE=$(docker exec open-webui python3 -c 'import urllib.request; resp=urllib.request.urlopen("http://localhost:8080/health"); print(resp.getcode())' 2>/dev/null || echo "Failed")
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "  Open WebUI Internal Health: [${GREEN}HTTP 200 OK${NC}]"
    else
        echo -e "  Open WebUI Internal Health: [${RED}Status: ${HTTP_CODE}${NC}]"
    fi
fi

# 8. Caddy HTTPS Status & Certificates
echo -e "\n${CYAN}8. Caddy Reverse Proxy & TLS Certificates:${NC}"
if docker ps --filter "name=caddy" --filter "status=running" | grep -q "caddy"; then
    CADDY_HEALTH=$(docker exec caddy wget -qO- http://localhost:80/healthz 2>/dev/null || echo "Failed")
    if [ "$CADDY_HEALTH" = "OK" ]; then
        echo -e "  Caddy Endpoint Health: [${GREEN}OK${NC}]"
    fi
    echo -e "  Managed TLS Certificates:"
    docker exec caddy find /data/caddy/certificates -type f -name "*.crt" 2>/dev/null | sed 's/^/    /' || echo "    No public certs loaded yet (e.g. internal mode or pending DNS)."
fi

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${GREEN}Health check completed.${NC}"

