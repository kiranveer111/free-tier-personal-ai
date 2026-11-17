#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Sanitized System Diagnostics Collector
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${PROJECT_ROOT}/diagnostics-${TIMESTAMP}.txt"

echo "Collecting sanitized diagnostic bundle into: ${REPORT_FILE}"

{
    echo "================================================================================"
    echo "  ORACLE CLOUD AI SERVER DIAGNOSTIC REPORT: ${TIMESTAMP}"
    echo "================================================================================"
    echo ""
    echo "--- 1. SYSTEM IDENTITY & HARDWARE ---"
    uname -a
    cat /etc/os-release | grep -E 'PRETTY_NAME|VERSION_ID'
    lscpu | grep -E 'Architecture|CPU\(s\)|Model name'
    echo ""
    echo "--- 2. MEMORY AND STORAGE ---"
    free -h
    df -h /
    echo ""
    echo "--- 3. NETWORK INTERFACES & LISTENING PORTS ---"
    ip -brief addr
    ss -tuln
    echo ""
    echo "--- 4. FIREWALL STATUS (UFW / IPTABLES) ---"
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw status verbose 2>&1 || true
    fi
    echo ""
    echo "--- 5. DOCKER DAEMON & VERSION ---"
    docker --version 2>&1 || echo "Docker not installed"
    docker compose version 2>&1 || echo "Docker compose not installed"
    echo ""
    echo "--- 6. RUNNING CONTAINERS ---"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" 2>&1 || true
    echo ""
    echo "--- 7. CONTAINER RESOURCE CONSUMPTION ---"
    docker stats --no-stream 2>&1 || true
    echo ""
    echo "--- 8. OLLAMA STATUS & INSTALLED MODELS ---"
    if docker ps | grep -q "ollama"; then
        docker exec ollama ollama list 2>&1 || true
    fi
    echo ""
    echo "--- 9. SANITIZED ENVIRONMENT VARIABLES ---"
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        sed -E 's/(KEY|SECRET|PASSWORD|TOKEN)=.*/\1=********REDACTED********/g' "${PROJECT_ROOT}/.env"
    else
        echo "No .env file found."
    fi
    echo ""
    echo "--- 10. RECENT CONTAINER LOGS (LAST 40 LINES) ---"
    for SVC in caddy open-webui ollama; do
        if docker ps -a | grep -q "$SVC"; then
            echo ">>> Container: $SVC <<<"
            docker logs --tail=40 "$SVC" 2>&1 | sed -E 's/(KEY|SECRET|PASSWORD|TOKEN|sk-[a-zA-Z0-9]+)=.*/[REDACTED]/g'
            echo ""
        fi
    done
    echo "================================================================================"
    echo "  END OF DIAGNOSTIC REPORT"
    echo "================================================================================"
} > "$REPORT_FILE"

chmod 600 "$REPORT_FILE"
echo "Diagnostic report successfully written to: ${REPORT_FILE}"

