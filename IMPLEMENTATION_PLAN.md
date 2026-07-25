# Firebase → Self-Hosted Database: Complete Migration & Implementation Plan

## Current Architecture

```
┌────────────────────────────────────────────────┐
│                  Flutter App                    │
│                                                 │
│  ┌─────────────┐  ┌────────────────────────┐  │
│  │ Firebase Auth│  │   Firebase Firestore   │  │
│  │ (GoTrue) ✅  │  │   (Still 80% active)   │  │
│  └─────────────┘  └────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │       Supabase Client (GoTrue) ✅       │  │
│  │       Supabase Client (Postgres) ✅     │  │
│  └────────────────────────────────────────┘  │
│  ┌─────────────┐  ┌────────────────────────┐  │
│  │  sqflite    │  │   Firebase Storage     │  │
│  │ (offline)✅ │  │   (MinIO: Not Started) │  │
│  └─────────────┘  └────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │  Firebase Cloud Messaging (Active)     │  │
│  └────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────┐
│               VPS (backend.managecare.info)    │
│                                                 │
│  ┌─────────────┐  ┌────────────────────────┐  │
│  │  PostgreSQL  │  │   Express.js Server    │  │
│  │  (Running)   │  │   (Auth + ADMS API)   │  │
│  └─────────────┘  └────────────────────────┘  │
│  ┌─────────────┐  ┌────────────────────────┐  │
│  │   MinIO     │  │   Admin API            │  │
│  │  (Running)  │  │   (Partial)            │  │
│  └─────────────┘  └────────────────────────┘  │
│  ┌─────────────┐                              │
│  │  Socket.io  │                              │
│  │  (Running)  │                              │
│  └─────────────┘                              │
└────────────────────────────────────────────────┘
```

---

## Target Architecture (After Migration)

```
┌────────────────────────────────────────────────┐
│                  Flutter App                    │
│                                                 │
│  ┌────────────────────────────────────────┐  │
│  │       Supabase GoTrue (Auth Only)      │  │
│  └────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │       Supabase Client (Postgres)       │  │
│  │       - All CRUD via REST API          │  │
│  │       - Row Level Security (RLS)       │  │
│  └────────────────────────────────────────┘  │
│  ┌─────────────┐  ┌────────────────────────┐  │
│  │  sqflite    │  │   MinIO/S3 Client     │  │
│  │ (offline)✅ │  │   (File Storage)      │  │
│  └─────────────┘  └────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │  Firebase Cloud Messaging (Keep)       │  │
│  │  OR migrate to self-hosted push       │  │
│  └────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────┐
│               VPS (backend.managecare.info)    │
│                                                 │
│  ┌─────────────┐  ┌────────────────────────┐  │
│  │  PostgreSQL  │  │   Express.js Server   │  │
│  │  + RLS       │  │   - Auth (GoTrue)     │  │
│  │  + Functions │  │   - Full CRUD API     │  │
│  └─────────────┘  │   - ADMS integration   │  │
│  ┌─────────────┐  │   - Admin API (Full)  │  │
│  │   MinIO     │  │   - File upload/serve  │  │
│  │  (Storage)  │  │   - Push notifications │  │
│  └─────────────┘  └────────────────────────┘  │
│  ┌─────────────┐                              │
│  │  Socket.io  │                              │
│  │  (Realtime) │                              │
│  └─────────────┘                              │
└────────────────────────────────────────────────┘
```

---

## Phase 1: Database Schema & Backend API (Weeks 1-2)

### Step 1.1: Complete PostgreSQL Schema

Create the full database schema covering all Firestore collections:

