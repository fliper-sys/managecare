# Implementation Plan: Private Database Migration Bug Fixes

## Information Gathered

After thorough analysis of the codebase, I've identified the root causes for each reported issue:

### 1. Worker Issues
**"Registering workers tagged off duty / existing workers show off duty"**
- `functions/routes/workers.js` GET route: The query filters by `isActive` only if `isActive=true` is passed explicitly. However, the workers fetched display `is_active` but the UI layer (`worker_permissions.dart`) treats `'staff'` role as having minimal permissions, making workers appear "off duty" because they lack permissions to do anything.
- **Root Cause:** When workers are registered via `add_worker_screen.dart`, they are created via `AuthenticationService.createWorkerUser()` which uses the admin API. But the WorkersProvider fetches from `WorkerRepositorySupabase` which calls `/workers/:businessId`. The worker's `role` in the backend defaults to `'staff'` when not explicitly passed, and staff has no meaningful permissions.

**"Worker role is automatically staff regardless of business due to private database"**
- In `worker_repository_supabase.dart` `_buildPayload()`: `'role': data['role'] ?? 'staff'` — If the role isn't provided, defaults to 'staff'.
- In `auth_provider_supabase.dart` `register()` for worker creation: The role is hardcoded to `'staff'`: `role: 'staff'`
- **Root Cause:** When `AuthProvider.register()` is called with `role == 'worker'`, it calls `_authService.createWorkerUser()` but the role passed is `'staff'` hardcoded.

### 2. Edit Permission & Role Switching Not Working
- `worker_details_screen.dart` `_showEditPermissionsDialog()` calls `workersProvider.updateWorker()` which uses `WorkersProvider.updateWorker()` -> `WorkerRepositorySupabase.updateWorker()` -> PUT `/workers/:businessId/:workerId`.
- The backend `workers.js` PUT route properly handles role and permissions updates.
- But the `WorkersProvider.updateWorker()` constructs payload with `role` and `permissions` keys, while the backend expects `role` and `permissions` which should be a JSON object, but the frontend sends it as a list.
- **Root Cause:** The backend expects `permissions` as a JSON object `{permission1: true, permission2: true}`, but the frontend sends it as a raw list `[permission1, permission2]`. The backend `JSON.stringify()` converts the list to JSON, but `workers.js` PUT route stores it directly. Meanwhile, `AuthenticationService._composeUserModel()` reads permissions from `business_members.permissions` expecting an object and converts to list.

### 3. Procurement & Pharmacy Issues
**"Products registered as pharmacy in procurement edit feature"**
- `procurement_screen.dart` `_loadProducts()`: Merges pharmacy drugs from `PharmacyProvider.drugs` into the product list with category 'Pharmacy' for ALL business types. This causes non-pharmacy businesses to see pharmacy-tagged products.
- **Root Cause:** The pharmacy merge logic doesn't restrict to pharmacy-type businesses only, unlike the sales screen which does `businessType == 'pharmacy'` check.

**"Error on sale due to pharmacy category"**
- The `_ProductsGrid` in `sales_screen.dart` filters fuel products via `_isFuelProduct()` but pharmacy products from `PharmacyProvider` are merged in for retail businesses, causing category mismatches during checkout.

**"Inventory log error"**
- Need to check the inventory history endpoint.

### 4. Wholesale Pricing Missing
- `inventory_repository_supabase.dart` `_buildPayload()`: Extra metadata fields like `wholesale_price`, `sale_unit`, `sale_unit_multiplier`, etc. are correctly folded into the `metadata` JSONB column.
- However, `_buildPayload()` in `inventory_repository_supabase.dart` already handles metadata merging correctly.
- But in the `inventory_repository_supabase.dart` `getInventory()` response, metadata fields are promoted to top-level via:
  ```dart
  for (final raw in items) {
    final row = raw as Map;
    final metadata = row['metadata'];
    if (metadata is Map) {
      for (final entry in metadata.entries) {
        row.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }
  ```
- **Root Cause:** Need to verify that the backend `functions/routes/inventory.js` handles `wholesale_price` in the metadata properly during both save and retrieval.

