#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Model Manager & Benchmarking
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
echo -e "${BLUE}  Ollama Model Management & Benchmark Suite (ARM64 Optimized)  ${NC}"
echo -e "${BLUE}================================================================${NC}"

# Check if Ollama container is running
if ! docker ps --filter "name=ollama" --filter "status=running" | grep -q "ollama"; then
    echo -e "${RED}Error: Ollama container is not running.${NC}"
    echo "Please start the stack with: ./scripts/deploy.sh"
    exit 1
fi

# Check host disk space
AVAIL_DISK_MB=$(df -m / | awk 'NR==2 {print $4}')
AVAIL_DISK_GB=$((AVAIL_DISK_MB / 1024))
echo -e "Available root disk space: ${GREEN}${AVAIL_DISK_GB} GB${NC}"

if [ "$AVAIL_DISK_GB" -lt 5 ]; then
    echo -e "${RED}Warning: Extremely low disk space (${AVAIL_DISK_GB} GB). Cannot pull large models.${NC}"
    exit 1
fi

pull_model() {
    local MODEL="$1"
    local DESCRIPTION="$2"
    local EST_SIZE="$3"

    echo -e "\n${CYAN}----------------------------------------------------------------${NC}"
    echo -e "${CYAN}Target Model: ${GREEN}${MODEL}${NC} (${EST_SIZE}) - ${DESCRIPTION}"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"

    echo -e "Pulling ${MODEL} via Ollama..."
    if docker exec ollama ollama pull "${MODEL}"; then
        echo -e "${GREEN}Successfully pulled ${MODEL}!${NC}"
    else
        echo -e "${RED}Failed to pull ${MODEL}.${NC}"
        return 1
    fi
}

benchmark_model() {
    local MODEL="$1"
    echo -e "\n${YELLOW}================================================================${NC}"
    echo -e "${YELLOW}  Benchmarking Model: ${GREEN}${MODEL}${NC}"
    echo -e "${YELLOW}================================================================${NC}"

    TEST_PROMPT="Explain how an asynchronous event loop works in Node.js in two concise sentences."
    echo -e "Test Prompt: \"${TEST_PROMPT}\""
    
    START_TIME=$(date +%s%N)
    
    # Run inference request using curl against internal Ollama container via network
    RESPONSE=$(docker exec open-webui curl -s http://ollama:11434/api/generate -d "{
        \"model\": \"${MODEL}\",
        \"prompt\": \"${TEST_PROMPT}\",
        \"stream\": false,
        \"options\": {
            \"num_predict\": 100
        }
    }")

    END_TIME=$(date +%s%N)
    DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

    if echo "$RESPONSE" | grep -q '"response"'; then
        ANSWER=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('response', ''))" 2>/dev/null || echo "Response parsed.")
        EVAL_COUNT=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('eval_count', 0))" 2>/dev/null || echo "0")
        EVAL_DURATION_NS=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('eval_duration', 1))" 2>/dev/null || echo "1")
        LOAD_DURATION_MS=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(int(data.get('load_duration', 0) / 1000000))" 2>/dev/null || echo "0")

        if [ "$EVAL_DURATION_NS" -gt 0 ] && [ "$EVAL_COUNT" -gt 0 ]; then
            TOKENS_PER_SEC=$(python3 -c "print(round(${EVAL_COUNT} / (${EVAL_DURATION_NS} / 1e9), 2))")
        else
            TOKENS_PER_SEC="N/A"
        fi

        echo -e "\n${GREEN}Inference Response:${NC}\n${ANSWER}\n"
        echo -e "${CYAN}Benchmark Metrics:${NC}"
        echo -e "  - Model Load Time:      ${LOAD_DURATION_MS} ms"
        echo -e "  - Total Wall Duration:  ${DURATION_MS} ms"
        echo -e "  - Tokens Generated:     ${EVAL_COUNT}"
        echo -e "  - Generation Speed:     ${GREEN}${TOKENS_PER_SEC} tokens/sec${NC}"
    else
        echo -e "${RED}Benchmark failed or unexpected response:${NC}"
        echo "$RESPONSE"
    fi
}

