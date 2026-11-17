# Backup & Disaster Recovery Guide

This guide details procedures for backing up, verifying, and restoring the Oracle Cloud Personal AI Server.

---

## 1. Backup Scope

The automated backup script (`scripts/backup.sh`) creates a standalone, self-contained archive containing:

1. **Open WebUI Persistent Data:**
   - SQLite database (`webui.db`) containing user profiles, permissions, API keys, chat sessions, document collections, and prompt templates.
   - User-uploaded RAG documents (PDFs, Markdown, DOCX, CSV).
2. **Caddy TLS & Configuration:**
   - Active SSL/TLS certificates and ACME account keys.
   - Avoids rate-limiting penalties from Let's Encrypt upon redeployment.
3. **Environment and Orchestration:**
   - `compose.yaml`, `Caddyfile`, and protected `.env` configuration.
4. **Model Metadata Manifest:**
   - List of installed models and tags for rapid re-download.

---

## 2. Creating a Backup

Execute the backup script from the project directory:

```bash
./scripts/backup.sh
```

### What Happens:
- Temporary snapshot is created via an ephemeral Alpine container attached to Docker volumes.
- Volume contents are archived and compressed into `backups/oracle_ai_backup_<TIMESTAMP>.tar.gz`.
- Permissions are set to `0600` (read/write by owner only).
- A `.sha256` integrity file is generated alongside the archive.
- The retention policy is evaluated: older archives beyond the latest 7 are automatically pruned.

---

## 3. Restoring from a Backup

To restore your system from an existing backup:

```bash
./scripts/restore.sh backups/oracle_ai_backup_YYYYMMDD_HHMMSS.tar.gz
```

### Safety Features:
1. **Integrity Check:** The script validates the archive against its SHA256 checksum. If corrupted, execution halts immediately.
2. **Explicit Confirmation:** Prompts for confirmation before overwriting existing data volumes.
3. **Clean Container Stop:** Safely shuts down running containers to prevent SQLite lock contention.
4. **Volume Restoration:** Extracts archived data directly into `oracle_ai_webui_data` and `oracle_ai_caddy_data`.
5. **Automatic Health Verification:** Starts the stack and runs health checks.

---

## 4. Scheduling Automated Backups (Cron)

To configure an automated daily backup at 03:00 AM UTC:

1. Open user crontab:
   ```bash
   crontab -e
   ```
2. Add the following entry:
   ```cron
   0 3 * * * /bin/bash /home/ubuntu/oracle-ai-server/scripts/backup.sh >> /home/ubuntu/oracle-ai-server/backups/backup.log 2>&1
   ```

---

## 5. Offsite / Disaster Recovery Strategy

To safeguard against total VPS loss, copy the compressed backup file to a remote machine or storage bucket:

```bash
# Example: Copy to local machine via SCP
scp -i ~/.ssh/oracle_vps.key ubuntu@<YOUR_VPS_IP>:/home/ubuntu/oracle-ai-server/backups/*.tar.gz ./local_backups/
```