### 5. Offline / Subscription Issues
**"Logouts to subscription page on offline"**
- `auth_provider_supabase.dart`: The offline handling in `_init()` and `_initializeLocalStorage()` attempts to stay authenticated when offline, but if the session refresh or profile poll fails, it may navigate to subscription page.
- The enhanced subscription provider may be forcing subscription validation.

**"Working offline is recurring"**
- Related to the sync service and offline sales service — need to ensure offline mode is properly detected and handled.

### 6. WhatsApp Messages
**"WhatsApp messages only show worker name and sales amount, not what was sold"**
- `whatsapp_service.dart` `sendRecentTransactions()`: The message shows transaction amounts but doesn't include line item details for each sale.
- Need to add item-level details (product names, quantities) to the WhatsApp message.

**"Remaining stock for petroleum should be part of WhatsApp info"**
- The `_buildPetrolDailyTransactionsMessage()` doesn't include remaining stock levels for each pump/product.

### 7. Daily Email Transactions
**"Email complete transactions from all businesses page in app admin should be functional"**
- The daily transactions email is partially implemented but not wired up from the admin all-businesses page.

### 8. Worker Details Screen Edit Permission Button
- Already implemented in `worker_details_screen.dart` `_showEditPermissionsDialog()`, but may have issues with the permission format mismatch described above.

---

## Detailed Edit Plan

### Fix 1: Worker Role Default 'staff' when registering
**File:** `lib/providers/auth_provider_supabase.dart`
- Change `role: 'staff'` to pass the actual role from the caller in the `register()` method.

### Fix 2: Worker appears "off duty" / shows off duty
**File:** `functions/routes/workers.js`
- Add proper filtering for `isActive` status and ensure the GET route returns active workers by default when no `isActive` filter is specified.

### Fix 3: Edit Permission & Role Switching
**File:** `lib/presentation/workers/screens/worker_details_screen.dart`
- Fix `_showEditPermissionsDialog()` to properly format permissions as a JSON object `{permission: true}` before sending to the API.

### Fix 4: Procurement Screen Pharmacy Category for Non-Pharmacy Businesses
**File:** `lib/presentation/dashboard/owner/screens/procurement_screen.dart`
- Restrict pharmacy drug merging to pharmacy-type businesses only (similar to how sales_screen.dart already does it).

### Fix 5: Wholesale Pricing Missing from Product Data
**File:** `lib/data/repositories/inventory_repository_supabase.dart`
- Ensure the inventory API payload properly handles wholesale_price, sale_unit, sale_unit_multiplier in metadata both for save and retrieval.

### Fix 6: Offline Subscription Logout
**File:** `lib/providers/auth_provider_supabase.dart`
- Improve offline subscription validation to not redirect to subscription page when offline.

### Fix 7: WhatsApp Message - Include Sold Items Details
**File:** `lib/services/whatsapp_service.dart`
- Update `sendRecentTransactions()` to include line item details (product name, quantity) for each sale in the WhatsApp message.

### Fix 8: WhatsApp Message - Petroleum Remaining Stock
**File:** `lib/services/whatsapp_service.dart`
- Add remaining stock information to `_buildPetrolDailyTransactionsMessage()`.

### Fix 9: Daily Email Transactions from All Businesses Page
**File:** `lib/presentation/dashboard/owner/owner_dashboard_screen.dart` (or related admin screens)
- Wire up the daily transactions email functionality from the admin all-businesses page.

---

## Files to be Edited

1. `lib/providers/auth_provider_supabase.dart` - Fix worker role default, offline subscription
2. `functions/routes/workers.js` - Fix worker active status filtering
3. `lib/presentation/workers/screens/worker_details_screen.dart` - Fix permission format
4. `lib/presentation/dashboard/owner/screens/procurement_screen.dart` - Restrict pharmacy merge
5. `lib/data/repositories/inventory_repository_supabase.dart` - Fix wholesale pricing metadata
6. `lib/services/whatsapp_service.dart` - Add item details and petroleum stock
7. `lib/presentation/dashboard/owner/owner_dashboard_screen.dart` - Wire up daily email

## Follow-up Steps

1. Verify each fix by reviewing the edited files
2. Test worker registration flow
3. Test permission editing
4. Test wholesale/retail pricing toggle
5. Test WhatsApp message formatting
6. Test offline mode subscription handling

