# ManageCare — Deployment Guide

## Prerequisites (VPS)

- Ubuntu 24.04 (or similar)
- PostgreSQL 16+
- Node.js 18+
- PM2 (`npm install -g pm2`)
- Nginx
- MinIO (already running on port 9000)
- Certbot (for SSL)

## Files in this directory

| File | Purpose |
|------|---------|
| `nginx-managecare.conf` | Nginx reverse proxy config (HTTP→HTTPS, WebSocket, rate limiting) |
| `backup-db.sh` | Daily PostgreSQL backup script (compressed, with retention & optional MinIO upload) |
| `monitoring.sh` | Health check, DB check, disk/memory alerts, auto-recovery via PM2 |

---

## Quick Start on Fresh VPS

### 1. Nginx

```bash
sudo cp deploy/nginx-managecare.conf /etc/nginx/sites-available/managecare
sudo ln -s /etc/nginx/sites-available/managecare /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 2. SSL Certificate

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d backend.managecare.info
```

### 3. Run Migrations

```bash
# Migration 008: notifications + device_tokens
psql -U postgres -d managecare -f managecare-1/migrations/008_notifications_and_devices.sql

# Migration 009: business_members, realtime_subscriptions, sync_audit_log + indexes
psql -U postgres -d managecare -f managecare-1/migrations/009_missing_objects.sql
```

### 4. Start/Restart Backend

```bash
cd /opt/managecare-backend

# Install dependencies
npm install

# Restart with PM2
pm2 restart managecare-backend
pm2 save

# Verify health
curl http://localhost:3000/api/health
```

### 5. Database Backup (cron)

```bash
sudo crontab -e
# Add:
0 2 * * * /opt/managecare-backend/deploy/backup-db.sh >> /var/log/managecare-backup.log 2>&1
```

### 6. Monitoring (cron)

```bash
sudo crontab -e
# Add:
*/5 * * * * /opt/managecare-backend/deploy/monitoring.sh

# Optional: configure Slack alerts
sudo sh -c 'echo "SLACK_WEBHOOK_URL=https://hooks.slack.com/services/..." >> /etc/environment'
```

---

## API Endpoints (after deployment)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/health` | No | Health check |
| POST | `/api/auth/login` | No | Login (JWT) |
| POST | `/api/auth/register` | No | Register worker |
| POST | `/api/push/register` | JWT | Register device for push |
| DELETE | `/api/push/device/:deviceId` | JWT | Unregister device |
| POST | `/api/push/send` | JWT | Send notification |
| GET | `/api/notifications/unread/:userId` | JWT | Unread notifications |
| GET | `/api/notifications/:userId` | JWT | All notifications (paginated) |
| PUT | `/api/notifications/:id/read` | JWT | Mark read |
| PUT | `/api/notifications/read-all/:userId` | JWT | Mark all read |
| DELETE | `/api/notifications/:id` | JWT | Delete notification |
| POST | `/api/upload/:businessId` | JWT | File upload (→ MinIO) |
| GET/POST/PUT/DELETE | `/api/inventory/*` | JWT | Inventory CRUD |
| GET/POST/PUT/DELETE | `/api/sales/*` | JWT | Sales CRUD |
| GET/POST/PUT/DELETE | `/api/customers/*` | JWT | Customer CRUD |
| GET/POST/PUT/DELETE | `/api/workers/*` | JWT | Worker CRUD |
| GET/POST/PUT/DELETE | `/api/expenses/*` | JWT | Expense CRUD |
| GET | `/api/businesses` | JWT | List user's businesses |
| GET | `/api/businesses/:id` | JWT | Get business details |
| POST | `/api/subscriptions/validate/:businessId` | JWT | Validate subscription |

## WebSocket Events (Socket.IO)

| Event | Direction | Description |
|-------|-----------|-------------|
| `join_business` | Client→Server | Join a business room for notifications |
| `join_user` | Client→Server | Join a user's personal room |
| `notification` | Server→Client | New push notification |
| `device_registered` | Server→Client | Device registration confirmed |
| `new_attendance` | Server→Client | Real-time attendance from ADMS device |
