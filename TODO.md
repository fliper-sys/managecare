# Firebase → Self-Hosted Database Migration - TODO

## ✅ PHASE 1: Backend API (Complete)
- [x] functions/db/schema.sql — Complete PostgreSQL schema
- [x] functions/server.js — Express.js entry (all routes, ADMS, Socket.IO)
- [x] functions/middleware/auth.js — JWT + session auth
- [x] functions/middleware/validation.js — Request validation
- [x] functions/routes/inventory.js — Inventory CRUD
- [x] functions/routes/sales.js — Sales records
- [x] functions/routes/customers.js — Customer management
- [x] functions/routes/workers.js — Worker management
- [x] functions/routes/expenses.js — Expense tracking
- [x] functions/routes/upload.js — MinIO file upload

## ✅ PHASE 2: Supabase Repository Layer (Complete)
### Core Repositories
- [x] sales_repository_supabase.dart — Full CRUD + offline sync
- [x] auth_repository_supabase.dart — GoTrue + profile/membership
- [x] inventory_repository_supabase.dart — CRUD + search/low-stock + offline
- [x] business_repository_supabase.dart — CRUD + RPC for owner membership
- [x] customer_repository_supabase.dart — CRUD + search + top customers
- [x] worker_repository_supabase.dart — CRUD + attendance + admin API

### Industry-Specific Repositories
- [x] auto_repository_supabase.dart
- [x] drink_repository_supabase.dart
- [x] gym_repository_supabase.dart
- [x] hotel_repository_supabase.dart
- [x] agri_repository_supabase.dart
- [x] real_estate_repository_supabase.dart
- [x] retail_repository_supabase.dart
- [x] pharmacy_repository_supabase.dart
- [x] restaurant_repository_supabase.dart
- [x] salon_repository_supabase.dart

## ✅ PHASE 3a: Supabase Service Layer (Complete)
- [x] subscription_service_supabase.dart — Supabase-backed subscription management

## ✅ PHASE 3b: Provider & Service Migration (Complete)
- [x] auth_provider_supabase.dart — Supabase-only AuthProvider (GoTrue + Postgres realtime, no Firebase)
- [x] sync_service_supabase.dart — Supabase/Postgres-backed sync (targets Express API, retry logic)
- [x] deletion_recovery_service_supabase.dart — Postgres-backed soft-delete/recovery (30-day grace period)

## ✅ PHASE 4: main.dart Cleanup (Complete)
- [x] Replace blocking `_initializeFirebase()` with non-fatal `_initializeFirebaseIfAvailable()`
- [x] Firebase init wrapped in try/catch — startup cannot be blocked by missing Firebase config
- [x] All business data flows through Supabase/Postgres; Firebase is push-notifications-only
- [ ] Remove Firebase packages from pubspec.yaml — deferred until push notification migration decided

## ✅ PHASE 5: Offline Sync Re-targeting (Complete)
- [x] `lib/services/sync_service.dart` — Rewritten to target Postgres API (no Firestore)
- [x] `lib/providers/sync_provider.dart` — Removed cloud_firestore/firebase_service imports
- [x] `lib/services/offline_sales_service.dart` — Routes to Postgres API online, SQLite offline
- [x] `lib/data/repositories/inventory_repository_supabase.dart` — Stream fixed with client-side filtering
- [ ] Handle conflict resolution (deferred)

## ✅ PHASE 6: MinIO Flutter Storage Integration (Complete)
- [x] `lib/services/minio_storage_service.dart` — Created. Uploads files to backend.managecare.info/api/upload/:businessId which forwards to MinIO on VPS port 9000. Supports file upload, raw bytes upload, metadata retrieval, URL verification.
- [x] Backend route `POST /api/upload/:businessId` already exists in `functions/routes/upload.js` with MinIO forwarding
- [x] MinIO client already initialized in `functions/server.js` (port 9000, bucket `managecare-files`)
- [ ] Wire CloudStorageService/FileUploadService to use MinioStorageService instead of globalthrivealliance.com PHP endpoint

## ✅ PHASE 7: Push Notification Backend Routes (COMPLETE)
- [x] `functions/routes/push.js` — Full implementation with all endpoints
- [x] `device_tokens` table for device registration
- [x] `notifications` table for persistent notification queue
- [x] Socket.IO integration for real-time delivery
- [x] Migration 008 created for device_tokens + notifications tables

## ✅ PHASE 8: MinIO File Upload Wiring (COMPLETE)
- [x] `lib/services/cloud_storage_service.dart` — Rewired to MinioStorageService
- [x] `lib/services/services_initializer.dart` — Fixed initialization
- [x] `lib/services/file_upload_service.dart` — Deprecated (PHP endpoint replaced)

## ✅ PHASE 9: Sync Conflict Resolution (COMPLETE)
- [x] `_resolveConflict()` — last-writer-wins via `updated_at` timestamps
- [x] `_parseUpdatedAt()` — robust timestamp parsing
- [x] `_syncSaleToApi()` — conflict-aware sync with 404→POST fallback

## ✅ PHASE 10: Missing DB Objects Migration (COMPLETE)
- [x] Migration 009: `business_members` table, `sync_audit_log`, `realtime_subscriptions`
- [x] Missing indexes (low stock, business active, profiles email)
- [x] Auto-update trigger for `updated_at` on key tables
- [x] Updated `get_daily_sales_summary` with fixed aggregation
- [x] New `get_pending_sync_count` function

## ✅ PHASE 11: Deployment & Infrastructure (COMPLETE)
- [x] `deploy/nginx-managecare.conf` — Nginx reverse proxy with:
  - [x] HTTP→HTTPS redirect via Certbot
  - [x] Socket.IO WebSocket passthrough (upgrade headers, long timeout)
  - [x] Security headers (X-Frame-Options, X-Content-Type-Options, HSTS)
  - [x] Rate limiting zone (api) + 10MB max upload
  - [x] All API proxy_pass routes
- [x] `deploy/backup-db.sh` — PostgreSQL backup script with:
  - [x] Compressed custom-format pg_dump
  - [x] 30-day retention via mtime-based cleanup
  - [x] Optional MinIO/S3 upload for off-site storage
  - [x] Integrity verification (gzip -t)
  - [x] Cron-ready (daily at 2am)
- [x] `deploy/monitoring.sh` — Health monitoring with:
  - [x] HTTP health check with auto-recovery (PM2 restart)
  - [x] PostgreSQL connectivity check
  - [x] Disk usage alert (>85%)
  - [x] Memory alert (<500MB free)
  - [x] PM2 process status check
  - [x] Slack webhook + email alerting
  - [x] Runs every 5 minutes via cron
- [x] `deploy/README.md` — Complete deployment guide with:
  - [x] Step-by-step VPS setup instructions
  - [x] All API endpoint reference table
  - [x] WebSocket/Socket.IO event reference
  - [x] Migration commands
  - [x] Cron setup instructions
