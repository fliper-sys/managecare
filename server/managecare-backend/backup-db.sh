#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Database Backup Script — ManageCare PostgreSQL
# ═══════════════════════════════════════════════════════════════
# Install in cron:
#   sudo crontab -e
#   # Daily at 2am
#   0 2 * * * /opt/managecare-backend/deploy/backup-db.sh >> /var/log/managecare-backup.log 2>&1
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ────────────────────────────────────────────
BACKUP_DIR="/opt/managecare-backend/backups"
DB_NAME="${DB_NAME:-managecare}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
S3_BUCKET="${S3_BUCKET:-}"  # Optional: mc alias for MinIO upload
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
LATEST_LINK="${BACKUP_DIR}/latest.sql.gz"

# ── Create backup directory ──────────────────────────────────
mkdir -p "${BACKUP_DIR}"

# ── Log start ────────────────────────────────────────────────
echo "[$(date -Iseconds)] Starting backup of database: ${DB_NAME}"

# ── Dump database (compressed) ──────────────────────────────
PGPASSWORD="${DB_PASSWORD:-}" pg_dump \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --format=custom \
    --verbose \
    --no-owner \
    --no-acl \
    2>> "${BACKUP_DIR}/dump.log" \
    | gzip > "${BACKUP_FILE}"

BACKUP_SIZE=$(stat --printf="%s" "${BACKUP_FILE}" 2>/dev/null || echo 0)
echo "[$(date -Iseconds)] Backup completed: ${BACKUP_FILE} (${BACKUP_SIZE} bytes)"

# ── Update latest symlink ────────────────────────────────────
ln -sf "${BACKUP_FILE}" "${LATEST_LINK}"

# ── Retention: remove backups older than RETENTION_DAYS ────
find "${BACKUP_DIR}" -name "${DB_NAME}_*.sql.gz" -mtime "+${RETENTION_DAYS}" -delete
echo "[$(date -Iseconds)] Retention: removed backups older than ${RETENTION_DAYS} days"

# ── Optional: upload to MinIO/S3 ────────────────────────────
if [ -n "${S3_BUCKET}" ]; then
    echo "[$(date -Iseconds)] Uploading to MinIO bucket: ${S3_BUCKET}"
    mc cp "${BACKUP_FILE}" "${S3_BUCKET}/database-backups/" 2>> "${BACKUP_DIR}/s3_upload.log"
    echo "[$(date -Iseconds)] Upload completed"
fi

# ── Verify backup integrity (quick check) ───────────────────
echo "[$(date -Iseconds)] Verifying backup integrity..."
if gzip -t "${BACKUP_FILE}" 2>/dev/null; then
    echo "[$(date -Iseconds)] Backup integrity check: PASSED"
else
    echo "[$(date -Iseconds)] Backup integrity check: FAILED — file may be corrupt"
    exit 1
fi

echo "[$(date -Iseconds)] Backup process completed successfully"
exit 0
