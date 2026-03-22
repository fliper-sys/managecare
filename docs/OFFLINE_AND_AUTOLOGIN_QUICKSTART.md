# Offline & Auto-Login Quick Reference

## User Auto-Login Flow

### What Happens on App Start
```
App Start
  ↓
AuthProvider._init()
  ↓
_initializeLocalStorage()
  ↓
Check isAutoLoginEnabled()
  ↓
YES → getCachedUser() → Set authenticated (immediate, offline)
  ↓
Validate subscription (background)
  ↓
Sync with Firebase (background, non-blocking)
  ↓
User can use app offline
```

### Key Code
```dart
// In AuthProvider._initializeLocalStorage()
if (_localStorage!.isAutoLoginEnabled()) {
  final cachedUser = _localStorage!.getCachedUser();
  if (cachedUser != null) {
    _currentUser = cachedUser;
    _status = AuthStatus.authenticated;
    // User is logged in and ready to use app
  }
}
```

## Business Data Offline Access

### What Gets Cached
- ✅ User's businesses list
- ✅ Current selected business
- ✅ Business configuration
- ✅ Subscription tier
- ✅ Last sync time

### Loading Businesses (with offline fallback)
```dart
// In BusinessProvider.loadUserBusinesses()
try {
  // Try Firebase first
  _userBusinesses = await _repository.getUserBusinesses(userId);
  // Save to cache for offline
  await _localStorage!.saveBusinessList(_userBusinesses);
} catch (e) {
  // Fall back to cache
  _userBusinesses = _localStorage!.getCachedBusinesses();
  _isUsingCachedData = true;
}
```

### Getting Cached Data in Offline Mode
```dart
// In your screen/provider
final cachedBusiness = businessProvider.getCachedCurrentBusiness();
final allCached = businessProvider.getCachedBusinesses();
bool isOffline = businessProvider.isUsingCachedData;
```

## Storage Locations

### User Cache
**File**: `SharedPreferences`
**Keys**:
- `cached_user_data` - Full user JSON
- `last_logged_in_email` - Email for login form
- `auto_login_enabled` - Boolean flag

### Business Cache
**File**: `SharedPreferences`
**Keys**:
- `cached_business_list` - All businesses JSON
- `current_business_id` - Selected business ID
- `business_last_sync_timestamp` - When cached
- `business_<id>` - Individual business data

## Enabling Features Based on Subscription

### Check Feature Availability
```dart
final canUseAnalytics = businessProvider
    .isFeatureAvailable('advanced_analytics');

if (canUseAnalytics) {
  // Show analytics screen
} else {
  // Show upgrade prompt
}
```

### Available Features
- `unlimited_workers` - Pro/Enterprise only
- `advanced_analytics` - Pro/Enterprise only
- `multi_location` - Pro/Enterprise only
- `api_access` - Pro/Enterprise only
- `sso_login` - Tier3 only
- `white_label` - Enterprise only

## Subscription Tiers

### Tier Names
- `free` - Trial version
- `basic` - Standard plan
- `pro` - Professional plan
- `enterprise` - Custom plan

### Check Subscription
```dart
// Is subscription valid?
bool isValid = businessProvider
    .isSubscriptionValid(business);

// Get tier
final tier = businessProvider.currentBusiness?.subscriptionTier;

// Check expiration
final expiresAt = businessProvider
    .currentBusiness?.subscriptionEndDate;
final daysLeft = expiresAt?.difference(DateTime.now()).inDays ?? 0;
```

## Cache Management

### Get Cache Statistics
```dart
final stats = businessProvider.getCacheStats();
// {
//   'totalCachedBusinesses': 2,
//   'currentBusinessId': 'biz_123',
//   'lastSyncTime': '2025-12-08...',
//   'isCacheStale': false,
//   'businessesInCache': [...]
// }
```

### Check if Cache is Stale
```dart
if (businessProvider.isCacheStale()) {
  // Refresh from Firebase
  await businessProvider.loadUserBusinesses(userId);
}
```

### Clear Cache on Logout
```dart
// AuthProvider.logout() automatically clears
// But you can manually clear:
await businessProvider.clearCachedBusinessData();
```

## Logging & Debugging

### Key Log Tags
```
[AuthProvider]          - User auth events
[LocalUserStorage]      - User cache ops
[BusinessProvider]      - Business operations
[LocalBusinessStorage]  - Business cache ops
[SubscriptionService]   - Subscription validation
```

