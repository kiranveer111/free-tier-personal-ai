# Oracle Cloud Personal AI Server – Deployment Action Register & Execution Log

**Instance Target:** Oracle Cloud Always Free Ampere A1 (`203.0.113.195` / `oracle-vps-arm`)  
**Architecture:** ARM64 (`aarch64`) | 4 OCPU (Neoverse-N1) | 24 GB RAM | Ubuntu 24.04.5 LTS  
**Deployment Date:** 2026-11-17  
**Status:** **OPERATIONAL & VERIFIED**

---

## Executive Summary & Live Endpoints

The personal AI server has been successfully built, hardened, and deployed on the Oracle Cloud VPS.

| Component | Status | Access / Configuration |
|---|---|---|
| **WebUI Interface** | **HEALTHY (HTTP 200)** | `https://203.0.113.195.nip.io` |
| **Reverse Proxy** | **HEALTHY** | Caddy v2.9 with HTTP/2 & HTTP/3 (QUIC) |
| **LLM Inference Engine** | **HEALTHY** | Ollama v0.40.16 (Internal network only) |
| **General Assistant Model** | **INSTALLED** | `qwen2.5:3b` (1.9 GB, 3.1B params, 12.86 tokens/s) |
| **Coding Assistant Model** | **INSTALLED** | `qwen2.5-coder:7b` (4.7 GB, 7.6B params) |
| **Document RAG Embedding** | **INSTALLED** | `bge-m3:latest` (1.2 GB, 567M params, 8k context) |
| **Security Hardening** | **ACTIVE** | Fail2ban SSH jail, UFW/iptables, internal network isolation |
| **Automated Backups** | **VERIFIED** | SHA256-verified compressed archive (239 MB) |

---

## Detailed Step-by-Step Action Register

### Step 1: Remote Hardware & System Preflight Audit

#### Command Executed:
```bash
ssh oracle-vps "uname -a && lsb_release -a && lscpu | grep -E 'Architecture|CPU\(s\)|Model name' && free -h && df -h"
```
#### Explanation:
Verifies hardware shape and operating system specifications to ensure complete compatibility with ARM64 CPU inference guidelines before deploying containers.
#### Output:
```text
Linux oracle-vps-arm 7.0.0-1013-oracle #13~24.04.1-Ubuntu SMP aarch64
Distributor ID: Ubuntu
Description:    Ubuntu 24.04.5 LTS
Release:        24.04
Architecture:   aarch64
CPU(s):         4
Model name:     Neoverse-N1
Mem Total:      23Gi (640Mi used, 21Gi available)
Filesystem:     /dev/sda1 (48G total, 45G available)
```

---

### Step 2: Automated Preflight Verification

#### Command Executed:
```bash
bash /home/ubuntu/oracle-ai-server/scripts/preflight-check.sh
```
#### Explanation:
Automates 7 independent system checks: OS version, ARM64 architecture, CPU cores, RAM minimums, available disk space, Docker hub reachability, and host port availability (ports 80 & 443).
#### Output:
```text
================================================================
  Oracle Cloud AI Server - System Preflight Verification        
================================================================
1. Operating System Check:     [PASS] Ubuntu 24.04 LTS detected
2. CPU Architecture Check:     [PASS] ARM64 / aarch64 confirmed
3. CPU Cores Check:            [PASS] 4 CPU cores detected (Ampere A1 4 OCPU)
4. Memory (RAM) Check:         [PASS] 23 GB RAM detected (24GB allocation)
5. Disk Space Check:           [PASS] 44 GB free disk space available
6. Network Connectivity Check: [PASS] Outbound internet access verified
7. Host Port Availability Check:[PASS] Port 80 and 443 open and available
================================================================
Preflight verification successful! (0 error(s), 0 warning(s))
```

---

### Step 3: Docker Engine & Compose ARM64 Installation

#### Command Executed:
```bash
bash /home/ubuntu/oracle-ai-server/scripts/setup-docker.sh
```
#### Explanation:
Installs official Docker Community Edition and Compose Plugin for Ubuntu 24.04 ARM64 (`noble`). Adds log-driver rotation (`max-size: 50m`, `max-file: 3`) to prevent unconstrained log disk exhaustion, and adds the `ubuntu` user to the `docker` group.
#### Output:
```text
Docker installation complete!
Docker version 29.10.0, build fdd4b8e
Docker Compose version v5.7.1
Added user 'ubuntu' to docker group.
```

---

### Step 4: Host Firewall & Security Hardening

