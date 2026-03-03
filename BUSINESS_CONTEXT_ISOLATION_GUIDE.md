# Business Context Isolation & Access Control Guide

## Overview
The Manage Care application implements multi-tenancy with complete business isolation. Each business operates independently with its own users, data, and interfaces. This document explains how the architecture ensures proper business separation and access control.

---

## 1. User-to-Business Relationship

### Owner (Business Creator)
```dart
UserModel {
  id: "user_123",
  email: "owner@business.com",
  fullName: "John Doe",
  role: "owner",              // Owner role
  businessId: "bus_456",      // Single business ID
  isOwner: true,
}
```

### Worker (Employee)
```dart
UserModel {
  id: "worker_789",
  email: "worker@business.com",
  fullName: "Jane Smith",
  role: "staff",              // Worker role (staff, cashier, manager)
  businessId: "bus_456",      // Same business as owner
  isOwner: false,
}
```

**Key Point**: Every user has a `businessId` field that links them to a specific business. This is the primary access control mechanism.

---

## 2. Business Model Structure

```dart
BusinessModel {
  id: "bus_456",
  name: "Acme Pharmacy",
  businessType: "pharmacy",
  ownerId: "user_123",        // Links to owner
  
  // Business-specific data
  email: "info@acmepharm.com",
  phone: "+234800123456",
  address: "123 Main St",
  
  // Subscription tier controls feature access
  subscriptionTier: "professional",
  isActive: true,
  createdAt: DateTime(2024, 1, 15),
}
```

---

## 3. Data Isolation Architecture

### 3.1 Firestore Collection Structure

```
businesses/
  ├── bus_456/                     # Owned by user_123
  │   ├── name: "Acme Pharmacy"
  │   ├── ownerId: "user_123"
  │   └── ...
  └── bus_789/                     # Owned by different owner

users/
  ├── user_123/                    # Owner
  │   ├── businessId: "bus_456"
  │   ├── isOwner: true
  │   └── role: "owner"
  └── worker_789/                  # Worker
      ├── businessId: "bus_456"    # Same business
      ├── isOwner: false
      └── role: "staff"

pharmacy_drugs/
  ├── drug_001/
  │   ├── businessId: "bus_456"    # Scoped to business
  │   ├── name: "Paracetamol"
  │   └── stock: 150
  └── drug_002/
      ├── businessId: "bus_789"    # Different business
      └── ...

pharmacy_prescriptions/
  ├── pres_001/
  │   ├── businessId: "bus_456"    # Scoped to business
  │   └── ...
  └── pres_002/
      ├── businessId: "bus_789"
      └── ...

inventory/
  ├── inv_001/
  │   ├── businessId: "bus_456"
  │   └── ...
  └── inv_002/
      ├── businessId: "bus_789"
      └── ...
```

### 3.2 Query Filtering Pattern

All data queries **MUST** filter by `businessId`:

```dart
// ✅ CORRECT: Scoped to current business
Future<List<DrugModel>> fetchDrugs(String businessId) {
  return _firestore
      .collection('pharmacy_drugs')
      .where('businessId', isEqualTo: businessId)  // MANDATORY FILTER
      .get();
}

// ❌ WRONG: No business filter (security risk!)
Future<List<DrugModel>> fetchAllDrugs() {
  return _firestore
      .collection('pharmacy_drugs')
      .get();  // This would return ALL drugs from ALL businesses!
}
```

---

## 4. Authentication & Dashboard Routing Flow

### Step 1: User Logs In
```
┌─────────────────────────────────────────────┐
│ 1. User enters email + password             │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│ 2. Firebase Auth validates credentials      │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│ 3. Auth Provider loads user from Firestore  │
│    UserModel { businessId, isOwner, role }  │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│ 4. Check user properties:                   │
│    if (user.isOwner) → Owner Dashboard      │
│    else            → Worker Dashboard       │
└──────────────────┬──────────────────────────┘
                   ▼
        ┌─────────────────────┐
        │ Business Provider   │
        │ loads business data │
        │ for this businessId │
        └─────────────────────┘
```

### Step 2: Owner Dashboard Initialization

```dart
class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final businessProvider = context.read<BusinessProvider>();

      if (authProvider.currentUser != null) {
        // Load ONLY this user's business
        businessProvider.loadUserBusinesses(authProvider.currentUser!.id);
      }
    });
  }
}
```

**In BusinessProvider:**
```dart
Future<void> loadUserBusinesses(String userId) async {
  try {
    // Query: WHERE ownerId == userId (AND isActive == true)
    // This ensures owner only sees their own business(es)
    _userBusinesses = await _repository.getUserBusinesses(userId);
    
    if (_userBusinesses.isNotEmpty && _currentBusiness == null) {
      _currentBusiness = _userBusinesses.first;
    }
    notifyListeners();
  } catch (e) {
    _errorMessage = 'Failed to load businesses: ${e.toString()}';
    notifyListeners();
  }
}
```

---

## 5. Owner Dashboard - Business Data Access

### 5.1 Home Tab (Real-time Business Data)

