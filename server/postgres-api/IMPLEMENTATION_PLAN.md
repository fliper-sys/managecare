# ManageCare PostgreSQL API Implementation Plan

## Goal
Build a private PostgreSQL backend for the Manage Care app, deploy it on an Ubuntu VPS, and migrate Firestore data into the new schema.

## Phase 1: Foundation
1. Install PostgreSQL on Ubuntu.
2. Create the `managecare` database and `managecare` user.
3. Enable PostgreSQL service and verify port 5432.
4. Create the schema from `schema.sql`.
5. Build a minimal API with health, products, sales, and procurements endpoints.
6. Add Docker support for local development and deployment.

## Phase 2: Data Migration
1. Configure Firebase service account via `.env`.
2. Run `npm install` to install dependencies.
3. Use `npm run migrate` to migrate Firestore collections into PostgreSQL.
4. Validate counts and sample rows for `businesses`, `products`, `sales`, and `procurements`.
5. Update the migration script if Firestore document fields differ.

## Phase 3: API Expansion
1. Add endpoints for `businesses`, `users`, and inventory operations.
2. Add secure authentication (JWT or API key).
3. Add input validation and consistent error handling.
4. Add pagination and filtering for read endpoints.
5. Add audit and soft-delete support if needed.

## Phase 4: Flutter Integration
1. Create a new API client in the Flutter app.
2. Replace one inventory screen to read from the new API.
3. Replace one sales flow to write to the new backend.
4. Add loading and network error states in the app.
5. Validate the new flow end to end.

## Phase 5: Production Readiness
1. Use environment variables in production.
2. Restrict PostgreSQL access to trusted IPs only.
3. Add HTTPS via reverse proxy (Nginx) or a managed TLS certificate.
4. Add database backups and restore procedures.
5. Add logging and health monitoring.

## First Most Important Milestone
- Ubuntu server ready with PostgreSQL
- New `managecare` database created
- `schema.sql` applied successfully
- API returns products from PostgreSQL
- Migration script can move one collection from Firestore
- Docker deployment works locally
