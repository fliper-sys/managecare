# Worker System Troubleshooting Guide

## Issues Identified

### Issue 1: Worker Details Screen Shows "No Worker Found"
**Root Cause**: The worker ID being passed doesn't match the actual document ID in Firestore

**Problem Flow**:
1. Worker created with ID: `worker_1764979393152` (timestamp-based)
2. Saved to `workers` collection with this ID
3. When clicking worker in list, `workerId` passed is the document ID
4. `getWorkerById()` queries Firestore for this ID
5. If ID format doesn't match, document not found

**Solution**: Ensure worker ID is consistent across all collections

### Issue 2: Worker Login Fails with Worker ID + Password
**Root Cause**: Firebase Auth requires email/password, but system tries worker ID login

**Problem Flow**:
1. Worker created with email and password
2. Firebase Auth account created with email/password
3. User tries to login with "worker ID" (timestamp-based) + password
4. Auth service expects email, not worker ID
5. Login fails

**Solution**: Implement dual authentication - support both email and worker ID login

---

## Fix Implementation

### Fix 1: Worker Details Loading

**File**: `lib/presentation/workers/screens/worker_details_screen.dart`

Add better error handling and logging:

```dart
Future<void> _loadWorker() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    print('Loading worker with ID: ${widget.workerId}');
    final repo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
    final data = await repo.getWorkerById(widget.workerId);

    print('Worker data retrieved: ${data != null ? 'found' : 'not found'}');
    
    if (data == null) {
      // Try alternative: search by email or other fields
      print('Worker not found by ID, trying alternative methods');
      setState(() {
        _error = 'Worker not found by ID: ${widget.workerId}';
        _isLoading = false;
      });
      return;
    }

    // Validation logic...
    setState(() {
      _worker = Map<String, dynamic>.from(data as Map<String, dynamic>);
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load worker: $e';
      _isLoading = false;
    });
  }
}
```

### Fix 2: Implement Worker ID Login

**File**: `lib/services/authentication_service.dart`

Add support for worker ID authentication:

```dart
/// Authenticate worker by worker ID and password
Future<UserModel> authenticateWorkerByWorkerId({
  required String workerId,
  required String password,
}) async {
  try {
    // 1. Find worker in Firestore by workerId
    final workerDoc = await _firestore
        .collection('workers')
        .doc(workerId)
        .get();

    if (!workerDoc.exists) {
      throw Exception('Worker not found');
    }

    final workerData = workerDoc.data() as Map<String, dynamic>;
    final workerEmail = workerData['email'] as String?;

    if (workerEmail == null || workerEmail.isEmpty) {
      throw Exception('Worker email not configured');
    }

    // 2. Authenticate with the worker's email and password
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: workerEmail,
      password: password,
    );

    // 3. Load and return the UserModel from users collection
    final userModel = await _getUserFromFirestore(userCredential.user!.uid);

    if (userModel == null) {
      throw Exception('User profile not found');
    }

    return userModel;
  } catch (e) {
    throw Exception('Worker authentication failed: ${e.toString()}');
  }
}
```

### Fix 3: Update Auth Provider to Support Worker ID Login

**File**: `lib/providers/auth_provider.dart`

```dart
Future<bool> loginAsWorker({
  required String workerId,
  required String password,
}) async {
  try {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final user = await _authenticationService.authenticateWorkerByWorkerId(
      workerId: workerId,
      password: password,
    );
    
    _currentUser = user;
    _status = AuthStatus.authenticated;
    _errorMessage = null;
    notifyListeners();
    return true;
  } catch (e) {
    _status = AuthStatus.unauthenticated;
    _errorMessage = e.toString();
    notifyListeners();
    return false;
  }
}
```

---

## Verification Checklist

- [ ] Worker is created with Firestore document using workerId
- [ ] Worker has Firebase Auth account with email
- [ ] Worker email and workerId stored in workers collection
- [ ] getWorkerById returns the document correctly
- [ ] Worker ID + password login works via authenticateWorkerByWorkerId
- [ ] Email + password login still works (owner login)

---

## Data Structure

**Expected workers collection document**:
```json
{
  "id": "worker_1764979393152",
  "name": "John Doe",
  "email": "john@example.com",
  "role": "cashier",
  "businessId": "bus_123",
  "isActive": true,
  "createdAt": "2024-12-06T10:00:00Z"
}
```

**Expected users collection document** (for Firebase Auth):
```json
{
  "id": "{FIREBASE_UID}",
  "email": "john@example.com",
  "fullName": "John Doe",
  "role": "worker",
  "businessId": "bus_123",
  "isActive": true
}
```

---

## Testing Steps

1. **Create a worker**
   - Go to Worker Management
   - Add new worker with email and password
   - Verify worker appears in list

2. **View worker details**
   - Click on worker in list
   - Should show worker information, not "no worker found"

3. **Login as worker**
   - Go to login screen
   - Enter worker ID (e.g., worker_1764979393152)
   - Enter password
   - Should authenticate successfully

4. **Alternative: Login with email**
   - Go to login screen
   - Enter email (e.g., john@example.com)
   - Enter password
   - Should also authenticate successfully

