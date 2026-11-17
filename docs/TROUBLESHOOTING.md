# Troubleshooting & Problem Resolution Guide

This guide addresses common issues, diagnostic procedures, and recovery steps for the Oracle Cloud Personal AI Server.

---

## 1. Quick Diagnostics

Whenever an unexpected behavior occurs, generate a comprehensive diagnostic report:

```bash
./scripts/diagnostics.sh
```

This generates a timestamped, sanitized report (`diagnostics-<TIMESTAMP>.txt`) containing memory, CPU, disk, listening ports, Docker container health, and recent logs without exposing secrets.

---

## 2. Common Scenarios & Solutions

### Issue A: Cannot Connect to HTTPS (Connection Refused or Timed Out)

**Symptoms:** Browser displays `ERR_CONNECTION_TIMED_OUT` or `ERR_CONNECTION_REFUSED`.

**Possible Causes & Solutions:**
1. **OCI VCN Ingress Rules Not Configured:**
   - Log in to Oracle Cloud Console > VCN > Security Lists.
   - Verify that TCP ports `80` and `443` are allowed from `0.0.0.0/0`.
2. **DNS A Record Not Pointing to VPS IP:**
   - Test resolution locally:
     ```bash
     dig +short ai.yourdomain.com
     ```
   - Must match your VPS public IP (`<YOUR_VPS_IP>`).
3. **Caddy Container Down:**
   - Check status:
     ```bash
     docker compose ps caddy
     docker compose logs caddy
     ```

---

### Issue B: Let's Encrypt Certificate Pending or Fails

**Symptoms:** Browser warns about self-signed certificate or Caddy log shows ACME challenge failure.

**Solutions:**
1. Let's Encrypt requires port 80 to verify domain ownership via HTTP-01 challenge. Ensure port 80 is not blocked in OCI Security List.
2. If using an IP address directly or testing without a public domain, enable internal TLS mode in `.env`:
   ```bash
   CADDY_TLS_MODE=internal
   ./scripts/deploy.sh
   ```
   *Note: In internal mode, Caddy generates a self-signed certificate. You will need to click "Advanced -> Proceed" in your browser.*

---

### Issue C: Ollama Inference is Slow or Freezes / CPU Spikes Continuously

**Symptoms:** Token generation takes a long time to start, generation rate is sluggish, or CPU spikes to 100% across all cores and stays pegged long after an answer finishes.

**Root Causes & Verified Solutions:**
1. **Linux CFS Quota Throttling (Crucial Fix):**
   - *Problem:* If Docker container CPU limit is set to a partial quota (e.g., `cpus: 3.5`) while Ollama uses 4 OpenMP threads (`OMP_NUM_THREADS=4`), the Linux kernel CFS scheduler freezes all inference threads for 12.5ms out of every 100ms. Inspect via:
     ```bash
     docker exec ollama cat /sys/fs/cgroup/cpu.stat
     ```
     High `nr_throttled` and `throttled_usec` confirm kernel throttling.
   - *Solution:* In `.env`, ensure `OLLAMA_CPU_LIMIT=4.0` to permit full 4-core execution without artificial scheduler stalls.

2. **Open WebUI Background Task Storm:**
   - *Problem:* Open WebUI by default triggers three separate LLM tasks after every message: Title Generation, Tag Generation, and Follow-up Generation. If `TASK_MODEL` is unset, all three tasks run on the heavy chat model (e.g. 7B), queuing up and pinning the CPU for an additional 45-60 seconds.
   - *Solution:* Configure Open WebUI to offload titling to an ultra-fast 0.5B model and disable redundant tasks:
     ```bash
     TASK_MODEL=qwen2.5:0.5b
     ENABLE_TITLE_GENERATION=true
     ENABLE_TAGS_GENERATION=false
     ENABLE_FOLLOW_UP_GENERATION=false
     ```

3. **Model Eviction & Reload Thrashing (`OLLAMA_MAX_LOADED_MODELS`):**
   - *Problem:* If `OLLAMA_MAX_LOADED_MODELS=1`, invoking document embeddings (`bge-m3`) or a task model forces Ollama to evict the chat model from RAM. Reloading a 7B model from disk adds 7-8 seconds of latency to every chat turn.
   - *Solution:* With 24 GB of RAM on the Ampere A1, set `OLLAMA_MAX_LOADED_MODELS=3` in `.env`. This keeps the chat model, task model, and embedding model permanently warm in memory with 0 ms reload delay.

4. **Model Selection for ARM64 CPU Inference:**
   - On a 4-core ARM64 CPU:
     - `qwen2.5:3b`: Yields **~15-18 tokens/sec** — optimal for everyday conversations.
     - `qwen2.5-coder:1.5b`: Yields **~23-28 tokens/sec** — optimal for rapid programming tasks.
     - `qwen2.5:0.5b`: Yields **~52 tokens/sec** — dedicated background task runner.
     - `qwen2.5-coder:7b`: Yields **~6-7 tokens/sec** — reserved for complex architectural tasks where slower latency is acceptable.

5. **Context Window Size:**
   - CPU attention computation scales quadratically with context length. Set `OLLAMA_CONTEXT_SIZE=4096` in `.env` (reduced from 8192) for optimal responsiveness.

---

### Issue D: Container Cannot Communicate (Docker DNS / Forwarding Blocked)

**Symptoms:** Open WebUI logs report `Connection refused` when contacting `http://ollama:11434`.

**Cause:**
Oracle Cloud Ubuntu images occasionally maintain default iptables rules in the `FORWARD` chain (`icmp-host-prohibited`).

**Solution:**
Run the firewall setup script which cleans up legacy forward rejection rules:
```bash
./scripts/setup-firewall.sh
```
Verify Docker network connectivity:
```bash
docker exec open-webui ping -c 2 ollama
```

---

### Issue E: Disk Full / Out of Space

**Symptoms:** Docker pull fails with `no space left on device`.

**Resolution Steps:**
1. Inspect disk consumption:
   ```bash
   df -h /
   docker system df
   ```
2. Prune unused images and build caches:
   ```bash
   docker system prune -a --volumes
   ```
3. Remove unused Ollama models:
   ```bash
   docker exec -it ollama ollama rm <unused_model_tag>
   ```

---

## 3. Emergency Container Reset

If services become unresponsive and need a clean restart without losing data:

```bash
cd /home/ubuntu/oracle-ai-server
docker compose restart
./scripts/health-check.sh
```