```sql
-- Already exists: profiles, business_members, businesses
-- Need to create:

-- INVENTORY
CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sku TEXT,
  barcode TEXT,
  category TEXT,
  description TEXT,
  unit_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  cost_price DECIMAL(12,2) DEFAULT 0,
  quantity DECIMAL(12,2) NOT NULL DEFAULT 0,
  min_stock_level DECIMAL(12,2) DEFAULT 0,
  unit TEXT DEFAULT 'pcs',
  expiry_date TIMESTAMPTZ,
  store_id UUID,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SALES
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id UUID,
  store_id UUID,
  worker_id UUID,
  worker_name TEXT,
  total_amount DECIMAL(12,2) NOT NULL,
  discount_amount DECIMAL(12,2) DEFAULT 0,
  tax_amount DECIMAL(12,2) DEFAULT 0,
  final_amount DECIMAL(12,2) NOT NULL,
  payment_method TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed',
  notes TEXT,
  created_by UUID NOT NULL,
  sale_type TEXT DEFAULT 'retail',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SALE ITEMS
CREATE TABLE sale_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id UUID,
  product_name TEXT NOT NULL,
  quantity DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount DECIMAL(12,2) DEFAULT 0,
  total DECIMAL(12,2) NOT NULL,
  pricing_mode TEXT,
  inventory_unit TEXT,
  sale_unit TEXT,
  sale_unit_multiplier DECIMAL(12,2) DEFAULT 1
);

-- CUSTOMERS
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  loyalty_points INTEGER DEFAULT 0,
  total_purchases DECIMAL(12,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- WORKERS
CREATE TABLE workers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'staff',
  business_id UUID NOT NULL REFERENCES businesses(id),
  store_id UUID,
  is_active BOOLEAN DEFAULT true,
  permissions JSONB DEFAULT '{}',
  pin TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ATTENDANCE
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id UUID REFERENCES workers(id),
  device_sn TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT,
  verify_mode TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_inventory_business ON inventory(business_id);
CREATE INDEX idx_sales_business ON sales(business_id);
CREATE INDEX idx_sales_created ON sales(created_at DESC);
CREATE INDEX idx_customers_business ON customers(business_id);
CREATE INDEX idx_workers_business ON workers(business_id);
CREATE INDEX idx_attendance_worker ON attendance(worker_id);
CREATE INDEX idx_attendance_timestamp ON attendance(timestamp DESC);
```

### Step 1.2: Build Complete Express.js REST API

Create the following API routes on the existing Express server:

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/api/inventory` | GET | List inventory for a business | ❌ |
| `/api/inventory` | POST | Add inventory item | ❌ |
| `/api/inventory/:id` | PUT | Update inventory item | ❌ |
| `/api/inventory/:id` | DELETE | Delete inventory item | ❌ |
| `/api/sales` | GET | List sales with filters | ❌ |
| `/api/sales` | POST | Create sale | ❌ |
| `/api/sales/:id` | GET | Get sale by ID | ❌ |
| `/api/sales/:id/items` | GET | Get sale items | ❌ |
| `/api/sales/summary/daily` | GET | Daily sales summary | ❌ |
| `/api/customers` | GET | List customers | ❌ |
| `/api/customers` | POST | Create customer | ❌ |
| `/api/customers/:id` | PUT | Update customer | ❌ |
| `/api/customers/:id` | DELETE | Delete customer | ❌ |
| `/api/workers` | GET | List workers | ❌ |
| `/api/workers/:id` | GET | Get worker details | ❌ |
| `/api/workers/:id` | PUT | Update worker | ❌ |
| `/api/workers/:id/attendance` | GET | Get worker attendance | ❌ |
| `/api/upload` | POST | Upload file (to MinIO) | ❌ |
| `/api/upload/:id` | GET | Get file URL | ❌ |
| `/api/subscriptions/validate` | POST | Validate subscription | ❌ |

### Files to Create/Modify:
- `functions/server.js` (heavily extend) - Add all REST API endpoints
- `functions/routes/` (new directory) - Split routes into modules
- `functions/middleware/auth.js` (new) - JWT auth middleware
- `functions/middleware/validation.js` (new) - Request validation
- `functions/db/schema.sql` (new) - Complete database schema
- `functions/db/migrations/` (new) - Versioned migrations

---

## Phase 2: Repository Layer Migration (Weeks 3-4)

### Step 2.1: Create Supabase Repository Implementations

For each repository that currently uses Firestore, create a Supabase/Postgres-backed version:

| Current File | New File | Priority |
|-------------|----------|----------|
| `lib/data/repositories/sales_repository_impl.dart` | `lib/data/repositories/sales_repository_supabase.dart` | HIGH |
| `lib/data/repositories/inventory_repository_impl.dart` | `lib/data/repositories/inventory_repository_supabase.dart` | HIGH |
| `lib/data/repositories/business_repository_impl.dart` | `lib/data/repositories/business_repository_supabase.dart` | HIGH |
| `lib/data/repositories/worker_repository_impl.dart` | `lib/data/repositories/worker_repository_supabase.dart` | HIGH |
| `lib/data/repositories/customer_repository_impl.dart` | `lib/data/repositories/customer_repository_supabase.dart` | HIGH |
| `lib/data/repositories/industry_specific/gym_repository_impl.dart` | `lib/data/repositories/industry_specific/gym_repository_supabase.dart` | MEDIUM |
| `lib/data/repositories/industry_specific/drink_repository_impl.dart` | `lib/data/repositories/industry_specific/drink_repository_supabase.dart` | MEDIUM |
| `lib/data/repositories/industry_specific/hotel_repository_impl.dart` | `lib/data/repositories/industry_specific/hotel_repository_supabase.dart` | MEDIUM |
| `lib/data/repositories/industry_specific/restaurant_repository_impl.dart` | `lib/data/repositories/industry_specific/restaurant_repository_supabase.dart` | MEDIUM |
| `lib/data/repositories/industry_specific/pharmacy_repository_impl.dart` | `lib/data/repositories/industry_specific/pharmacy_repository_supabase.dart` | MEDIUM |
| `lib/data/repositories/industry_specific/agri_repository_impl.dart` | `lib/data/repositories/industry_specific/agri_repository_supabase.dart` | LOW |
| `lib/data/repositories/industry_specific/auto_repository_impl.dart` | `lib/data/repositories/industry_specific/auto_repository_supabase.dart` | LOW |
| `lib/data/repositories/industry_specific/real_estate_repository_impl.dart` | `lib/data/repositories/industry_specific/real_estate_repository_supabase.dart` | LOW |
| `lib/data/repositories/industry_specific/salon_repository_impl.dart` | `lib/data/repositories/industry_specific/salon_repository_supabase.dart` | LOW |

### Example Pattern for Supabase Repository:

```dart
class SalesRepositorySupabase implements SalesRepository {
  final SupabaseClient _db;