```dart
class _HomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    
    final user = authProvider.currentUser;
    final business = businessProvider.currentBusiness;  // ← Current business context
    
    return Column(
      children: [
        // Display current business name
        Text('Welcome to ${business?.name}'),
        
        // Show business-specific data
        _buildStatsCards(business),  // Revenue, customers, etc. for THIS business
        
        // Industry-specific menu based on businessType
        _buildIndustryMenu(business?.businessType),
      ],
    );
  }
}
```

### 5.2 Industry-Specific Screen Access

When owner taps "Pharmacy Dashboard" (for example):

```dart
// Main owner dashboard navigates to industry-specific screen
Navigator.of(context).pushNamed(
  Routes.pharmacyDashboard,
  arguments: {'businessId': businessProvider.currentBusiness!.id},
);

// Pharmacy dashboard uses businessId from arguments
class PharmacyDashboard extends StatefulWidget {
  final String businessId;
  
  @override
  void initState() {
    final pharmacyProvider = context.read<PharmacyProvider>();
    
    // Load ONLY drugs for this business
    pharmacyProvider.fetchDrugs(businessId: businessId);
    // Queries: WHERE businessId == businessId
  }
}
```

### 5.3 Business Provider Feature Access Control

```dart
bool hasFeatureAccess(String feature) {
  if (_currentBusiness == null) return false;
  
  final tier = _currentBusiness!.subscriptionTier;
  
  switch (feature) {
    case 'unlimited_workers':
      return tier == 'professional' || tier == 'enterprise';
    case 'advanced_reports':
      return tier == 'professional' || tier == 'enterprise';
    case 'api_access':
      return tier == 'enterprise';
    default:
      return false;
  }
}
```

**Usage:**
```dart
if (businessProvider.hasFeatureAccess('unlimited_workers')) {
  // Show add worker button
} else {
  // Show message: "Upgrade to add more workers"
}
```

---

## 6. Worker Dashboard - Restricted Access

### 6.1 Worker Login Flow

```dart
// Worker logs in
final success = await authProvider.login(
  email: 'worker@business.com',
  password: 'password123',
);

if (success) {
  final user = authProvider.currentUser;
  
  if (user.isOwner) {
    // Navigate to owner dashboard
    Navigator.of(context).pushReplacementNamed(Routes.ownerDashboard);
  } else {
    // Navigate to WORKER dashboard
    Navigator.of(context).pushReplacementNamed(Routes.workerDashboard);
  }
}
```

### 6.2 Worker Dashboard - Business-Specific Features

```dart
class WorkerDashboardScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      
      // Worker can ONLY access their own business
      _loadWorkerData(user!.businessId);  // Use worker's businessId
    });
  }
  
  void _loadWorkerData(String businessId) {
    // Load ONLY data for this business
    // All queries will include: WHERE businessId == businessId
  }
}
```

### 6.3 Worker Role-Based Permission Control

```dart
final user = authProvider.currentUser;

// Determine what features worker can access
switch (user?.role) {
  case 'manager':
    // Can view reports, manage staff, approve payments
    _showManagerFeatures();
    break;
    
  case 'cashier':
    // Can process transactions, print receipts
    _showCashierFeatures();
    break;
    
  case 'staff':
    // Can view only assigned tasks
    _showStaffFeatures();
    break;
}
```

---

## 7. Security Rules in Firestore

### 7.1 Collection-Level Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // === USERS COLLECTION ===
    match /users/{userId} {
      // Users can only read their own document
      allow read: if request.auth.uid == userId;
      
      // Users can only update their own document
      allow update: if request.auth.uid == userId;
      
      // Never allow delete via client
      allow delete: false;
    }
    
    // === BUSINESSES COLLECTION ===
    match /businesses/{businessId} {
      // Only owner can read their business
      allow read: if resource.data.ownerId == request.auth.uid;
      
      // Only owner can update their business
      allow update: if resource.data.ownerId == request.auth.uid;
    }
    
    // === PHARMACY_DRUGS COLLECTION ===
    match /pharmacy_drugs/{drugId} {
      // Read: User must belong to the business
      allow read: if exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.businessId == resource.data.businessId;
      
      // Write: User must be owner of the business
      allow write: if exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
                      exists(/databases/$(database)/documents/businesses/$(resource.data.businessId)) &&
                      get(/databases/$(database)/documents/businesses/$(resource.data.businessId)).data.ownerId == request.auth.uid;
    }
    
    // === PHARMACY_PRESCRIPTIONS ===
    match /pharmacy_prescriptions/{prescriptionId} {
      // Similar rules: check businessId matches user's businessId
      allow read: if exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.businessId == resource.data.businessId;
    }
    
    // === INVENTORY ===
    match /inventory/{inventoryId} {
      allow read, write: if exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
                            get(/databases/$(database)/documents/users/$(request.auth.uid)).data.businessId == resource.data.businessId;
    }
    
    // Apply similar patterns to all other collections
    // Key principle: Always verify businessId matches user's businessId
  }
}
```

---

## 8. Business Independence Guarantees

### 8.1 Data Never Crosses Business Boundaries

| Operation | Guarantee |
|-----------|-----------|
| **Load User Businesses** | Query filters by ownerId == currentUserId |
| **Fetch Products** | Query filters by businessId == currentBusinessId |
| **Get Prescriptions** | Query filters by businessId == currentBusinessId |
| **List Inventory** | Query filters by businessId == currentBusinessId |
| **Fetch Employees** | Query filters by businessId + read role check |

### 8.2 Multi-Business Support (Future Enhancement)

If an owner wants to manage multiple businesses:

```dart
// Owner has multiple businesses
Owner { id: "user_123" }

