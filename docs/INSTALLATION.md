# Installation and Deployment Guide

This guide walks you step-by-step through setting up and running the Oracle Cloud Personal AI Server on an **Ampere A1 (4 OCPU, 24 GB RAM, ARM64)** Ubuntu 24.04 LTS instance.

---

## 1. Prerequisites

### Hardware Requirements
- **Cloud Provider:** Oracle Cloud Infrastructure (OCI) Always Free Tier
- **Compute Shape:** `VM.Standard.A1.Flex`
- **OCPU:** 4 cores (ARM64 Neoverse-N1)
- **RAM:** 24 GB
- **Operating System:** Ubuntu 24.04 LTS (Minimal or Server)
- **Boot Volume:** 50 GB to 200 GB

### Network Requirements
- A public IPv4 address assigned to the VPS (e.g. `<YOUR_VPS_IP>`).
- A domain name with an **A Record** pointing to your VPS public IPv4:
  - Example: `ai.yourdomain.com -> <YOUR_VPS_IP>`
  - *Testing alternative:* You can use a wildcard DNS service like `<YOUR_VPS_IP>.nip.io`.

---

## 2. Oracle Cloud Infrastructure (OCI) Firewall Configuration

Before starting software setup, ensure that OCI virtual cloud network (VCN) allows incoming web traffic.

### OCI Console Steps:
1. Log in to the [Oracle Cloud Console](https://cloud.oracle.com/).
2. Navigate to **Networking** > **Virtual Cloud Networks (VCN)**.
3. Click your instance's VCN, then click **Security Lists** > **Default Security List for your VCN**.
4. Click **Add Ingress Rules** and add the following rules:

| Source CIDR | IP Protocol | Destination Port Range | Description |
|---|---|---|---|
| `0.0.0.0/0` | TCP | `80` | HTTP / ACME Let's Encrypt challenge |
| `0.0.0.0/0` | TCP | `443` | HTTPS encrypted WebUI access |
| `0.0.0.0/0` | UDP | `443` | HTTP/3 QUIC (optional, recommended) |
| `Your-Admin-IP/32` (or `0.0.0.0/0`) | TCP | `22` | Secure SSH management |

> [!WARNING]
> Never open ports `11434` (Ollama), `8080` (Open WebUI internal), or `6333` (Qdrant) in OCI Ingress Rules. They must remain internal.

---

## 3. Automated Quick Installation

On your Oracle Cloud VPS, clone or upload this repository and run the master installer:

```bash
# 1. Navigate to the repository directory
cd oracle-ai-server

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. Copy and customize your environment configuration
cp .env.example .env
nano .env   # Set AI_DOMAIN (e.g. ai.yourdomain.com) and LETSENCRYPT_EMAIL

# 4. Execute master installer
./scripts/install.sh
```

The script will automatically:
1. Validate Ubuntu version, ARM64 architecture, 4 OCPUs, 24GB RAM, and disk space.
2. Install official Docker Engine and Docker Compose for Ubuntu ARM64.
3. Configure UFW firewall and Fail2ban for SSH protection.
4. Generate a 256-bit cryptographically secure `WEBUI_SECRET_KEY`.
5. Launch Ollama, Open WebUI, and Caddy.
6. Verify container health status.

---

## 4. Manual Step-by-Step Installation

If you prefer executing each phase manually, follow these commands:

### Step 4.1: Preflight Verification
```bash
./scripts/preflight-check.sh
```

### Step 4.2: Install Docker Engine & Compose
```bash
./scripts/setup-docker.sh
# Apply docker group permissions to current session:
newgrp docker
```

### Step 4.3: Configure Host Firewall & Fail2ban
```bash
./scripts/setup-firewall.sh
```

### Step 4.4: Prepare Environment File
```bash
cp .env.example .env
# Generate a secret key
sed -i "s|WEBUI_SECRET_KEY=.*|WEBUI_SECRET_KEY=$(openssl rand -hex 32)|" .env
chmod 600 .env
```

### Step 4.5: Launch Core Services
```bash
./scripts/deploy.sh
```

---

## 5. Post-Installation: Initial Admin Setup

1. Open your browser and navigate to:
   ```
   https://ai.yourdomain.com
   ```
2. Click **Sign Up** to create your primary administrator account. The very first registered user is automatically granted full admin rights.
3. Once logged in, disable open registration to protect your server:
   - Go to **Admin Panel** > **Settings** > **General** > toggle **Enable Signups** to `OFF`.
   - Alternatively, edit `.env`:
     ```bash
     ENABLE_SIGNUP=false
     ./scripts/deploy.sh
     ```

---

## 6. Install AI Models

Download recommended models:

```bash
# Install Qwen 2.5 3B (Fast general model) and BGE-M3 (Embeddings for RAG)
./scripts/install-models.sh --recommended

# Or install the coding-specialized model:
./scripts/install-models.sh --coder

# Or launch the interactive selector:
./scripts/install-models.sh
```

