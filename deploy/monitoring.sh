#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# ManageCare — Health Monitoring & Auto-Recovery
# ═══════════════════════════════════════════════════════════════
# Run every 5 minutes via cron:
#   */5 * * * * /opt/managecare-backend/deploy/monitoring.sh
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ────────────────────────────────────────────
HEALTH_URL="http://localhost:3000/api/health"
LOG_FILE="/var/log/managecare-monitor.log"
PM2_APP_NAME="managecare-backend"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"   # Optional Slack alerting
ALERT_EMAIL="${ALERT_EMAIL:-}"               # Optional email alerting

log() {
    local level="$1"
    local message="$2"
    echo "[$(date -Iseconds)] [${level}] ${message}" >> "${LOG_FILE}"
}

send_alert() {
    local subject="$1"
    local body="$2"

    # Slack
    if [ -n "${SLACK_WEBHOOK_URL}" ]; then
        curl -s -X POST "${SLACK_WEBHOOK_URL}" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"*[ManageCare Alert]* ${subject}\n${body}\"}" \
            > /dev/null 2>&1 || true
    fi

    # Email
    if [ -n "${ALERT_EMAIL}" ]; then
        echo "${body}" | mail -s "[ManageCare] ${subject}" "${ALERT_EMAIL}" || true
    fi
}

# ── 1. Health check ──────────────────────────────────────────
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${HEALTH_URL}" 2>/dev/null || echo "000")

if [ "${HTTP_CODE}" != "200" ]; then
    log "ERROR" "Health check failed with HTTP ${HTTP_CODE}"
    send_alert "Health Check Failed" "HTTP ${HTTP_CODE} from ${HEALTH_URL}. Attempting restart..."

    # Attempt auto-recovery
    log "INFO" "Attempting PM2 restart of ${PM2_APP_NAME}..."
    pm2 restart "${PM2_APP_NAME}" >> "${LOG_FILE}" 2>&1 || true
    sleep 5

    # Verify recovery
    RETRY_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${HEALTH_URL}" 2>/dev/null || echo "000")
    if [ "${RETRY_CODE}" == "200" ]; then
        log "INFO" "Auto-recovery successful — application is healthy after restart"
        send_alert "Auto-Recovery Successful" "Application restarted and is now healthy."
    else
        log "CRITICAL" "Auto-recovery FAILED — HTTP ${RETRY_CODE} after restart"
        send_alert "CRITICAL: Auto-Recovery Failed" "Application is down after restart. Immediate attention required."
    fi
else
    log "INFO" "Health check passed (HTTP 200)"
fi

# ── 2. Database connectivity check ──────────────────────────
DB_CHECK=$(psql -U postgres -d managecare -c "SELECT 1 AS ok;" 2>/dev/null | grep -c "1" || echo "0")
if [ "${DB_CHECK}" -eq 0 ]; then
    log "ERROR" "Database connectivity check FAILED"
    send_alert "Database Down" "Cannot connect to PostgreSQL database."
else
    log "INFO" "Database connectivity: OK"
fi

# ── 3. Disk usage check (alert if over 85%) ─────────────────
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "${DISK_USAGE}" -gt 85 ]; then
    log "WARN" "Disk usage at ${DISK_USAGE}% — exceeds 85% threshold"
    send_alert "Disk Space Warning" "Disk usage is at ${DISK_USAGE}% on root partition."
fi

# ── 4. Memory check (alert if under 500MB free) ────────────
MEM_FREE=$(free -m | awk '/^Mem:/ {print $7}')
if [ "${MEM_FREE}" -lt 500 ]; then
    log "WARN" "Low memory: ${MEM_FREE}MB free — below 500MB threshold"
    send_alert "Low Memory Warning" "Only ${MEM_FREE}MB free memory available."
fi

# ── 5. PM2 process status ──────────────────────────────────
PM2_STATUS=$(pm2 show "${PM2_APP_NAME}" 2>/dev/null | grep -c "online" || echo "0")
if [ "${PM2_STATUS}" -eq 0 ]; then
    log "ERROR" "PM2 process ${PM2_APP_NAME} is not running"
    send_alert "PM2 Process Down" "${PM2_APP_NAME} is not in 'online' status."
fi

log "INFO" "Monitoring check completed"
exit 0