// Each business linked by ownerId
Business_1 { id: "bus_456", ownerId: "user_123" }
Business_2 { id: "bus_789", ownerId: "user_123" }

// Provider loads ALL businesses
businessProvider.loadUserBusinesses(user.id);
// Returns [bus_456, bus_789]

// Owner can switch between businesses
businessProvider.switchBusiness("bus_789");

// All subsequent queries use the new currentBusiness.id
```

---

## 9. Complete Access Control Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      USER LOGIN                              │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
            ┌──────────────────────────────┐
            │  Firebase Auth validates     │
            │  credentials                 │
            └──────────────┬───────────────┘
                           ▼
            ┌──────────────────────────────┐
            │  Load UserModel from         │
            │  Firestore (includes         │
            │  businessId, role, isOwner)  │
            └──────────────┬───────────────┘
                           ▼
              ┌────────────────────────┐
              │  Check isOwner flag    │
              └────────┬───────────┬──┘
                       │           │
              ┌────────▼──┐   ┌───▼─────────┐
              │   TRUE    │   │    FALSE    │
              └────────┬──┘   └───┬─────────┘
                       ▼          ▼
            ┌──────────────────────────────┐   ┌──────────────────────────────┐
            │  OWNER DASHBOARD             │   │  WORKER DASHBOARD            │
            │  ├─ Load owner's businesses  │   │  ├─ Single business only     │
            │  │  (WHERE ownerId)          │   │  │  (user.businessId)        │
            │  ├─ Show business selector   │   │  ├─ Show role-based menu     │
            │  ├─ Show all features        │   │  │  (manager/cashier/staff) │
            │  └─ Access all industry     │   │  └─ Limited features         │
            │     specific screens         │   │    (based on role)           │
            └──────────────┬───────────────┘   └──────────────┬───────────────┘
                           ▼                                   ▼
        ┌─────────────────────────────────┐  ┌────────────────────────────────┐
        │  Select/Switch Business         │  │  Show Worker-Specific Data     │
        │  businessProvider               │  │  for businessId: user.businessId
        │  .switchBusiness(busId)         │  │                                │
        └─────────────────┬───────────────┘  └────────────────────────────────┘
                          ▼
        ┌─────────────────────────────────┐
        │  Access Industry-Specific      │
        │  Screen with businessId        │
        │  All queries scoped to this    │
        │  businessId via Firestore      │
        └─────────────────────────────────┘
```

---

## 10. Implementation Checklist

- [x] User model includes `businessId` field
- [x] Business model includes `ownerId` field
- [x] All data models include `businessId` field
- [x] Auth provider loads user with businessId
- [x] Dashboard routing based on `isOwner` flag
- [x] Business provider loads user's businesses only
- [x] All Firestore queries filter by businessId
- [x] Industry-specific screens receive businessId
- [x] Worker role-based feature access
- [x] Firestore security rules validate businessId
- [ ] Complete security rule implementation (production)
- [ ] Audit logging for cross-business access attempts

---

## 11. Common Patterns

### Pattern 1: Access Current Business Data

```dart
final businessProvider = context.watch<BusinessProvider>();
final currentBusiness = businessProvider.currentBusiness;

// Always use currentBusiness.id for queries
fetchData(businessId: currentBusiness!.id);
```

### Pattern 2: Verify User Belongs to Business

```dart
final authProvider = context.read<AuthProvider>();
final businessId = args['businessId'];

if (authProvider.currentUser?.businessId != businessId) {
  // Unauthorized! User trying to access different business
  Navigator.of(context).pop();
  return;
}
```

### Pattern 3: Multi-Business Screen

```dart
// If owner manages multiple businesses
final businesses = businessProvider.userBusinesses;

// Show dropdown to select business
DropdownButton(
  items: businesses.map((b) => DropdownMenuItem(
    value: b.id,
    child: Text(b.name),
  )).toList(),
  onChanged: (selectedId) {
    businessProvider.switchBusiness(selectedId);
  },
);
```

---

## 12. Conclusion

The architecture ensures:
- **Complete Data Isolation**: Each business operates independently
- **Strong Access Control**: Users can only access their assigned business
- **Role-Based Permissions**: Workers have limited features based on role
- **Scalability**: System can handle unlimited businesses
- **Security**: Firestore rules enforce business boundaries
- **Worker Integration**: Workers seamlessly access only their employer's data


