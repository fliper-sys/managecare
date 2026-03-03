# Local Storage Cache Schema

## Overview
This document describes the complete structure of data cached locally in SharedPreferences for offline access and auto-login functionality.

## User Cache Schema

### Primary User Cache
**Key**: `cached_user_data`
**Type**: JSON String
**Size**: ~2-5 KB

```json
{
  "id": "user_uuid_123",
  "email": "user@example.com",
  "fullName": "John Doe",
  "phoneNumber": "+1234567890",
  "photoUrl": "https://example.com/photo.jpg",
  "businessId": "business_uuid_456",
  "preferredBusinessId": "business_uuid_456",
  "role": "owner",
  "isOwner": true,
  "isWorker": false,
  "permissions": ["view_sales", "manage_staff"],
  "lastUpdated": "2025-12-08T10:30:00.000Z",
  "createdAt": "2025-12-01T00:00:00.000Z"
}
```

### Auto-Login Flag
**Key**: `auto_login_enabled`
**Type**: Boolean
**Default**: false

Used to determine if user should be automatically logged in on app start.

```dart
// Stored as
await prefs.setBool('auto_login_enabled', true);

// Retrieved as
bool isEnabled = prefs.getBool('auto_login_enabled') ?? false;
```

### Last Logged-In Email
**Key**: `last_logged_in_email`
**Type**: String
**Purpose**: Pre-fill email field on login screen

```dart
// Stored as
await prefs.setString('last_logged_in_email', 'user@example.com');

// Retrieved as
String? email = prefs.getString('last_logged_in_email');
```

## Business Cache Schema

### Business List Cache
**Key**: `cached_business_list`
**Type**: JSON String Array
**Size**: ~5-20 KB (depending on number of businesses)

```json
[
  {
    "id": "business_uuid_1",
    "ownerId": "user_uuid_123",
    "name": "John's Cafe",
    "businessType": "restaurant",
    "description": "A cozy coffee shop",
    "photoUrl": "https://example.com/business.jpg",
    "taxId": "TAX123456",
    "businessRegistration": "REG123456",
    "operatingHours": {
      "monday": { "open": "09:00", "close": "21:00" },
      "tuesday": { "open": "09:00", "close": "21:00" }
    },
    "location": {
      "address": "123 Main St",
      "city": "Springfield",
      "state": "IL",
      "zipCode": "62701",
      "latitude": 39.7817,
      "longitude": -89.6501
    },
    "contact": {
      "email": "cafe@example.com",
      "phone": "+1234567890",
      "website": "https://example.com"
    },
    "subscriptionTier": "pro",
    "isSubscriptionActive": true,
    "subscriptionStartDate": "2025-01-01T00:00:00.000Z",
    "subscriptionEndDate": "2026-01-01T00:00:00.000Z",
    "durationDays": 365,
    "totalPrice": 249.99,
    "isActive": true,
    "createdAt": "2025-01-01T00:00:00.000Z",
    "updatedAt": "2025-12-08T10:30:00.000Z"
  },
  {
    "id": "business_uuid_2",
    "ownerId": "user_uuid_123",
    "name": "John's Retail Store",
    "businessType": "retail",
    "subscriptionTier": "basic",
    "isSubscriptionActive": true
  }
]
```

### Current Business ID Cache
**Key**: `current_business_id`
**Type**: String
**Purpose**: Remember which business was last selected

```dart
// Stored as
await prefs.setString('current_business_id', 'business_uuid_1');

// Retrieved as
String? businessId = prefs.getString('current_business_id');
```

### Business Last Sync Timestamp
**Key**: `business_last_sync_timestamp`
**Type**: Integer (milliseconds since epoch)
**Purpose**: Track when cache was last updated

```dart
// Stored as
await prefs.setInt('business_last_sync_timestamp', 1733678400000);

// Retrieved as
int? timestamp = prefs.getInt('business_last_sync_timestamp');
DateTime? lastSync = timestamp != null 
    ? DateTime.fromMillisecondsSinceEpoch(timestamp)
    : null;
```

### Individual Business Cache
**Key**: `business_<business_id>`
**Type**: JSON String
**Size**: ~2-5 KB per business
**Purpose**: Quick access to specific business data without full list

```json
{
  "id": "business_uuid_1",
  "name": "John's Cafe",
  "businessType": "restaurant",
  "subscriptionTier": "pro",
  "isSubscriptionActive": true,
  "subscriptionEndDate": "2026-01-01T00:00:00.000Z"
}
```

**Example Keys**:
```
business_550e8400_e29b_41d4_a716_446655440000
business_6ba7b810_9dad_11d1_80b4_00c04fd430c8
```

## Storage Limits & Optimization