  SalesRepositorySupabase(this._db);

  @override
  Future<dynamic> createSale(Map<String, dynamic> saleData) async {
    final response = await _db.from('sales').insert({
      'business_id': saleData['businessId'],
      'customer_id': saleData['customerId'],
      'total_amount': saleData['totalAmount'],
      'final_amount': saleData['finalAmount'],
      'payment_method': saleData['paymentMethod'],
      'status': saleData['status'] ?? 'completed',
      'created_by': saleData['createdBy'],
    }).select('id').single();

    // Insert sale items
    if (saleData['items'] is List) {
      for (final item in saleData['items'] as List) {
        await _db.from('sale_items').insert({
          'sale_id': response['id'],
          'product_id': item['productId'],
          'product_name': item['productName'],
          'quantity': item['quantity'],
          'unit_price': item['unitPrice'],
          'total': item['total'],
        });
      }
    }

    return {'id': response['id'], ...saleData};
  }
}
```

---

## Phase 3: Provider & Service Cleanup (Weeks 3-4, parallel with Phase 2)

### Step 3.1: Clean `auth_provider.dart`

Remove all Firebase dependencies:
1. Replace `FirebaseAuth.instance.currentUser` → `Supabase.instance.client.auth.currentUser`
2. Replace `FirebaseFirestore.instance` user doc subscriptions → `profiles` table subscription or polling
3. Replace `FirebaseMessaging.instance` → keep FCM for now or use self-hosted push
4. Remove the Firebase fallback in the `login()` method

### Step 3.2: Migrate Core Services

| Service | Migration Strategy |
|---------|-------------------|
| `lib/services/sync_service.dart` | Replace `SalesRepositoryImpl` with `SalesRepositorySupabase` |
| `lib/services/subscription_service.dart` | Read subscription data from `businesses` table (already done in auth_service) |
| `lib/services/deletion_recovery_service.dart` | Implement soft-delete in `profiles` table |
| `lib/services/push_service.dart` | Keep FCM or migrate to your own push service |
| `lib/services/cloud_storage_service.dart` | Replace Firebase Storage with MinIO S3 client |

### Step 3.3: Update `main.dart`

Remove Firebase initialization. The app should only initialize Supabase:

```dart
await Future.wait([
  Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  ),
  Hive.initFlutter(),
  if (!kIsWeb) _initializeLocalDatabase(),
]);
```

Eventually remove `_initializeFirebase()` entirely once all Firebase dependencies are gone.

---

## Phase 4: Offline/Sync Redirect (Week 5)

### Step 4.1: Update Sync Targets

Change `sync_service.dart` to sync to the Postgres API instead of Firestore:

1. Replace `SalesRepositoryImpl` → `SalesRepositorySupabase`
2. Replace `InventoryRepositoryImpl` → `InventoryRepositorySupabase`
3. Replace `CustomerRepositoryImpl` → `CustomerRepositorySupabase`

### Step 4.2: Batch Sync Endpoint on Server

Create a `/api/sync/batch` endpoint that accepts an array of operations (inserts, updates, deletes) and processes them in a transaction, returning success/failure per operation.

---

## Phase 5: File Storage Migration (Week 5-6)

### Step 5.1: Replace Firebase Storage with MinIO/S3

1. Add `dart_s3` or use MinIO's S3-compatible API via `aws_s3` package in pubspec.yaml
2. Create `lib/services/supabase_storage_service.dart` that wraps MinIO operations
3. Update all image/file upload code to use the new service

### Step 5.2: File Upload API on Backend

Add endpoints to the Express.js server:
- `POST /api/upload` - Generate presigned URL or accept multipart upload
- `GET /api/files/:id` - Get file metadata
- `GET /api/files/:id/download` - Stream file from MinIO

---

## Phase 6: Push Notifications (Week 6)

### Option A: Keep Firebase Cloud Messaging (Easiest)
- Keep `firebase_messaging` and `firebase_core` in deps just for push
- Send FCM messages via Firebase Admin SDK from the backend
- Add FCM send endpoint to Express.js or use Firebase Functions

### Option B: Self-Hosted Push (More Control)
- Use a service like `ntfy` or set up your own WebSocket push
- Add a push worker in the PM2 process list
- Implement client-side WebSocket listener for real-time notifications

---

## Phase 7: Cleanup & Firebase Removal (Week 7)

### Step 7.1: Remove Firebase Dependencies

From `pubspec.yaml`:
- Remove `firebase_core`
- Remove `firebase_auth`
- Remove `cloud_firestore`
- Remove `firebase_storage`
- Remove `firebase_messaging` (if using self-hosted push)
- Remove `firebase_analytics` (optional - can migrate to self-hosted analytics)

### Step 7.2: Remove Firebase Files
- Delete `lib/firebase_options.dart`
- Delete `firebase.json`
- Delete `firestore.rules`
- Delete `firestore.indexes.json`
- Delete `database.rules.json`
- Delete `FIREBASE_SETUP.md`
- Delete `android/app/google-services.json` (if exists)
- Delete iOS GoogleService-Info.plist (if exists)

### Step 7.3: Code Cleanup
- Search for any remaining `import 'package:firebase_*'` imports
- Search for any remaining `FirebaseFirestore.instance` references
- Search for any remaining `FirebaseAuth.instance` references
- Search for any remaining `FieldValue`, `Timestamp`, `DocumentSnapshot` references

---

## Phase 8: Deployment & Infrastructure Hardening (Week 7-8)

### Step 8.1: Nginx Setup
- Install nginx on the VPS
- Configure reverse proxy to the Express.js backend
- Set up SSL with Let's Encrypt/Certbot
- Configure rate limiting, request body size limits

### Step 8.2: Database Backups
- Set up `pg_dump` cron job for daily backups
- Configure backup retention policy
- Test restore procedure

### Step 8.3: Monitoring
- Set up PM2 monitoring (`pm2 monit`)
- Add health check endpoints (`GET /api/health`)
- Configure log rotation
- Set up uptime monitoring (UptimeRobot, etc.)

### Step 8.4: Performance
- Add Redis caching layer for frequently accessed data
- Implement database connection pooling (already using Pool from pg)
- Add API endpoint pagination for list endpoints

---

## Implementation Order & Dependencies

```
Phase 1 ─► Phase 2 ─► Phase 4 ─► Phase 7
   │                     │
   └─────────┬───────────┘
             ▼
       Phase 3 ──────────┐
                          ▼
                    Phase 5 ─► Phase 6 ─► Phase 8
