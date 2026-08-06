# ManageCare Database Architecture

> **Version:** 1.0.0  
> **Engine:** PostgreSQL 16+  
> **Extensions:** `uuid-ossp`  
> **Migration Strategy:** Sequential SQL files in `managecare-1/migrations/`

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Entity Relationship Diagram](#2-entity-relationship-diagram)
3. [Core Tables](#3-core-tables)
4. [Supporting Tables](#4-supporting-tables)
5. [Migration 008: Push Notifications](#5-migration-008-push-notifications)
6. [Migration 009: Missing Objects](#6-migration-009-missing-objects)
7. [Indexes](#7-indexes)
8. [Functions & Stored Procedures](#8-functions--stored-procedures)
9. [Triggers](#9-triggers)
10. [Row-Level Security (RLS)](#10-row-level-security-rls)
11. [Data Flow & Integration](#11-data-flow--integration)
12. [Backend API Routes](#12-backend-api-routes)
13. [Performance Considerations](#13-performance-considerations)
14. [Migration Guide](#14-migration-guide)

---

## 1. Architecture Overview

ManageCare is a **multi-tenant PostgreSQL database** powering a business management platform. It replaces a legacy Firebase/Firestore backend with a fully self-hosted solution.

### Key Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Multi-tenancy** | Every record has a `business_id` column + RLS policies enforce isolation |
| **UUID Primary Keys** | All tables use `uuid_generate_v4()` for distributed/offline ID generation |
| **Soft-delete** | Most tables have `is_active` boolean column instead of hard deletes |
| **Timestamp Tracking** | `created_at` + `updated_at` on all core tables with auto-update triggers |
| **Offline Sync** | `sync_audit_log` tracks offline→online sync activity with conflict metadata |
| **Real-time** | Socket.IO integration + `realtime_subscriptions` + `notifications` table |
| **Biometric ADMS** | `/iclock/cdata` endpoint receives punch data from Hippoint F16 devices |

### Database Connection

```env
DB_HOST=localhost        # or VPS IP
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=<from VPS /root/managecare-minio-credentials.txt>
DB_NAME=managecare
DB_POOL_MAX=20
```

### Schema Files

| File | Purpose | Tables Added |
|------|---------|-------------|
| `functions/db/schema.sql` | Complete initial schema | Profiles, businesses, inventory, sales, sale_items, customers, workers, attendance, devices, expenses, procurements, distributors, subscription_transactions |
| `managecare-1/migrations/008_notifications_and_devices.sql` | Push notifications | `device_tokens`, `notifications` |
| `managecare-1/migrations/009_missing_objects.sql` | Missing infrastructure | `business_members`, `realtime_subscriptions`, `sync_audit_log` |

### Total Tables: **18** | Indexes: **25+** | Functions: **4** | Triggers: **3**

---

## 2. Entity Relationship Diagram

```
┌──────────────────────┐
│     profiles (GoTrue)│ ◄────── auth.users (auto-created on signup)
└─────────┬────────────┘
          │
          ▼
┌──────────────────────┐       ┌──────────────────────┐
│   business_members   │ ◄─────│      businesses      │
│ (user_id, business_id,│       │  (multi-tenant root) │
│  role, is_owner)      │       └──────────┬───────────┘
└──────────────────────┘                    │
                                            │
          ┌─────────────────────────────────┼──────────────────────────────┐
          │              │                  │              │               │
          ▼              ▼                  ▼              ▼               ▼
┌──────────────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────┐ ┌──────────────┐
│    inventory     │ │  sales   │ │  customers   │ │ workers  │ │ subscription_│
│ (products/stock) │ └────┬─────┘ │              │ └────┬─────┘ │ transactions │
└──────────────────┘      │       └──────────────┘      │       └──────────────┘
                          ▼                              │
                  ┌──────────────┐                       ▼
                  │  sale_items  │               ┌──────────────┐
                  │ (line items) │               │  attendance  │
                  └──────────────┘               │ (biometric)  │
                                                 └──────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│    expenses      │  │  procurements    │  │  distributors    │
└──────────────────┘  └──────────────────┘  └──────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  device_tokens   │  │  notifications   │  │    devices       │
│ (push delivery)  │  │ (notification q) │  │ (ADMS hardware)  │
└──────────────────┘  └──────────────────┘  └──────────────────┘

┌──────────────────┐  ┌──────────────────┐
│ realtime_subscrip.│  │ sync_audit_log   │
│ (Socket.IO)      │  │ (offline sync)   │
└──────────────────┘  └──────────────────┘
```

---

## 3. Core Tables

### 3.1 `profiles` — User Profiles

Extends GoTrue `auth.users`. Auto-populated via trigger.

```sql
CREATE TABLE profiles (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),  -- matches auth.users.id
  email      TEXT,
  full_name  TEXT,
  pin        TEXT,                -- POS quick-login PIN
  current_business_id UUID REFERENCES businesses(id),
  phone_number TEXT,
  photo_url  TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Auto-creation trigger** (in schema.sql):
```sql
CREATE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

---

### 3.2 `businesses` — Tenant Root

Every record in the system belongs to a business.

```sql
CREATE TABLE businesses (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                  TEXT NOT NULL DEFAULT '',
  owner_id              UUID REFERENCES profiles(id),
  business_type         TEXT,         -- retail, gas, restaurant, pharmacy, gym, hotel, salon, agri, real_estate, auto, drink
  address               TEXT,
  phone                 TEXT,
  email                 TEXT,
  currency              TEXT DEFAULT 'NGN',
  logo_url              TEXT,
  store_ids             UUID[] DEFAULT '{}',
  is_active             BOOLEAN DEFAULT true,
  last_sku_number       INTEGER DEFAULT 0,
  subscription_tier     TEXT DEFAULT 'free',     -- free, basic, premium
  subscription_start_date TIMESTAMPTZ,
  subscription_end_date   TIMESTAMPTZ,
  is_subscription_active  BOOLEAN DEFAULT false,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);
```

**Key business_type values:**

| Type | Industry | Features |
|------|----------|----------|
| `retail` | Retail/General Store | POS, inventory, customers, loyalty |
| `gas` | Gas Station | Pump management, nozzle tracking, daily uploads |
| `restaurant` | Restaurant/Cafe | Table management, menu, kitchen tickets |
| `pharmacy` | Pharmacy | Drug expiry tracking, prescription management |
| `gym` | Gym/Fitness | Membership, attendance, class scheduling |
| `hotel` | Hotel/Lodging | Room booking, check-in/out, housekeeping |
| `salon` | Salon/Spa | Appointment booking, service menu |
| `agri` | Agriculture | Crop tracking, harvest management |
| `real_estate` | Real Estate | Property listing, tenant management |
| `auto` | Auto Repair | Vehicle tracking, job cards, parts |
| `drink` | Bar/Drink | Tab management, drink menu |

---

### 3.3 `inventory` — Products & Stock

```sql
CREATE TABLE inventory (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  sku             TEXT,
  barcode         TEXT,
  category        TEXT,
  description     TEXT,
  unit_price      DECIMAL(12,2) NOT NULL DEFAULT 0,
  cost_price      DECIMAL(12,2) DEFAULT 0,
  quantity        DECIMAL(12,2) NOT NULL DEFAULT 0,
  min_stock_level DECIMAL(12,2) DEFAULT 0,
  unit            TEXT DEFAULT 'pcs',    -- pcs, kg, L, box, etc.
  expiry_date     TIMESTAMPTZ,
  store_id        UUID,                  -- multi-store assignment
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Indexes:**
- `idx_inventory_business` — Lookup by business
- `idx_inventory_low_stock` — Partial index: `WHERE quantity <= min_stock_level` (dashboard alert)
- `idx_inventory_category` — Category-based filtering
- `idx_inventory_sku` — SKU lookup

---

### 3.4 `sales` — Sales Transactions

```sql
CREATE TABLE sales (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id     UUID,                    -- FK → customers
  store_id        UUID,
  worker_id       UUID,                    -- FK → workers
  worker_name     TEXT,
  total_amount    DECIMAL(12,2) NOT NULL,
  discount_amount DECIMAL(12,2) DEFAULT 0,
  tax_amount      DECIMAL(12,2) DEFAULT 0,
  final_amount    DECIMAL(12,2) NOT NULL,
  payment_method  TEXT NOT NULL,           -- cash, card, transfer, pos
  status          TEXT NOT NULL DEFAULT 'completed',  -- completed, refunded, voided, pending
  notes           TEXT,
  created_by      UUID NOT NULL,
  sale_type       TEXT DEFAULT 'retail',   -- retail, wholesale, bakery, fuel
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Indexes:**
- `idx_sales_business` — Business lookup
- `idx_sales_created` — `(created_at DESC)` — daily/weekly/monthly reports
- `idx_sales_status` — Filter by status
- `idx_sales_payment` — Payment method analysis

---

### 3.5 `sale_items` — Line Items

```sql
CREATE TABLE sale_items (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sale_id             UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id          UUID,               -- FK → inventory
  product_name        TEXT NOT NULL,       -- denormalized for speed
  quantity            DECIMAL(12,2) NOT NULL,
  unit_price          DECIMAL(12,2) NOT NULL,
  discount            DECIMAL(12,2) DEFAULT 0,
  total               DECIMAL(12,2) NOT NULL,
  pricing_mode        TEXT,               -- simple, variable, weight
  inventory_unit      TEXT,
  sale_unit           TEXT,               -- for unit-conversion sales
  sale_unit_multiplier DECIMAL(12,2) DEFAULT 1
);
```

**Index:** `idx_sale_items_sale` on `sale_id`

---

### 3.6 `customers` — Customer Records

```sql
CREATE TABLE customers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  email           TEXT,
  phone           TEXT,
  address         TEXT,
  city            TEXT,
  state           TEXT,
  loyalty_points  INTEGER DEFAULT 0,
  total_purchases DECIMAL(12,2) DEFAULT 0,  -- count of purchases
  total_spent     DECIMAL(12,2) DEFAULT 0,   -- lifetime value
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Indexes:** `idx_customers_business`, `idx_customers_phone`

---

### 3.7 `workers` — Staff/Employees

```sql
CREATE TABLE workers (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT,
  full_name     TEXT NOT NULL,
  phone         TEXT,
  role          TEXT NOT NULL DEFAULT 'staff',  -- owner, manager, staff, cashier
  business_id   UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  store_id      UUID,
  is_active     BOOLEAN DEFAULT true,
  permissions   JSONB DEFAULT '{}',            -- granular permissions
  pin           TEXT,                          -- POS PIN
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Indexes:** `idx_workers_business`, `idx_workers_email`

---

### 3.8 `attendance` — Biometric Clock-In/Out

Receives data from Hippoint F16 devices via `/iclock/cdata`.

```sql
CREATE TABLE attendance (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id        UUID REFERENCES workers(id) ON DELETE SET NULL,
  business_id      UUID REFERENCES businesses(id) ON DELETE CASCADE,
  device_sn        TEXT,                    -- device serial number
  user_id_on_device TEXT,                   -- user id on device
  timestamp        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status           TEXT,                    -- 0=In, 1=Out, 2=BreakOut, 3=BreakIn, 4=OTIn, 5=OTOut
  verify_mode      TEXT,                    -- 0=Password, 1=Fingerprint, 2=Card
  created_at       TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Indexes:** `idx_attendance_worker`, `idx_attendance_timestamp`, `idx_attendance_business`, `idx_attendance_device`

---

### 3.9 `expenses` — Business Expenses

```sql
CREATE TABLE expenses (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  category    TEXT NOT NULL,
  amount      DECIMAL(12,2) NOT NULL,
  description TEXT,
  paid_by     TEXT,
  receipt_url TEXT,           -- MinIO URL
  created_by  UUID,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

### 3.10 `procurements` & `distributors` — Supply Chain

```sql
CREATE TABLE procurements (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  supplier_name TEXT,
  total_amount DECIMAL(12,2) NOT NULL,
  status       TEXT DEFAULT 'pending',     -- pending, approved, received, cancelled
  notes        TEXT,
  created_by   UUID,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE distributors (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id    UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  contact_person TEXT,
  phone          TEXT,
  email          TEXT,
  address        TEXT,
  is_active      BOOLEAN DEFAULT true,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);
```

---

### 3.11 `subscription_transactions` — Billing History

```sql
CREATE TABLE subscription_transactions (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id    UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id        UUID REFERENCES profiles(id),
  amount         DECIMAL(12,2) NOT NULL,
  plan           TEXT NOT NULL,           -- free, basic, premium
  transaction_id TEXT,                    -- payment gateway transaction ID
  status         TEXT DEFAULT 'pending',  -- pending, completed, failed
  reference      TEXT,                    -- merchant reference
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 4. Supporting Tables

### 4.1 `devices` — Biometric/ADMS Hardware Registry

```sql
CREATE TABLE devices (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  serial_number   TEXT UNIQUE NOT NULL,
  business_id     UUID REFERENCES businesses(id),
  name            TEXT,
  last_seen       TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**ADMS Communication Flow:**
```
ADMS Device (Hippoint F16) ──GET /iclock/cdata?SN=xxx──▶ Express API
        ◀─── Configuration Response ────────
        ──POST /iclock/cdata?SN=xxx&table=ATTLOG──▶  (tab-separated punch data)
        ◀─── "OK" ────▶
        
Express API → PostgreSQL INSERT → Socket.IO emit('new_attendance') → Flutter clients
```

---

### 4.2 `business_members` — Multi-User Access (Migration 009)

```sql
CREATE TABLE business_members (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'staff',  -- owner, manager, staff
  is_owner    BOOLEAN DEFAULT false,
  is_active   BOOLEAN DEFAULT true,
  permissions JSONB DEFAULT '{}',
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, business_id)               -- one membership per user per business
);
```

**RLS Usage:** All RLS policies reference this table:
```sql
USING (business_id IN (
  SELECT business_id FROM business_members WHERE user_id = auth.uid()
))
```

---

## 5. Migration 008: Push Notifications

### 5.1 `device_tokens` — Device Registration

```sql
CREATE TABLE device_tokens (
  device_id   VARCHAR(255) PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  platform    VARCHAR(50) DEFAULT 'mobile',  -- mobile, web, desktop
  device_name VARCHAR(255),
  last_seen   TIMESTAMPTZ DEFAULT NOW(),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

**Index:** `idx_device_tokens_user_id` on `user_id`

### 5.2 `notifications` — Notification Queue

```sql
CREATE TABLE notifications (
  id           BIGSERIAL PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  business_id  UUID REFERENCES businesses(id) ON DELETE CASCADE,
  title        VARCHAR(255) NOT NULL,
  body         TEXT NOT NULL,
  type         VARCHAR(50) DEFAULT 'general',  -- general, sale, inventory, attendance, subscription
  data         JSONB,                          -- arbitrary payload
  is_read      BOOLEAN DEFAULT false,
  read_at      TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
```

**Indexes:**
- `idx_notifications_user_id` — Lookup by user
- `idx_notifications_unread` — Partial: `WHERE is_read = false` — fast unread badge
- `idx_notifications_created_at` — `(created_at DESC)` sorting

### Push Notification Flow

```
┌──────────┐    WebSocket     ┌────────────┐   PostgreSQL    ┌──────────┐
│  Flutter  │ ◄──Socket.IO────│ Express.js │ ◄──INSERT/SELECT─│ database │
│   App    │                  │  server.js  │                └──────────┘
└──────────┘                  └──────┬─────┘
       ▲                            │
       │    pushRoutes.js            │
       │                            │
       └────────────────────────────┘
       (via /api/push/register, /api/push/send,
        /api/notifications/unread/:userId, etc.)

1. App start → Socket.IO connect → join_user(userId), join_business(businessId)
2. App calls POST /api/push/register {device_id, user_id, platform}
   → upserts device_tokens row
3. Backend system calls POST /api/push/send {user_id, title, body, type, business_id}
   → INSERT into notifications
   → io.to(`user:${userId}`).emit('notification', notification)
   → io.to(`business:${businessId}`).emit('notification', notification)
4. Flutter receives 'notification' event → shows in-app toast / updates badge
5. App polls or receives → calls GET /api/notifications/unread/:userId for badge count
6. User reads → calls PUT /api/notifications/:id/read (or PUT /read-all/:userId)
```

---

## 6. Migration 009: Missing Objects

### 6.1 `realtime_subscriptions` — Socket.IO Tracking

```sql
CREATE TABLE realtime_subscriptions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID REFERENCES profiles(id) ON DELETE CASCADE,
  business_id     UUID REFERENCES businesses(id) ON DELETE CASCADE,
  socket_id       TEXT,                         -- Socket.IO session ID
  rooms           TEXT[] DEFAULT '{}',           -- rooms joined
  connected_at    TIMESTAMPTZ DEFAULT NOW(),
  disconnected_at TIMESTAMPTZ,
  is_active       BOOLEAN DEFAULT true
);
```

**Indexes:** `idx_realtime_user`, `idx_realtime_business`

### 6.2 `sync_audit_log` — Offline Sync Audit

```sql
CREATE TABLE sync_audit_log (
  id                BIGSERIAL PRIMARY KEY,
  business_id       UUID REFERENCES businesses(id) ON DELETE CASCADE,
  entity_type       TEXT NOT NULL,            -- sale, inventory, customer, worker
  entity_id         TEXT,                     -- record ID being synced
  action            TEXT NOT NULL,             -- create, update, delete
  status            TEXT NOT NULL DEFAULT 'pending',  -- pending, synced, failed, conflict
  conflict_resolved BOOLEAN DEFAULT false,
  local_updated_at  TIMESTAMPTZ,              -- client timestamp
  server_updated_at TIMESTAMPTZ,              -- server timestamp
  payload           JSONB,                    -- full record snapshot
  error_message     TEXT,                     -- error on failure
  synced_by         UUID REFERENCES profiles(id),
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
```

**Indexes:** `idx_sync_audit_business`, `idx_sync_audit_status`, `idx_sync_audit_created`

### 6.3 Additional Indexes Added

```sql
idx_businesses_owner     ON businesses(owner_id)
idx_businesses_active    ON businesses(is_active)
idx_profiles_email       ON profiles(email)
idx_inventory_low_stock  ON inventory(business_id, quantity, min_stock_level)
                         WHERE quantity <= min_stock_level
```

### 6.4 Auto-Update Trigger

Applies to: `inventory`, `sales`, `customers`, `workers`, `expenses`, `procurements`, `distributors`, `business_members`

```sql
CREATE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 6.5 Improved Functions

**get_daily_sales_summary** — Fixed aggregation (proper GROUP BY for payment breakdown):

```sql
CREATE OR REPLACE FUNCTION get_daily_sales_summary(
  p_business_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
  total_sales DECIMAL(12,2),
  transaction_count BIGINT,
  average_sale DECIMAL(12,2),
  payment_breakdown JSONB
) AS $$ ... $$ LANGUAGE plpgsql STABLE;
```

**New: get_pending_sync_count** — Returns count of pending/failed sync items for badge:

```sql
CREATE OR REPLACE FUNCTION get_pending_sync_count(
  p_business_id UUID
) RETURNS INTEGER AS $$ ... $$ LANGUAGE plpgsql STABLE;
```

---

## 7. Indexes

### Complete Index List

| Index Name | Table | Column(s) | Type | Purpose |
|------------|-------|-----------|------|---------|
| `idx_inventory_business` | inventory | business_id | B-tree | Tenant lookup |
| `idx_inventory_category` | inventory | category | B-tree | Category filter |
| `idx_inventory_sku` | inventory | sku | B-tree | SKU lookup |
| `idx_inventory_low_stock` | inventory | business_id, quantity, min_stock_level | **Partial** `WHERE quantity <= min_stock_level` | Low-stock alerts |
| `idx_sales_business` | sales | business_id | B-tree | Tenant lookup |
| `idx_sales_created` | sales | created_at DESC | B-tree | Date-range queries |
| `idx_sales_status` | sales | status | B-tree | Status filter |
| `idx_sales_payment` | sales | payment_method | B-tree | Payment analysis |
| `idx_sale_items_sale` | sale_items | sale_id | B-tree | Line items by sale |
| `idx_customers_business` | customers | business_id | B-tree | Tenant lookup |
| `idx_customers_phone` | customers | phone | B-tree | Phone search |
| `idx_workers_business` | workers | business_id | B-tree | Tenant lookup |
| `idx_workers_email` | workers | email | B-tree | Email lookup |
| `idx_attendance_worker` | attendance | worker_id | B-tree | Worker history |
| `idx_attendance_timestamp` | attendance | timestamp DESC | B-tree | Time-based queries |
| `idx_attendance_business` | attendance | business_id | B-tree | Tenant lookup |
| `idx_attendance_device` | attendance | device_sn | B-tree | Device audit |
| `idx_devices_serial` | devices | serial_number | B-tree | Device lookup |
| `idx_expenses_business` | expenses | business_id | B-tree | Tenant lookup |
| `idx_procurements_business` | procurements | business_id | B-tree | Tenant lookup |
| `idx_distributors_business` | distributors | business_id | B-tree | Tenant lookup |
| `idx_subscription_transactions_business` | subscription_transactions | business_id | B-tree | Tenant lookup |
| `idx_device_tokens_user_id` | device_tokens | user_id | B-tree | User devices |
| `idx_notifications_user_id` | notifications | user_id | B-tree | User notifications |
| `idx_notifications_unread` | notifications | user_id, is_read | **Partial** `WHERE is_read = false` | Unread count |
| `idx_notifications_created_at` | notifications | created_at DESC | B-tree | Sort recency |
| `idx_business_members_user` | business_members | user_id | B-tree | User memberships |
| `idx_business_members_business` | business_members | business_id | B-tree | Business members |
| `idx_business_members_active` | business_members | business_id, is_active | **Partial** `WHERE is_active = true` | Active members (RLS) |
| `idx_realtime_user` | realtime_subscriptions | user_id | B-tree | User connections |
| `idx_realtime_business` | realtime_subscriptions | business_id | B-tree | Business connections |
| `idx_sync_audit_business` | sync_audit_log | business_id | B-tree | Tenant lookup |
| `idx_sync_audit_status` | sync_audit_log | status | B-tree | Status filter |
| `idx_sync_audit_created` | sync_audit_log | created_at DESC | B-tree | Time range |
| `idx_businesses_owner` | businesses | owner_id | B-tree | Owner lookup |
| `idx_businesses_active` | businesses | is_active | B-tree | Active filter |
| `idx_profiles_email` | profiles | email | B-tree | Email lookup |

### Performance Notes

- **Partial indexes** on `idx_notifications_unread` and `idx_inventory_low_stock` are the most frequently hit (dashboard badges + alerts)
- `idx_sales_created DESC` enables efficient daily/weekly/monthly aggregation
- All foreign key columns are indexed (prevents CASCADE scan locks)
- `business_id` indexes on every tenant table ensure RLS policies are fast
- Estimate: ~50KB per index for small tenants, growing linearly with data

---

## 8. Functions & Stored Procedures

### 8.1 `create_business_with_owner(p_name, p_business_type, p_owner_id)`

| Detail | Value |
|--------|-------|
| **Returns** | UUID (new business ID) |
| **Security** | `SECURITY DEFINER` |
| **Caller** | Flutter registration flow |

**Logic:**
1. Creates business record with name, type, owner_id
2. Creates `business_members` record with `role='owner'`, `is_owner=true`
3. Returns the new business UUID

**Used by:** `POST /api/businesses` (via `auth_provider_supabase.dart`)

### 8.2 `get_daily_sales_summary(p_business_id, p_date)`

| Detail | Value |
|--------|-------|
| **Returns** | TABLE(total_sales, transaction_count, average_sale, payment_breakdown) |
| **Stability** | `STABLE` (can be used in read-only replicas) |
| **Caller** | Owner dashboard analytics |

**Returns:**
```json
{
  "total_sales": 125000.00,
  "transaction_count": 47,
  "average_sale": 2659.57,
  "payment_breakdown": [
    {"method": "cash", "total": 75000.00},
    {"method": "card", "total": 35000.00},
    {"method": "transfer", "total": 15000.00}
  ]
}
```

### 8.3 `get_pending_sync_count(p_business_id)`

| Detail | Value |
|--------|-------|
| **Returns** | INTEGER |
| **Stability** | `STABLE` |
| **Caller** | Sync status badge in UI |

**Logic:** Counts `sync_audit_log` rows with `status IN ('pending', 'failed')`

### 8.4 `update_updated_at_column()` (Trigger Function)

| Detail | Value |
|--------|-------|
| **Returns** | TRIGGER |
| **Applied to** | 8 tables (see §6.4) |

**Logic:** Sets `NEW.updated_at = NOW()` before any UPDATE

---

## 9. Triggers

| Trigger Name | Table | Timing | Event | Function |
|-------------|-------|--------|-------|----------|
| `on_auth_user_created` | `auth.users` | AFTER INSERT | User signup | `handle_new_user()` — creates profile |
| `trg_inventory_updated_at` | inventory | BEFORE UPDATE | Any column change | `update_updated_at_column()` |
| `trg_sales_updated_at` | sales | BEFORE UPDATE | Any column change | `update_updated_at_column()` |
| `trg_customers_updated_at` | customers | BEFORE UPDATE | Any column change | `update_updated_at_column()` |
| `trg_workers_updated_at` | workers | BEFORE UPDATE | Any column change | `update_updated_at_column()` |
| `trg_expenses_updated_at` | expenses | BEFORE UPDATE | Any column change | `update_updated_at_column()` |
| `trg_procurements_updated_at` | procurements | BEFORE UPDATE | Any column change | `update_updated_at_column()` |
| `trg_distributors_updated_at` | distributors | BEFORE UPDATE | Any column change | `update_updated_at_column()` |
| `trg_business_members_updated_at` | business_members | BEFORE UPDATE | Any column change | `update_updated_at_column()` |

All `updated_at` triggers are created via a PL/pgSQL DO block in migration 009.

---

## 10. Row-Level Security (RLS)

### Enabled Tables

RLS is enabled on all business-scoped tables:

- `inventory`
- `sales`
- `sale_items`
- `customers`
- `workers`
- `attendance`
- `expenses`
- `procurements`
- `distributors`
- `business_members`

### Isolation Policy

Each policy uses the same `USING` clause to enforce tenant isolation:

```sql
CREATE POLICY business_isolation ON inventory
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));
```

**How it works:**
1. `auth.uid()` returns the current authenticated user's UUID (from JWT)
2. `business_members` join table links users to businesses they have access to
3. The subquery returns all business IDs the user is a member of
4. The policy filters rows to only those whose `business_id` is in that list

**This means:**
- A user can only see records for businesses they belong to
- An owner sees all businesses they own
- A staff member sees only the business(es) they work for
- Unauthenticated requests see zero rows

---

## 11. Data Flow & Integration

### 11.1 Offline Sync Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter App (online mode)                                      │
│                                                                 │
│  SalesScreen ──createSale()──▶ SalesRepositorySupabase ──HTTP──▶│
│      ▲                              │                           │
│      │                              ▼                           │
│      │                        Online success?                   │
│      │                         /        \                      │
│      │                       YES        NO                     │
│      │                        │          │                     │
│      │                        ▼          ▼                     │
│      │                   Return        Save to                 │
│      │                   success       SQLite                  │
│      │                               (syncStatus="pending")    │
│      │                                    │                    │
│      └──────────────── SyncService.syncAll() ──────────────────┘
│                                    │
│                                    ▼
│                          SyncService._syncSaleToApi()
│                          ┌────────────────────────┐
│                          │  PUT /api/sales/:biz/:id│
│                          │  (if 404 → POST)       │
│                          │  includes updated_at   │
│                          └────────────────────────┘
│                                    │
│                                    ▼
│                          Update SQLite syncStatus="synced"
└─────────────────────────────────────────────────────────────────┘

Conflict Resolution (last-writer-wins):
  if local.updated_at > server.updated_at → push local
  else → accept server version
```

### 11.2 File Upload Flow (MinIO)

```
Flutter App ──CloudStorageService.uploadFile()──▶ MinioStorageService
       │                                                 │
       │                                                 ▼
       │                               HTTP POST /api/upload/:businessId
       │                                                 │
       │                                                 ▼
       │                                    Express API (upload.js)
       │                                                 │
       │                                                 ▼
       │                                    MinIO Client (port 9000)
       │                                    Bucket: managecare-files
       │                                                 │
       │                                                 ▼
       │                                    Returns public URL
       └──────────────────────────────────────────────────┘
```

### 11.3 Real-Time Attendance Flow

```
ADMS Device (Hippoint F16)
       │
       │  GET /iclock/cdata?SN=HFF16xxxxx
       │  (handshake + receive config)
       │
       │  POST /iclock/cdata?SN=xxx&table=ATTLOG
       │  (tab-separated punch data)
       ▼
Express API (server.js)
       │
       ├──▶ PostgreSQL INSERT INTO attendance
       │       (device_sn, user_id_on_device, timestamp, status, verify_mode)
       │
       └──▶ Socket.IO emit('new_attendance', record)
               │
               ▼
        Flutter App (AttendanceScreen)
        listens on 'new_attendance' event
        → real-time update in attendance list
```

---

## 12. Backend API Routes

### Public Routes (No Auth)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check (DB, MinIO, uptime) |
| POST | `/api/auth/register` | Register worker |
| POST | `/api/auth/login` | Login → JWT |
| GET | `/iclock/cdata` | ADMS handshake (Hippoint F16) |
| POST | `/iclock/cdata` | ADMS attendance upload |
| GET | `/iclock/getrequest` | ADMS request handler |

### Authenticated Routes (JWT Required)

| Method | Path | Source | Description |
|--------|------|--------|-------------|
| GET | `/api/attendance` | server.js | Attendance records |
| GET/POST/PUT/DELETE | `/api/inventory/*` | inventory.js | Inventory CRUD |
| GET/POST/PUT/DELETE | `/api/sales/*` | sales.js | Sales CRUD |
| GET/POST/PUT/DELETE | `/api/customers/*` | customers.js | Customer CRUD |
| GET/POST/PUT/DELETE | `/api/workers/*` | workers.js | Worker CRUD |
| GET/POST/PUT/DELETE | `/api/expenses/*` | expenses.js | Expense CRUD |
| POST | `/api/upload/:businessId` | upload.js | File upload → MinIO |
| POST | `/api/push/register` | push.js | Register device |
| DELETE | `/api/push/device/:deviceId` | push.js | Unregister device |
| POST | `/api/push/send` | push.js | Send notification |
| GET | `/api/notifications/unread/:userId` | push.js | Unread notifications |
| GET | `/api/notifications/:userId` | push.js | All notifications (paginated) |
| PUT | `/api/notifications/:id/read` | push.js | Mark read |
| PUT | `/api/notifications/read-all/:userId` | push.js | Mark all read |
| DELETE | `/api/notifications/:id` | push.js | Delete notification |
| GET | `/api/businesses` | server.js | List user's businesses |
| GET | `/api/businesses/:id` | server.js | Get business details |
| POST | `/api/subscriptions/validate/:businessId` | server.js | Validate subscription |

### Admin Routes

| Method | Path | Description |
|--------|------|-------------|
| POST | `/admin-api/workers` | Create worker (The documentation file doesn't exist yet. Let me read the schema and migration files to create the comprehensive documentation.

<read_file>
<path>c:/Users/USER/Desktop/mc/functions/db/schema.sql</path>
</read_file>
