# Runtime Error Fix Plan

## Issues Identified from Runtime Logs

### 1. 🔴 CRITICAL: Supabase Realtime WebSocket 502 Error (Port :0)
**File:** `lib/core/config/supabase_config.dart` + Supabase initialization
**Issue:** Supabase realtime client connects to port `:0` because the realtime URL resolves incorrectly from `https://backend.managecare.info` without a port.

### 2. 🔴 CRITICAL: Missing Firestore Composite Indexes
**Affects:** `inventory_alerts`, `sales`, `pharmacy_prescriptions` queries
**File:** `firestore.indexes.json`

### 3. 🟡 HIGH: NotificationService - Windows Crash
**File:** `lib/services/notification_service.dart`
**Issue:** `sendNotification` called from `background_subscription_checker.dart` crashes on Windows because `initialize()` doesn't configure Windows.

### 4. 🟡 HIGH: Business ID UUID Mismatch
**Files:** `lib/data/repositories/business_repository_supabase.dart`, `lib/providers/auth_provider_supabase.dart`
**Issue:** Business IDs like `bus_1785252246491` fail Postgres UUID validation: `invalid input syntax for type uuid: "bus_1785252246491"`

### 5. 🟡 MEDIUM: Hybrid Firebase/Supabase Migration
**Files:** `lib/services/background_subscription_checker.dart`, `lib/providers/reports_provider.dart`
**Issue:** These still use `FirebaseFirestore` while other parts use Supabase.

### 6. 🟡 MEDIUM: Worker-Treated-as-Owner Bug
**Files:** `lib/providers/auth_provider_supabase.dart`, `lib/providers/auth_provider.dart`
**Issue:** Staff user (role=staff) is incorrectly processed as OWNER.

