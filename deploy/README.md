# ManageCare Deployment Guide

## Prerequisites
- VPS root access via SSH
- PM2 running managecare-backend
- PostgreSQL running on localhost

## Deployment Steps

### Step 1: Upload Files from Local Machine
```bash
# From your local machine (C:\Users\USER\Desktop\mc)
scp managecare-1/migrations/008_notifications_and_devices.sql root@backend.managecare.info:/opt/managecare-backend/migration_008.sql
scp managecare-1/migrations/009_missing_objects.sql root@backend.managecare.info:/opt/managecare-backend/migration_009.sql
scp functions/server.js root@backend.managecare.info:/opt/managecare-backend/server.js
scp functions/routes/push.js root@backend.managecare.info:/opt/managecare-backend/routes/push.js
scp deploy/backup-db.sh root@backend.managecare.info:/opt/managecare-backend/backup-db.sh
scp deploy/monitoring.sh root@backend.managecare.info:/opt/managecare-backend/monitoring.sh
```

### Step 2: SSH and Run Migrations
```bash
ssh root@backend.managecare.info

# On VPS:
cd /opt/managecare-backend

# Backup current server.js before replacing
cp server.js server.js.bak

# Run Migration 008 — Push Notifications Tables
sudo -u postgres psql -d managecare -f migration_008.sql

# Run Migration 009 — Missing Objects
sudo -u postgres psql -d managecare -f migration_009.sql

# Restart backend
pm2 restart managecare-backend && pm2 save

# Verify health
curl -s http://localhost:3000/api/health

# Test auth endpoint
curl -s -X POST http://localhost:3000/auth/v1/token \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test","grant_type":"password"}'

echo "Deployment complete!"
```

### Step 3: Verify
1. **Health Check**: `curl http://localhost:3000/api/health` should return `{"status":"ok"}`
2. **Auth**: `curl -X POST http://localhost:3000/auth/v1/token` should return JWT tokens
3. **Notifications**: `curl http://localhost:3000/api/push/unread/{userId}` should work

### Quick Deploy Script (copy-paste into VPS)
```bash
cd /opt/managecare-backend && \
echo "=== MIGRATION 008 ===" && \
sudo -u postgres psql -d managecare -f migration_008.sql && \
echo "=== MIGRATION 009 ===" && \
sudo -u postgres psql -d managecare -f migration_009.sql && \
echo "=== RESTARTING ===" && \
pm2 restart managecare-backend && pm2 save && \
echo "=== HEALTH ===" && \
curl -s http://localhost:3000/api/health && \
echo "" && \
echo "=== AUTH TEST ===" && \
curl -s -X POST http://localhost:3000/auth/v1/token \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test","grant_type":"password"}' && \
echo "" && \
echo "=== DONE ==="