### SharedPreferences Size Limits
- **Android**: Typically 4 MB per app
- **iOS**: Typically 4 MB per app
- **Web**: Typically 5-10 MB per site

### Current Cache Sizes (Estimated)
```
User Cache:              ~3 KB
Business List (2 items): ~10 KB
Individual Businesses:   ~4 KB each
Auto-login flags:        ~1 KB
─────────────────────────────────
Total (2 businesses):    ~20 KB
```

### Optimization Tips
1. Only cache essential fields
2. Remove null values from JSON
3. Archive old transactions separately
4. Clear unused cache entries
5. Monitor cache size regularly

## Cache Lifecycle

### On User Login
```
1. User authenticates successfully
2. saveUser() called
   ├─ Serialize UserModel to JSON
   ├─ Store in `cached_user_data`
   ├─ Store email in `last_logged_in_email`
   ├─ Set `auto_login_enabled` = true
   └─ User cache ready for offline use
```

### On Business Load
```
1. Firebase query returns businesses
2. saveBusinessList() called
   ├─ Serialize each business to JSON
   ├─ Combine into array
   ├─ Store in `cached_business_list`
   ├─ Update `business_last_sync_timestamp`
   ├─ Also save each business individually
   │  └─ Key: `business_<id>`
   └─ Cache ready for offline access
```

### On Business Selection
```
1. User selects different business
2. setCurrentBusiness() called
   ├─ Store business ID in `current_business_id`
   └─ Preference persisted for next app start
```

### On App Restart (with Auto-Login)
```
1. AuthProvider._initializeLocalStorage() called
2. Check isAutoLoginEnabled()
3. If true:
   ├─ getCachedUser() from `cached_user_data`
   ├─ Set user as authenticated (IMMEDIATE - OFFLINE)
   ├─ Validate subscription (background)
   └─ Sync with Firebase (background)
4. BusinessProvider checks cache:
   ├─ Load previous selection from `current_business_id`
   ├─ Or load last used from `cached_business_list`
   └─ User ready to use app offline
```

### On Logout
```
1. logout() called
2. clearUser() executed:
   ├─ Remove `cached_user_data`
   ├─ Remove `last_logged_in_email`
   ├─ Set `auto_login_enabled` = false
   └─ User logged out completely
3. clearCachedBusinessData() executed:
   ├─ Remove `cached_business_list`
   ├─ Remove `current_business_id`
   ├─ Remove `business_last_sync_timestamp`
   ├─ Remove all `business_<id>` keys
   └─ Clean slate for next login
```

## Data Synchronization

### Cache Update Strategy
```
Priority: Firebase → Local Cache → In-Memory

When loading data:
1. Try Firebase (if connected)
   ✅ Success → Update cache, use data
   ❌ Fail → Fall back to cache
2. Check local cache
   ✅ Found → Use cached data, mark as offline
   ❌ Not found → Show error
3. In-memory fallback
   Use any in-memory copy as last resort
```

### Background Sync Flow
```
On App Start:
├─ Restore user from cache (FAST - IMMEDIATE)
├─ Start Firebase sync (BACKGROUND - NON-BLOCKING)
│  ├─ Fetch updated user data
│  ├─ Update cache if changed
│  └─ Notify UI of updates
└─ App ready for user

On Business Load:
├─ Try Firebase query first
├─ If successful:
│  ├─ Update cache with new data
│  ├─ Save last sync timestamp
│  └─ Show updated data
└─ If failed:
   ├─ Fall back to cache
   ├─ Mark as "offline mode"
   └─ Show cached data with indicator
```

## Cache Validation

### Staleness Detection
```dart
bool isCacheStale({int maxAgeMinutes = 60}) {
  final lastSync = getLastSyncTime(); // From timestamp
  if (lastSync == null) return true;
  
  final ageInMinutes = DateTime.now()
      .difference(lastSync)
      .inMinutes;
  
  return ageInMinutes > maxAgeMinutes;
}

// Usage
if (businessStorage.isCacheStale(maxAgeMinutes: 120)) {
  // Cache is older than 2 hours, refresh from Firebase
  await loadUserBusinesses(userId);
}
```

### Cache Integrity
```dart
// Check if cached user is valid
UserModel? cached = localStorage.getCachedUser();
bool isValid = cached != null 
    && cached.id.isNotEmpty
    && cached.email.isNotEmpty;

// Check if cached businesses are valid
List<BusinessModel> cached = businessStorage.getCachedBusinesses();
bool hasData = cached.isNotEmpty;
bool allValid = cached.every((b) => b.id.isNotEmpty);
```

## Storage Keys Reference