```

- **Phase 1** must complete first (database + API is foundation)
- **Phase 2 + 3** can run in parallel after Phase 1
- **Phase 4** depends on Phase 2
- **Phase 5** can run in parallel with Phase 3/4 (independent)
- **Phase 6** depends on Phase 1 (needs server endpoints)
- **Phase 7** depends on Phase 2, 3, 4, 5 (all migration code must work first)
- **Phase 8** can start early but mostly during final stabilization

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Data loss during migration | High | Keep Firebase running in parallel; dual-write during Phase 2-4 |
| API downtime | Medium | PM2 auto-restart; gradual rollout per endpoint |
| Offline sync conflicts | Medium | Use server-side timestamps for conflict resolution |
| Performance regression | Medium | Add pagination; benchmark before/after |
| RLS policy gaps | High | Test all API endpoints with anon/service_role keys |
| Worker short-code login missing | Low | Add as follow-up; workers can use email for now |

---

## Appendix A: Existing Database Schema (from `managecare-1/database.md`)

Current tables already created:
- `profiles` - User profiles (id, email, full_name, phone_number, photo_url, pin, current_business_id)
- `business_members` - Business membership (user_id, business_id, role, is_owner, permissions, store_id, is_active)
- `businesses` - Business records (id, business_type, subscription_plan, subscription_dates, is_subscription_active)
- `devices` - ADMS biometric devices (serial_number, last_seen)
- `attendance` - Attendance records (device_sn, user_id_on_device, timestamp, status, verify_mode)

## Appendix B: Files Containing Firebase Imports to Replace

### Critical (in active use):
1. `lib/providers/auth_provider.dart` - `firebase_auth`, `cloud_firestore`, `firebase_messaging`
2. `lib/data/repositories/sales_repository_impl.dart` - `cloud_firestore`
3. `lib/data/repositories/inventory_repository_impl.dart` - `cloud_firestore`
4. `lib/data/repositories/business_repository_impl.dart` - `cloud_firestore`
5. `lib/data/repositories/worker_repository_impl.dart` - `cloud_firestore`
6. `lib/data/repositories/customer_repository_impl.dart` - `cloud_firestore`
7. `lib/services/sync_service.dart` - `cloud_firestore`
8. `lib/services/subscription_service.dart` - `cloud_firestore`
9. `lib/services/deletion_recovery_service.dart` - `cloud_firestore`
10. `lib/services/push_service.dart` - `firebase_messaging`
11. `lib/main.dart` - `firebase_core`, `cloud_firestore`

### Industry-specific repositories (all use `cloud_firestore`):
12. `lib/data/repositories/industry_specific/gym_repository_impl.dart`
13. `lib/data/repositories/industry_specific/drink_repository_impl.dart`
14. `lib/data/repositories/industry_specific/hotel_repository_impl.dart`
15. `lib/data/repositories/industry_specific/restaurant_repository_impl.dart`
16. `lib/data/repositories/industry_specific/pharmacy_repository_impl.dart`
17. `lib/data/repositories/industry_specific/agri_repository_impl.dart`
18. `lib/data/repositories/industry_specific/auto_repository_impl.dart`
19. `lib/data/repositories/industry_specific/real_estate_repository_impl.dart`
20. `lib/data/repositories/industry_specific/salon_repository_impl.dart`
21. `lib/data/repositories/industry_specific/retail_repository.dart`
22. `lib/data/repositories/industry_specific/agri_firestore_repository.dart`

### Other Firebase-dependent files:
23. `lib/providers/reports_provider.dart` (likely uses Firestore)
24. `lib/providers/retail_provider.dart` (likely uses Firestore)
25. `lib/providers/workers_provider.dart` (likely uses Firestore)
26. `lib/services/firebase_service.dart` (pure Firebase wrapper)
27. `lib/services/push_notification_service.dart` (FCM)

---

## Estimated Timeline

| Phase | Duration | Effort |
|-------|----------|--------|
| Phase 1: Schema & Backend API | 2 weeks | ~40-60 hours |
| Phase 2: Repository Migration | 2 weeks | ~60-80 hours |
| Phase 3: Provider/Service Cleanup | 1.5 weeks | ~30-40 hours |
| Phase 4: Offline Sync Redirect | 0.5 week | ~10-15 hours |
| Phase 5: File Storage (MinIO) | 1 week | ~15-20 hours |
| Phase 6: Push Notifications | 1 week | ~10-20 hours |
| Phase 7: Firebase Cleanup | 0.5 week | ~10-15 hours |
| Phase 8: Deployment Hardening | 1 week | ~15-20 hours |

**Total: ~8-10 weeks at full-time effort**