#### Command Executed:
```bash
bash /home/ubuntu/oracle-ai-server/scripts/setup-firewall.sh
```
#### Explanation:
1. Configures `iptables` and persists rules with `netfilter-persistent`.
2. Removes Oracle Cloud's default `icmp-host-prohibited` FORWARD reject rule, which otherwise disrupts container-to-container network forwarding.
3. Configures and starts `fail2ban` on the SSH service (`/etc/fail2ban/jail.d/ssh-docker.local`) to protect port 22 from brute-force attempts.
#### Output:
```text
Removed legacy Oracle Cloud icmp-host-prohibited FORWARD rejection rule.
run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip4tables save
run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip6tables save
Fail2ban active and monitoring SSH.
Open external ports: 22 (SSH), 80 (HTTP), 443 (HTTPS TCP/UDP).
```

---

### Step 5: Environment & Cryptographic Secrets Generation

#### Actions Taken:
1. Generated a cryptographically secure 256-bit random hex secret for `WEBUI_SECRET_KEY`:
   ```bash
   openssl rand -hex 32
   ```
2. Set file permissions to `0600` so only owner/root can read `.env`.
3. Configured `AI_DOMAIN=203.0.113.195.nip.io` and `CADDY_TLS_MODE=internal`.

---

### Step 6: Core Stack Deployment & Health Probing

#### Command Executed:
```bash
docker compose up -d
```
#### Explanation:
Launches `ollama`, `open-webui`, and `caddy` in their designated isolated bridge networks (`oracle_ai_frontend` and `oracle_ai_backend`). Enforces health checks and strict startup sequencing (`caddy` waits for `open-webui` healthy; `open-webui` waits for `ollama` healthy).
#### Output:
```text
Network oracle_ai_frontend Created
Network oracle_ai_backend  Created
Volume oracle_ai_webui_data Created
Volume oracle_ai_ollama_data Created
Volume oracle_ai_caddy_data Created
Container ollama     Healthy
Container open-webui Healthy
Container caddy      Started
```

---

### Step 7: Comprehensive Stack Health Verification

#### Command Executed:
```bash
bash /home/ubuntu/oracle-ai-server/scripts/health-check.sh
```
#### Output:
```text
================================================================
  AI Platform Health & Service Status Monitor                   
================================================================
1. System Uptime & Load:      51 min uptime, load average: 1.74, 2.09, 1.11
2. System Memory:             23Gi total, 1.5Gi used, 21Gi available
3. Storage:                   /dev/sda1 48G (32G available, 34% used)
4. Docker Daemon:             [ACTIVE]
5. Containers:
   - Container [ollama]:     State=running | Health=healthy | Restarts=0 | MEM=11.5MiB
   - Container [open-webui]: State=running | Health=healthy | Restarts=0 | MEM=673.5MiB
   - Container [caddy]:      State=running | Health=healthy | Restarts=0 | MEM=12.2MiB
6. Ollama Version:            ollama version is 0.40.16
7. Open WebUI Endpoint:       [HTTP 200 OK]
8. Caddy Status:              [OK] | Managed Cert: 203.0.113.195.nip.io.crt
================================================================
Health check completed.
```

---

### Step 8: AI Model Installation & CPU Benchmarking

#### 8.1 Model Downloads:
Downloaded initial models using `./scripts/install-models.sh`:
- `qwen2.5:3b` (~1.9 GB): Pulled in ~4 seconds via Oracle Cloud datacenter network.
- `bge-m3:latest` (~1.2 GB): Multi-lingual embedding model for document RAG.
- `qwen2.5-coder:7b` (~4.7 GB): Software engineering assistant.

#### 8.2 CPU Benchmark Execution (qwen2.5:3b on 4 OCPUs ARM64):
```bash
bash /home/ubuntu/oracle-ai-server/scripts/install-models.sh --benchmark qwen2.5:3b
```
#### Test Prompt:
> *"Explain how an asynchronous event loop works in Node.js in two concise sentences."*

#### Model Output:
> *"In Node.js, an asynchronous event loop manages I/O and callback-based operations by scheduling them in a queue and running them as soon as the corresponding resources (like file descriptors or network sockets) become available, ensuring the program remains non-blocking and responsive."*

#### Measured Metrics:
- **Cold Load Time (Disk to RAM):** `4586 ms`
- **Warm Load Time (Subsequent calls):** `0 ms` (weights persistent via `OLLAMA_KEEP_ALIVE=24h`)
- **Total Wall Duration:** `4135 ms`
- **Tokens Generated:** `51 tokens`
- **Effective Throughput:** **12.86 tokens/second** (CPU inference only, zero GPU)

---

### Step 9: Automated Backup & Checksum Verification

