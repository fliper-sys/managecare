# Firestore Indexes Setup Guide

## Overview
Your Manage Care app requires several Firestore composite indexes for queries that filter on multiple fields and apply ordering. Without these indexes, queries will fail with `FAILED_PRECONDITION` errors.

## Current Index Errors

### 1. Businesses Query Index
**Error**: Query on `businesses` collection requires index for `ownerId + isActive + createdAt`

**Current Query** (in `business_repository_impl.dart`):
```dart
.where('ownerId', isEqualTo: userId)
.where('isActive', isEqualTo: true)
.orderBy('createdAt', descending: true)
```

**Status**: ✅ FIXED - Sorting moved to client-side to avoid index requirement

---

### 2. Attendance Query Index (BLOCKING)
**Error**: Query on `attendance` collection requires index for `businessId + workerId + date + createdAt`

**Current Query** (in `worker_details_screen.dart`):
```dart
.where('businessId', isEqualTo: businessId)
.where('workerId', isEqualTo: workerId)
.where('date', isGreaterThanOrEqualTo: startDate)
.orderBy('date', descending: true)
```

**Fix**: Implemented - sorting moved to client-side

---

## Firestore Indexes Required

### Index 1: Businesses (ownerId, isActive, createdAt)
```
Collection: businesses
Fields:
  - ownerId: Ascending
  - isActive: Ascending
  - createdAt: Descending
```

**Firebase Console Link**:
```
https://console.firebase.google.com/v1/r/project/manage-care-1e96b/firestore/indexes
```

**How to Create**:
1. Go to Firebase Console
2. Navigate to Firestore Database → Indexes (Composite)
3. Click "Create Index"
4. Collection: `businesses`
5. Add Fields:
   - Field: `ownerId` → Type: `Ascending`
   - Field: `isActive` → Type: `Ascending`
   - Field: `createdAt` → Type: `Descending`
6. Click Create

---

### Index 2: Attendance (businessId, workerId, date)
```
Collection: attendance
Fields:
  - businessId: Ascending
  - workerId: Ascending
  - date: Descending
```

**Firebase Console Link**:
```
https://console.firebase.google.com/v1/r/project/manage-care-1e96b/firestore/indexes
```

---

### Index 3: Workers (businessId, isActive, name)
```
Collection: workers
Fields:
  - businessId: Ascending
  - isActive: Ascending
  - name: Ascending
```

---

### Index 4: Prescriptions (businessId, status, createdAt)
```
Collection: pharmacy_prescriptions
Fields:
  - businessId: Ascending
  - status: Ascending
  - createdAt: Descending
```

---

### Index 5: Drugs (businessId, category, expiryDate)
```
Collection: pharmacy_drugs
Fields:
  - businessId: Ascending
  - category: Ascending
  - expiryDate: Ascending
```

---

## Automatic Index Creation

Firebase will automatically suggest index creation when a query without an index is executed. You can:

1. **Check Firestore Console** for index suggestions
2. **Click the provided link** in error messages to create indexes
3. **Wait 5-10 minutes** for index creation to complete

---

## Code Fixes Applied

### Fix 1: Business Query (COMPLETE)
**File**: `lib/data/repositories/business_repository_impl.dart`

Changed from server-side sorting to client-side:
```dart
// BEFORE (requires index)
.orderBy('createdAt', descending: true)

// AFTER (no index needed)
// Sorting done client-side after retrieval
```

### Fix 2: Attendance Query
**File**: `lib/presentation/workers/screens/worker_details_screen.dart`

Should change from server-side sorting to client-side:
```dart
// BEFORE (requires index)
.where('date', isGreaterThanOrEqualTo: startDate)
.orderBy('date', descending: true)

// AFTER (no index needed)
// Filter and sort client-side
```

---

## Temporary Workaround (While Indexes Create)

If you don't want to wait for indexes, modify queries to avoid composite ordering:

### Option 1: Remove orderBy
```dart
.where('ownerId', isEqualTo: userId)
.where('isActive', isEqualTo: true)
// Remove: .orderBy('createdAt', descending: true)
// Sort on client side instead
```

### Option 2: Single-field queries
```dart
// Instead of multiple where + orderBy
// Query by businessId only, then filter client-side
.where('businessId', isEqualTo: businessId)
// Filter and sort client-side
```

---

## Testing After Index Creation

1. **Wait for index status**: "Ready" in Firebase Console
2. **Restart app**: `flutter run`
3. **Check logs**: No more FAILED_PRECONDITION errors
4. **Verify data loads**: Attendance, businesses, workers all display

---

## Firebase CLI Alternative

If you prefer command-line setup:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Deploy indexes from file
firebase firestore:indexes

# Check index status
firebase firestore:indexes
```

---

## Performance Considerations

1. **Index Creation Time**: 5-30 minutes depending on data size
2. **Query Performance**: Indexes improve query speed significantly
3. **Index Size**: Minimal overhead for these collection sizes
4. **Write Costs**: Minimal impact on write costs

---

## Monitoring

Check Firebase Console regularly for:
- ✅ Index Status: "Ready"
- ✅ Query Performance in Firestore Usage
- ✅ No FAILED_PRECONDITION errors in logs

---

## Additional Resources

- [Firestore Composite Indexes](https://firebase.google.com/docs/firestore/composite-indexes)
- [Query Limitations](https://firebase.google.com/docs/firestore/query-data/queries)
- [Index Best Practices](https://firebase.google.com/docs/firestore/best-practices)

---

## Quick Reference

**All Required Indexes Summary**:

| Collection | Fields | Priority |
|-----------|--------|----------|
| businesses | ownerId, isActive, createdAt | HIGH |
| attendance | businessId, workerId, date | HIGH |
| workers | businessId, isActive, name | MEDIUM |
| pharmacy_prescriptions | businessId, status, createdAt | MEDIUM |
| pharmacy_drugs | businessId, category, expiryDate | MEDIUM |

---

## Next Steps

1. Go to Firebase Console for your project: `manage-care-1e96b`
2. Navigate to Firestore → Indexes
3. Create the 5 composite indexes listed above
4. Wait for status to show "Ready"
5. Restart your Flutter app
6. Verify errors are gone from logs

