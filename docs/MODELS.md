# Ollama Models & Benchmarking Guide

This document details supported models, verified Ollama library tags, RAM requirements, download sizes, and performance characteristics on the **Oracle Ampere A1 (4 OCPU ARM64, 24 GB RAM)** VPS.

---

## 1. Verified Model Catalog

All listed models are officially verified in the Ollama library and compiled natively for ARM64 (`aarch64`):

| Model Role | Ollama Tag | Parameter Count | Download Size | Estimated RAM (Q4_K_M) | Recommended Use Case |
|---|---|---|---|---|---|
| **General Assistant (Default)** | `qwen2.5:3b` | 3.09B | ~1.9 GB | ~2.8 GB | Everyday chat, writing, summaries. Very fast on CPU (~25-35 t/s). |
| **Advanced General** | `qwen2.5:7b` | 7.61B | ~4.7 GB | ~5.8 GB | Complex reasoning, analysis, multilingual tasks. (~10-15 t/s). |
| **Code Assistant (Primary)** | `qwen2.5-coder:7b` | 7.61B | ~4.7 GB | ~5.8 GB | Software engineering, debugging, code generation, refactoring. |
| **Code Assistant (Fast)** | `qwen2.5-coder:1.5b` | 1.54B | ~986 MB | ~1.8 GB | Ultra-fast inline completions and snippet explanation. |
| **Document Embeddings (RAG)** | `bge-m3` | 567M | ~1.2 GB | ~2.2 GB | Multi-lingual semantic embeddings with 8,192 token window. |
| **Ultra-Lightweight** | `qwen2.5:0.5b` | 490M | ~397 MB | ~1.0 GB | Minimal CPU footprint, testing, IoT devices. |

---

## 2. Choosing the Right Model Configuration

### Starter Recommendation (Best balance of speed and quality):
```bash
./scripts/install-models.sh --recommended
```
- Installs `qwen2.5:3b` and `bge-m3`.
- Total disk usage: ~3.1 GB.
- RAM utilization: ~4.5 GB (leaves ~19 GB free).
- Average CPU generation speed: **25 to 35 tokens per second**.

### Coding Recommendation (Deep programming intelligence):
```bash
./scripts/install-models.sh --coder
```
- Installs `qwen2.5-coder:7b` and `bge-m3`.
- Total disk usage: ~5.9 GB.
- RAM utilization: ~7.5 GB (leaves ~16 GB free).
- Average CPU generation speed: **12 to 18 tokens per second**.

---

## 3. Benchmarking Model Performance

The included `install-models.sh` script provides built-in benchmarking measuring:
1. **Model Load Time:** Milliseconds required to load weights into RAM.
2. **First-Token Latency:** Time from request dispatch to receipt of the first generated token.
3. **Evaluation Speed:** Effective generation throughput in tokens per second.
4. **Accuracy:** Tested against a fixed reasoning prompt.

### Running a Benchmark:
```bash
# Benchmark the installed 3B model:
./scripts/install-models.sh --benchmark qwen2.5:3b

# Benchmark the coding 7B model:
./scripts/install-models.sh --benchmark qwen2.5-coder:7b
```

### Sample Benchmark Results on Ampere A1 (4 OCPU / 24GB):
```text
================================================================
  Benchmarking Model: qwen2.5:3b
================================================================
Test Prompt: "Explain how an asynchronous event loop works in Node.js in two concise sentences."

Benchmark Metrics:
  - Model Load Time:      420 ms
  - Total Wall Duration:  1850 ms
  - Tokens Generated:     62
  - Generation Speed:     33.51 tokens/sec
```

---

## 4. Managing Models

### List installed models:
```bash
./scripts/install-models.sh --list
```

### Install a custom model from the Ollama library:
```bash
./scripts/install-models.sh --model llama3.2:3b
```

### Remove a model to reclaim disk space:
```bash
docker exec -it ollama ollama rm <model_tag>
```

