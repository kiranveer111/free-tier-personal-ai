# Maintenance & Operations Runbook

This runbook outlines routine tasks, upgrades, and maintenance procedures to keep your Oracle Cloud AI Server performant and reliable.

---

## 1. Routine System Checks

Run the integrated health check script weekly or after any configuration change:

```bash
cd /home/ubuntu/oracle-ai-server
./scripts/health-check.sh
```

### Key Metrics to Monitor:
1. **Available Root Disk:** Keep at least 10 GB free for model downloads and temporary buffers.
2. **Container Restarts:** If the `Restarts` counter is climbing, check container logs for memory exhaustion (OOM).
3. **RAM Availability:** Ensure at least 2 GB of memory remains free for Linux kernel filesystem caching.

---

## 2. Upgrading Containers Safely

To upgrade Ollama, Open WebUI, and Caddy to their latest releases without risking data loss:

```bash
cd /home/ubuntu/oracle-ai-server
./scripts/update.sh
```

### Upgrade Workflow:
1. Automatically triggers `./scripts/backup.sh` to capture a full pre-update safety snapshot.
2. Runs `docker compose pull` to download newest images.
3. Recreates containers gracefully with `docker compose up -d`.
4. Executes health checks to confirm successful startup.

---

## 3. Docker Storage & Cache Management

Over time, dangling images and build layers consume disk space:

### Safe Cleanup (Preserves persistent volumes):
```bash
# Remove stopped containers, dangling networks, and dangling images:
docker system prune -f

# Check reclaimed disk space:
df -h /
```

> [!WARNING]
> Never run `docker volume prune` unless you intentionally wish to delete all stored models, chat histories, and certificates.

---

## 4. Log Inspection & Rotation

All container logs are restricted to a maximum size of 50 MB with 3 rotated files via `/etc/docker/daemon.json`.

### Viewing Real-Time Logs:
```bash
# View last 50 lines of Open WebUI logs:
docker compose logs -f --tail=50 open-webui

# View Caddy access & reverse proxy logs:
docker compose logs -f --tail=50 caddy

# View Ollama inference and model load logs:
docker compose logs -f --tail=50 ollama
```

---

## 5. Security & OS Package Updates

Keep Ubuntu updated with upstream security patches:

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoremove -y
```
*(If a new kernel is installed, reboot the VPS via `sudo reboot`. Docker containers will automatically start upon boot due to `restart: unless-stopped`.)*