#### Command Executed:
```bash
bash /home/ubuntu/oracle-ai-server/scripts/backup.sh
sha256sum -c /home/ubuntu/oracle-ai-server/backups/oracle_ai_backup_*.tar.gz.sha256
```
#### Explanation:
Extracts data from named volumes (`oracle_ai_webui_data` and `oracle_ai_caddy_data`), environment configurations, and installed model manifests into a single compressed `.tar.gz` archive with strict permissions (`0600`). Validates data integrity via SHA256 checksum.
#### Output:
```text
Open WebUI data safely archived.
Caddy TLS certificates safely archived.
Backup successfully generated:
  File:     backups/oracle_ai_backup_20261116_211150.tar.gz
  Size:     239M
  Checksum: backups/oracle_ai_backup_20261116_211150.tar.gz.sha256
Verification: OK
```

---

### Step 10: Sanitized System Diagnostics

#### Command Executed:
```bash
bash /home/ubuntu/oracle-ai-server/scripts/diagnostics.sh
```
#### Explanation:
Generates a complete system diagnostics bundle. Verified that all passwords, tokens, and `WEBUI_SECRET_KEY` are safely redacted as `********REDACTED********`.
#### Output:
```text
Diagnostic report written to: /home/ubuntu/oracle-ai-server/diagnostics-20261116_211111.txt
Redaction verification: WEBUI_SECRET_KEY=********REDACTED******** (0 credentials exposed).
```

---

### Step 11: Network Perimeter & Port Isolation Audit

#### 11.1 Public HTTPS Ingress (Client to Host):
```bash
curl -k -I https://203.0.113.195.nip.io/
```
Result: `HTTP/2 200 OK`, `strict-transport-security: max-age=31536000`, `alt-svc: h3=":443"` (HTTP/3).

#### 11.2 Authentication Enforcement:
```bash
curl -k https://203.0.113.195.nip.io/api/chat/completions
```
Result: `HTTP 401 Unauthorized` (`{"detail":"Not authenticated"}`). Proves external API requests require Bearer token authentication.

#### 11.3 Internal Port Lockdown Audit:
```bash
nc -zv -w 2 203.0.113.195 11434 8080 6333 5678
```
Result: All internal ports **timed out**. Zero internal services are exposed to the public internet.

---

### Step 12: Primary Administrator Registration & Public Signup Lockdown

#### 12.1 Verify Administrator Account Creation:
Querying Open WebUI's internal SQLite database confirmed the creation of the primary Administrator account:
* **User ID:** `11b170e6-280b-4334-8239-f3f02c502de3`
* **Name:** `Admin User`
* **Email:** `admin@example.com`
* **Role:** `admin`

#### 12.2 Enforce Environment Lockdown:
```bash
sed -i 's|ENABLE_SIGNUP=true|ENABLE_SIGNUP=false|' /home/ubuntu/oracle-ai-server/.env
cd /home/ubuntu/oracle-ai-server && docker compose up -d open-webui
```
#### Explanation:
Updates `.env` to disable all future public user self-registrations and recreates the `open-webui` container with the new configuration.

#### 12.3 Container Environment Verification:
```bash
docker inspect open-webui --format '{{range .Config.Env}}{{println .}}{{end}}' | grep 'ENABLE_SIGNUP'
```
* **Result:** `ENABLE_SIGNUP=false` confirmed active inside the container.

#### 12.4 Verification of Blocked Signup Endpoint (External Penetration Test):
```bash
curl -k -s -w "\nHTTP_STATUS:%{http_code}\n" https://203.0.113.195.nip.io/api/v1/auths/signup \
  -H "Content-Type: application/json" \
  -d '{"name": "unauthorized", "email": "unauthorized@test.com", "password": "BlockedPassword123!"}'
```
* **Result:**
  ```json
  {"detail":"You do not have permission to access this resource. Please contact your administrator for assistance."}
  ```
  `HTTP_STATUS:403` (Forbidden). Public registration is completely locked down. Only the administrator can invite or add new users from the Admin Panel.

#### 12.5 Post-Lockdown Safety Backup:
```bash
bash /home/ubuntu/oracle-ai-server/scripts/backup.sh
```
* **Archive:** `backups/oracle_ai_backup_20261116_222340.tar.gz` (239 MB)
* **Checksum:** SHA256 verified. Contains the active admin account, chat settings, and locked signup state.

---

## Next Steps for Administrator

1. **Accessing Your Server:**
   - Log in directly at `https://203.0.113.195.nip.io` using your admin credentials.
2. **User Management:**
   - Since public registration is now closed, you can manually create accounts or generate invite links via **Admin Panel** > **Users** if you ever wish to grant access to others.
3. **Configure Custom Domain (Optional):**
   - Point your domain's DNS A Record to `203.0.113.195`.
   - Update `AI_DOMAIN=ai.yourdomain.com` and `CADDY_TLS_MODE=auto` in `.env`.
   - Run `./scripts/deploy.sh`. Caddy will automatically provision a public Let's Encrypt certificate.