show_menu() {
    echo -e "\nSelect an installation option:"
    echo "1) Recommended High-Performance Suite (Qwen 2.5 3B + Coder 1.5B + 0.5B Task + BGE-M3) [~4.5 GB]"
    echo "2) Power Coder Pack (Qwen 2.5 Coder 7B + Coder 1.5B + 0.5B Task + BGE-M3) [~7.3 GB]"
    echo "3) Ultra-Fast Coder Only (Qwen 2.5 Coder 1.5B) [~986 MB]"
    echo "4) Advanced Reasoner (Qwen 2.5 7B) [~4.7 GB]"
    echo "5) Task Model Only (Qwen 2.5 0.5B for WebUI titling) [~397 MB]"
    echo "6) Custom Model by Name"
    echo "7) List currently installed models"
    echo "8) Benchmark an installed model"
    echo "9) Exit"
    read -rp "Enter choice [1-9]: " CHOICE

    case "$CHOICE" in
        1)
            pull_model "qwen2.5:3b" "General Assistant (Fast, CPU friendly)" "1.9 GB"
            pull_model "qwen2.5-coder:1.5b" "Fast Coding Assistant (~23 t/s)" "986 MB"
            pull_model "qwen2.5:0.5b" "Background Task & Title Model (~52 t/s)" "397 MB"
            pull_model "bge-m3" "Embedding Model for RAG / Document Analysis" "1.2 GB"
            ;;
        2)
            pull_model "qwen2.5-coder:7b" "Advanced Deep Coding Assistant" "4.7 GB"
            pull_model "qwen2.5-coder:1.5b" "Fast Coding Assistant (~23 t/s)" "986 MB"
            pull_model "qwen2.5:0.5b" "Background Task & Title Model (~52 t/s)" "397 MB"
            pull_model "bge-m3" "Embedding Model for RAG / Document Analysis" "1.2 GB"
            ;;
        3)
            pull_model "qwen2.5-coder:1.5b" "Fast Coding Assistant (~23 t/s)" "986 MB"
            ;;
        4)
            pull_model "qwen2.5:7b" "Advanced General Reasoning & Architecture" "4.7 GB"
            ;;
        5)
            pull_model "qwen2.5:0.5b" "Background Task & Title Model (~52 t/s)" "397 MB"
            ;;
        6)
            read -rp "Enter full Ollama model tag (e.g. llama3.2:3b): " CUSTOM_MODEL
            pull_model "$CUSTOM_MODEL" "User custom selection" "Variable"
            ;;
        7)
            echo -e "\n${GREEN}Currently Installed Models in Ollama:${NC}"
            docker exec ollama ollama list
            ;;
        8)
            echo -e "\nInstalled models:"
            docker exec ollama ollama list
            read -rp "Enter model tag to benchmark: " BM_MODEL
            benchmark_model "$BM_MODEL"
            ;;
        9)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

# Non-interactive CLI flag parsing
if [ $# -gt 0 ]; then
    case "$1" in
        --recommended)
            pull_model "qwen2.5:3b" "General Assistant (Fast CPU)" "1.9 GB"
            pull_model "qwen2.5-coder:1.5b" "Fast Coding Assistant (~23 t/s)" "986 MB"
            pull_model "qwen2.5:0.5b" "Background Task & Title Model (~52 t/s)" "397 MB"
            pull_model "bge-m3" "RAG Embedding Model" "1.2 GB"
            ;;
        --coder)
            pull_model "qwen2.5-coder:7b" "Advanced Deep Coding Model" "4.7 GB"
            pull_model "qwen2.5-coder:1.5b" "Fast Coding Assistant (~23 t/s)" "986 MB"
            pull_model "qwen2.5:0.5b" "Background Task & Title Model" "397 MB"
            pull_model "bge-m3" "RAG Embedding Model" "1.2 GB"
            ;;
        --model)
            if [ -n "${2:-}" ]; then
                pull_model "$2" "Custom command-line model" "Variable"
            else
                echo -e "${RED}Error: --model requires a model tag (e.g., qwen2.5:3b)${NC}"
                exit 1
            fi
            ;;
        --list)
            docker exec ollama ollama list
            ;;
        --benchmark)
            if [ -n "${2:-}" ]; then
                benchmark_model "$2"
            else
                echo -e "${RED}Error: --benchmark requires a model tag${NC}"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [--recommended | --coder | --model <tag> | --list | --benchmark <tag>]"
            exit 1
            ;;
    esac
else
    show_menu
fi

echo -e "\n${GREEN}Current Models in Ollama:${NC}"
docker exec ollama ollama list
