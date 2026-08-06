# Private Database Migration Plan

## Current Configuration Status

The app is now configured to use the private database path as the primary
runtime path:

- Flutter initializes `Supabase.initialize()` with
  `https://backend.managecare.info`.
- `lib/main.dart` uses `providers/auth_provider_supabase.dart`, not the old
  Firebase auth provider.
- `functions/server.js` exposes:
  - `/auth/v1/*` for the Supabase Flutter auth client.
  - `/rest/v1/:table` for the migrated `supabase.from(...)` repositories.
  - `/rest/v1/rpc/create_business_with_owner`.
  - `/rest/v1/rpc/get_daily_sales_summary`.
  - `/api/*` custom backend endpoints.
- PostgreSQL migrations `008` and `009` add notification, device,
  profile-auth, business membership, sync, and realtime-support tables.

Run this readiness check after each deploy:

```powershell
.\tools\check_private_db_readiness.ps1
```

On the VPS, run:

```bash
cd /opt/managecare-backend
git pull
psql -U postgres -d managecare -f managecare-1/migrations/008_notifications_and_devices.sql
psql -U postgres -d managecare -f managecare-1/migrations/009_missing_objects.sql
pm2 restart managecare-backend
pm2 save
```

## Important Remaining Migration Work

The app still contains Firebase-backed modules. Firebase cannot be fully removed
until every `FirebaseFirestore`, `FirebaseAuth`, and `FirebaseStorage` call is
either migrated to Supabase/Postgres/MinIO or intentionally kept for a narrow
legacy/admin/push purpose.

Use this inventory command:

```powershell
rg "FirebaseFirestore|FirebaseAuth|FirebaseStorage|firebase_storage|cloud_firestore|firebase_auth" lib -l
```

High-priority modules to migrate first:

- `lib/providers/business_provider.dart`
- `lib/providers/workers_provider.dart`
- `lib/providers/retail_provider.dart`
- `lib/providers/reports_provider.dart`
- `lib/providers/settings_provider.dart`
- `lib/providers/receipt_settings_provider.dart`
- `lib/providers/notification_provider.dart`
- industry screens that still write direct Firestore subcollections

## Goal
Create a private database layer that can eventually replace or complement Firebase for core business data such as inventory, sales, procurements, and users.

## Recommended Stack
- Database: PostgreSQL
- Backend: Node.js + Express (simple REST API) or a lightweight Dart server
- Migration approach: export from Firestore, transform the data, import into PostgreSQL, then expose it via REST

## Phase 1: Scope the MVP
Start with the smallest useful slice of the app:
- businesses
- users/workers
- products/inventory
- sales
- procurements

This keeps the first release manageable and testable.

## Phase 2: Define the Database Schema
Create core tables:

### businesses
- id (primary key)
- name
- business_type
- created_at
- updated_at

### users
- id (primary key)
- business_id (foreign key)
- email
- full_name
- role
- created_at
- updated_at

### products
- id (primary key)
- business_id (foreign key)
- name
- category
- sku
- barcode
- price
- cost
- quantity
- unit
- is_ingredient
- created_at
- updated_at

### sales
- id (primary key)
- business_id (foreign key)
- customer_name
- total_amount
- payment_method
- status
- created_at
- updated_at

### sale_items
- id (primary key)
- sale_id (foreign key)
- product_id (foreign key)
- quantity
- unit_price
- total_amount
- created_at

### procurements
- id (primary key)
- business_id (foreign key)
- supplier_name
- total_amount
- status
- created_at
- updated_at

### procurement_items
- id (primary key)
- procurement_id (foreign key)
- product_id (foreign key)
- quantity
- unit_price
- total_amount
- created_at

## Phase 3: Build the Migration Script
Create a one-time migration utility that:
1. Reads Firestore collections
2. Converts document data into relational rows
3. Inserts rows into PostgreSQL
4. Logs errors and skipped records

### Migration behavior
- Preserve existing document IDs where possible
- Convert Firestore timestamps to SQL timestamps
- Normalize nested maps and arrays into separate tables
- Validate required fields before insert

## Phase 4: Create a Backend API
Expose a small REST API for the MVP:
- GET /products
- GET /products/:id
- POST /products
- GET /sales
- POST /sales
- GET /procurements
- POST /procurements

Use the API as the bridge between the Flutter app and the private database.

## Phase 5: Update the Flutter App
Start by replacing one feature at a time:
1. Inventory list
2. Sales list
3. Procurement list
4. Reporting screens later

Use a repository abstraction so the app can switch between Firebase and the private API without major rewrites.

## Phase 6: Validation and Reconciliation
After each migration batch:
- compare counts with Firestore
- compare sample rows
- verify totals and relationships
- confirm that data is readable from the app

## Phase 7: Sync Strategy
For the first version, prefer:
- one-way migration from Firebase to the private DB
- then incremental sync later if needed

Later, if you want full parity, add:
- webhook or event-based sync
- dual-write support
- reconciliation jobs

## Suggested Implementation Order
1. Create PostgreSQL database and schema
2. Create migration script
3. Create backend API
4. Seed with a small subset of data
5. Connect Flutter app to the new API
6. Validate one workflow end to end

## MVP Success Criteria
The MVP is successful when:
- inventory items can be read from the private database
- sales can be created and stored privately
- procurement data is visible through the app
- data can be migrated from Firebase without data loss

## Recommended Next Steps
- Create the SQL schema files
- Create a migration script for one collection
- Create a minimal API for inventory and sales
- Connect one Flutter screen to the API