### Check Logs
```
// Good: User auto-logged in
I/flutter: [AuthProvider] Auto-login: restoring cached user user@example.com

// Good: Using cached data (offline)
I/flutter: [BusinessProvider] Attempting to load cached businesses (offline mode)
I/flutter: [BusinessProvider] Successfully loaded 2 cached businesses

// Warning: Cache is stale
I/flutter: [LocalBusinessStorage] Cache is stale (check after 60 min)

// Error: Sync failed, falling back to cache
I/flutter: [BusinessProvider] Error loading from Firebase: Network error
I/flutter: [BusinessProvider] Using 2 cached businesses instead
```

## Testing Offline

### In Development
1. **Android**: Settings → Network & Internet → Airplane Mode ON
2. **iOS**: Settings → Airplane Mode ON
3. **Web**: DevTools → Network → Offline

### What Should Work
- ✅ App loads with auto-login
- ✅ Cached user data displays
- ✅ Businesses load from cache
- ✅ Navigation works
- ✅ View sales history
- ✅ View settings

### What Won't Work
- ❌ Create new business
- ❌ Sync transactions
- ❌ Real-time updates
- ❌ Cloud backups

## Common Issues & Fixes

### Auto-Login Not Working
**Check**:
```dart
// In debug console
final user = await LocalUserStorage.create();
final cached = user.getCachedUser();
print(cached); // Should show user data
```

**Fix**:
- User must login once first to cache data
- Check "Remember me" enabled
- Clear app cache and retry

### Getting Stale Cached Data
**Check**:
```dart
final stats = businessProvider.getCacheStats();
print(stats['lastSyncTime']); // Should be recent
```

**Fix**:
```dart
// Force refresh
await businessProvider.loadUserBusinesses(userId);
// This updates cache automatically
```

### Features Not Unlocking
**Check**:
```dart
final tier = businessProvider.currentBusiness?.subscriptionTier;
final isActive = businessProvider.currentBusiness?.isSubscriptionActive;
final expires = businessProvider.currentBusiness?.subscriptionEndDate;
print('Tier: $tier, Active: $isActive, Expires: $expires');
```

**Fix**:
- Subscription may be expired
- Sync with Firebase to update
- Check expiration date in subscription settings

## Implementation Checklist

- [x] User auto-login on app start
- [x] Auto-login enabled/disabled setting
- [x] User data cached locally
- [x] Business list cached locally
- [x] Current business selection cached
- [x] Offline access to user data
- [x] Offline access to business data
- [x] Graceful fallback to cache on network error
- [x] Background sync with Firebase
- [x] Subscription validation
- [x] Feature access control
- [x] Cache staleness detection
- [x] Cache clear on logout
- [x] Comprehensive logging
- [x] Documentation

## Files Modified

### New Files Created
- `lib/services/local_business_storage.dart` - Business cache service
- `SUBSCRIPTION_AND_OFFLINE_DOCUMENTATION.md` - Full documentation

### Files Updated
- `lib/providers/auth_provider.dart` - Added logout logging
- `lib/providers/business_provider.dart` - Added offline support
- `lib/services/local_user_storage.dart` - Already had caching

## Integration Summary

### AuthProvider
✅ Auto-login from cached user
✅ User cache save/load
✅ Clear on logout
✅ Background Firebase sync

### BusinessProvider
✅ Load from Firebase with fallback to cache
✅ Cache businesses on successful load
✅ Cache current business selection
✅ Restore previous selection on reload
✅ Get cached data for offline use
✅ Clear cache on logout

### LocalUserStorage
✅ Save user after login
✅ Load cached user on app start
✅ Update specific fields
✅ Clear on logout

### LocalBusinessStorage
✅ Save business list
✅ Load cached businesses
✅ Cache current selection
✅ Check cache staleness
✅ Get cache statistics
✅ Clear all data

## What's Enabled Now

### ✅ User Auto-Login
- Users stay logged in after closing app
- No need to re-enter credentials
- Works offline on app start

### ✅ Offline Business Access
- View cached business data
- View cached transactions
- Navigate app without connection
- Graceful error handling

### ✅ Automatic Caching
- Businesses cached after load
- Current selection persisted
- User data synced with Firebase
- Cache updated on each load

### ✅ Subscription Management
- Tier-based feature access
- Expiration tracking
- Offline validation
- Upgrade prompts

### ✅ Comprehensive Logging
- All cache operations logged
- Error scenarios captured
- Offline mode indicators
- Easy debugging

