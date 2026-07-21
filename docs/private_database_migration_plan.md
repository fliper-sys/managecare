# Private Database Migration Plan

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
