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

### Issue C: Ollama Inference is Slow or Freezes

**Symptoms:** Token generation takes a long time to start, or CPU spikes to 100% across all cores.

**Causes & Solutions:**
1. **Model Size Mismatch:**
   - Running a model larger than 7B (e.g. 14B or 32B) on a 4-core CPU causes slow token evaluation (~2-4 tokens/sec).
   - Switch to `qwen2.5:3b` for fast, lightweight responses (~30 tokens/sec).
2. **Parallel Request Contention:**
   - Ensure `OLLAMA_NUM_PARALLEL=1` in `.env`. Concurrent inferences on CPU cause severe cache thrashing.
3. **Context Length Overhead:**
   - Extremely large prompts (>16,000 tokens) increase quadratic attention computation. Keep context size at `8192` or lower.

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

