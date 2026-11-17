# Security Hardening & Threat Mitigation Guide

Security is a primary design pillar for this deployment. Because the server is publicly accessible over the internet, multiple layers of defense-in-depth have been implemented.

---

## 1. Operating System Hardening

### SSH Access Security
1. **Public Key Authentication Only:**
   - Password authentication must be strictly disabled once SSH key access is verified.
   - Edit `/etc/ssh/sshd_config.d/50-cloud-init.conf` or `/etc/ssh/sshd_config`:
     ```ini
     PasswordAuthentication no
     KbdInteractiveAuthentication no
     PermitRootLogin prohibit-password
     PubkeyAuthentication yes
     ```
   - Restart SSH daemon:
     ```bash
     sudo systemctl restart ssh
     ```

2. **Fail2ban Intrusion Prevention:**
   - Fail2ban is pre-configured by `scripts/setup-firewall.sh`.
   - Any IP address failing SSH authentication 5 times within a 10-minute window is banned for 1 hour.
   - To inspect banned IPs:
     ```bash
     sudo fail2ban-client status sshd
     ```
   - To unban an IP:
     ```bash
     sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
     ```

3. **Automatic Security Updates:**
   - Ensure `unattended-upgrades` is active on Ubuntu:
     ```bash
     sudo apt-get install -y unattended-upgrades
     sudo dpkg-reconfigure -plow unattended-upgrades
     ```

4. **Strict File Permissions:**
   - The `.env` file containing application secrets must be readable only by root/administrator:
     ```bash
     chmod 600 .env
     chmod 700 backups
     ```

---

## 2. Oracle Cloud Infrastructure (OCI) Network Isolation

### Ingress Rules Matrix
| Protocol | Port | Source | Justification |
|---|---|---|---|
| TCP | 22 | Administrator IP / CIDR | Secure SSH administration |
| TCP | 80 | `0.0.0.0/0` | HTTP Let's Encrypt validation & redirect |
| TCP | 443 | `0.0.0.0/0` | Encrypted HTTPS access to WebUI |
| UDP | 443 | `0.0.0.0/0` | Optional HTTP/3 QUIC acceleration |

> [!CAUTION]
> **Ports that must NEVER be opened in OCI Security Lists:**
> - `11434` (Ollama REST API): Has no built-in authentication mechanism. Exposing this port allows unauthorized third parties to run models and drain VPS resources.
> - `8080` (Open WebUI direct port): Should only receive traffic through Caddy TLS.
> - `6333` / `6334` (Qdrant): Vector database internal API.
> - `5678` (n8n): Workflow automation backend.

---

## 3. Container & Docker Hardening

1. **Non-Privileged Execution:**
   - All services execute with `security_opt: [no-new-privileges:true]`.
   - Containers cannot elevate privileges via setuid binaries.

2. **Network Segmentation:**
   - Ollama and internal modules reside on `oracle_ai_backend`.
   - Caddy resides on `oracle_ai_frontend`.
   - Direct external access to Ollama from the Internet is architecturally impossible.

3. **Ephemeral Logs & Resource Limits:**
   - Docker daemon logs are constrained (`max-size: 50m`, `max-file: 3`) to eliminate denial-of-service via log disk exhaustion.
   - CPU and memory ceilings prevent OOM crashes on the host system.

---

## 4. Application-Layer Security

1. **Registration Lockdown:**
   - Open WebUI initially starts with `ENABLE_SIGNUP=true`.
   - **Action Required:** As soon as you create your primary account, set `ENABLE_SIGNUP=false` in `.env` and restart containers via `./scripts/deploy.sh` to prevent unauthorized registrations.

2. **Cryptographic Secrets:**
   - `WEBUI_SECRET_KEY` is a 256-bit cryptographically random token used to sign cookies and JWT authentication tokens.
   - It is never committed to Git (`.gitignore` enforces this).

3. **HTTP Security Headers (Enforced by Caddy):**
   - **HSTS:** `Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"`
   - **MIME Sniffing Protection:** `X-Content-Type-Options nosniff`
   - **Clickjacking Protection:** `X-Frame-Options SAMEORIGIN`
   - **Referrer Privacy:** `Referrer-Policy strict-origin-when-cross-origin`
   - **Feature Policy:** `Permissions-Policy` restricts camera, microphone, and geolocation.