### All Keys Used
```
User Storage:
├── cached_user_data              (JSON String)
├── last_logged_in_email          (String)
└── auto_login_enabled            (Boolean)

Business Storage:
├── cached_business_list          (JSON Array)
├── current_business_id           (String)
├── business_last_sync_timestamp  (Integer)
└── business_<id>                 (JSON String) - multiple keys
    ├── business_550e8400...
    ├── business_6ba7b810...
    └── business_<uuid>...
```

### Key Naming Convention
```
Prefixes:
- cached_*          → Cached data
- auto_*            → Auto-feature flags
- business_*        → Business-related
- last_*            → Last used values
- *_timestamp       → Date tracking

Suffixes:
- *_enabled         → Boolean feature flags
- *_data            → Serialized data
- *_id              → Identifiers
- *_at              → Timestamps
```

## Debugging Cache

### Get Cache Statistics
```dart
final stats = businessStorage.getCacheStats();
print(stats);
// {
//   'totalCachedBusinesses': 2,
//   'currentBusinessId': 'biz_123',
//   'lastSyncTime': '2025-12-08T10:30:00.000Z',
//   'isCacheStale': false,
//   'businessesInCache': [
//     {'id': 'biz_123', 'name': 'Cafe', ...},
//     {'id': 'biz_456', 'name': 'Store', ...}
//   ]
// }
```

### Inspect Cache Manually (Dev Tools)
```dart
// In Flutter DevTools console
final prefs = await SharedPreferences.getInstance();
final allKeys = prefs.getKeys();
for (final key in allKeys) {
  print('$key = ${prefs.get(key)}');
}
```

### Clear Specific Cache Entry (Emergency)
```dart
// Clear specific business cache
await prefs.remove('business_<business_id>');

// Clear all business cache
final keys = prefs.getKeys();
for (final key in keys.where((k) => k.startsWith('business_'))) {
  await prefs.remove(key);
}
```

## Migration & Versioning

### Current Cache Version
Version 1.0 - Initial implementation

### Adding New Cache Fields
1. Update model (UserModel, BusinessModel)
2. Update serialization (toJson/fromFirestore)
3. Increment cache version
4. Add migration logic

```dart
// Example migration
Future<void> migrateCache() {
  final version = prefs.getInt('cache_version') ?? 1;
  if (version == 1) {
    // Perform migration logic
    prefs.setInt('cache_version', 2);
  }
}
```

## Performance Metrics

### Cache Operation Speed
```
Operation               Time        Size
────────────────────────────────────────
getCachedUser()         <1ms        3KB
getCachedBusinesses()   1-2ms       10KB
saveUser()              <5ms        3KB
saveBusinessList()      5-10ms      10KB
clearUser()             <5ms        -
clearAllBusinessData()  <10ms       -
```

### Network vs Cache
```
Scenario                    Firebase    Cache       Offline
────────────────────────────────────────────────────────────
Get user data               300-500ms   <1ms        ✅ Cache
Get businesses              500-1000ms  1-2ms       ✅ Cache
Create business             1000-2000ms N/A         ❌ Blocked
Sync data                   500-1000ms  -           ❌ Blocked
```

## Security Considerations

### What's Stored Locally
✅ User ID, email, name, phone (non-sensitive)
✅ Business IDs and names
✅ Subscription tier and dates
✅ Photo URLs

### What's NOT Stored
❌ Passwords (Firebase handles)
❌ API keys
❌ Sensitive credentials
❌ Payment information
❌ Personal financial data

### Best Practices
1. No sensitive data in cache
2. Clear on logout
3. SharedPreferences automatically encrypted on:
   - iOS: Keychain
   - Android: Encrypted SharedPreferences
4. Monitor cache size

## Troubleshooting Cache Issues

### Cache Not Persisting
**Check**:
- SharedPreferences library initialized
- Permissions granted (mobile platforms)
- Storage not full
- App not being force-closed

**Fix**:
```dart
// Force save
await localStorage.saveUser(user);
// Verify
final cached = localStorage.getCachedUser();
assert(cached != null);
```

### Cache Corrupted
**Symptoms**:
- App crashes on loading
- Corrupted JSON errors
- Empty data objects

**Fix**:
```dart
// Clear corrupt cache
final prefs = await SharedPreferences.getInstance();
await prefs.clear(); // Nuclear option
// Or selectively:
await localStorage.clearUser();
await businessStorage.clearAllBusinessData();
```

### Cache Not Updating
**Check**:
- Last sync time (should be recent)
- Cache staleness (should be false)
- Firebase sync completing

**Fix**:
```dart
// Force refresh
await businessProvider.loadUserBusinesses(userId);
// Verify update
final stats = businessStorage.getCacheStats();
assert(!stats['isCacheStale']);
```

