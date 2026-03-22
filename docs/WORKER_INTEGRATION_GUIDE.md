# Worker Screens Integration Guide

## Quick Start: Adding Worker Screens to Navigation

### 1. Update Routes (`lib/core/constants/routes.dart`)

Add these constants:
```dart
static const String workerDashboard = '/worker-dashboard';
static const String workerManagement = '/worker-management';
static const String workerSales = '/worker-sales';
static const String workerInventory = '/worker-inventory';
```

### 2. Update App Router (`lib/routes/app_router.dart`)

Add these routes:
```dart
GoRoute(
  path: 'worker-dashboard',
  name: 'workerDashboard',
  builder: (context, state) => const WorkerDashboardScreen(),
),
GoRoute(
  path: 'worker-management',
  name: 'workerManagement',
  builder: (context, state) => const WorkerManagementScreen(),
),
GoRoute(
  path: 'worker-sales',
  name: 'workerSales',
  builder: (context, state) => const WorkerSalesScreen(),
),
GoRoute(
  path: 'worker-inventory',
  name: 'workerInventory',
  builder: (context, state) => const WorkerInventoryScreen(),
),
```

### 3. Update Main Navigation Logic

In your main dashboard or navigation widget:
```dart
final user = context.read<AuthProvider>().currentUser;
final isWorker = user != null && !user.isOwner;

// Show worker dashboard if user is a worker
if (isWorker) {
  return const WorkerDashboardScreen();
}

// Otherwise show owner dashboard
return const OwnerDashboardScreen();
```

### 4. Add Worker Actions to Owner Dashboard

```dart
ListTile(
  leading: const Icon(Icons.people),
  title: const Text('Manage Workers'),
  onTap: () => Navigator.pushNamed(
    context,
    Routes.workerManagement,
  ),
),
```

## Screen Navigation Map

```
Login
  ↓
├─→ Owner (isOwner: true)
│   ├─→ Owner Dashboard
│   ├─→ Worker Management Screen
│   │   ├─→ Worker Details
│   │   ├─→ Add Worker
│   │   └─→ Permissions View
│   └─→ Workers List
│
└─→ Worker (businessId set, isOwner: false)
    ├─→ Worker Dashboard
    ├─→ Sales Screen (if permitted)
    ├─→ Inventory Screen (if permitted)
    ├─→ Attendance Screen
    └─→ Worker Details
```

## Permission-Based Access Control Example

```dart
// In any screen
final user = context.read<AuthProvider>().currentUser;

if (user != null && WorkerPermissions.canManageSales(user.role)) {
  // Show sales interface
} else {
  // Show restricted message
}

// For navigation
if (WorkerPermissions.canViewInventory(user.role)) {
  Navigator.pushNamed(context, Routes.workerInventory);
}
```

## Common Integration Points

### 1. Worker Dashboard as Home Screen
```dart
// In main.dart or splash screen
if (user.isOwner) {
  return const OwnerDashboardScreen();
} else if (user.businessId.isNotEmpty) {
  return const WorkerDashboardScreen();
}
```

### 2. Add Worker from Owner Dashboard
```dart
FloatingActionButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const AddWorkerScreen()),
  ),
  child: const Icon(Icons.person_add),
)
```

### 3. Role Selector Dropdown
```dart
DropdownButton<String>(
  items: WorkerPermissions.getAvailableRoles('retail')
    .map((role) => DropdownMenuItem(
      value: role,
      child: Text(WorkerPermissions.getRoleDisplayName(role)),
    ))
    .toList(),
  onChanged: (value) => setState(() => selectedRole = value),
)
```

### 4. Permission Checker Widgets
```dart
// Helper widget for permission-based UI
class PermissionGated extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGated({
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    
    if (user != null && 
        WorkerPermissions.hasPermission(user.role, permission)) {
      return child;
    }
    
    return fallback ?? const SizedBox.shrink();
  }
}

// Usage:
PermissionGated(
  permission: 'manage_inventory',
  child: ElevatedButton(
    onPressed: () => _editProduct(),
    child: const Text('Edit'),
  ),
)
```

## API Integration Checklist

- [ ] Connect sales to SalesRepository
- [ ] Connect inventory view to InventoryRepository
- [ ] Connect inventory edits to InventoryRepository
- [ ] Pull attendance records from Firestore
- [ ] Link worker performance metrics to actual sales data
- [ ] Implement real-time sync for worker status changes
- [ ] Add notifications for worker actions
- [ ] Implement payroll calculations based on sales

## Environment-Specific Setup

### Development
```dart
// Use mock data
const workers = [...mockWorkerData];
```

### Production
```dart
// Connect to actual repositories
final workers = await _workerRepository.getWorkersByBusiness(businessId);
```

## Testing Commands

```bash
# Run analyzer
flutter analyze

# Run tests
flutter test

# Build for release
flutter build apk --release
flutter build ios --release
flutter build web --release
```

## Troubleshooting

### Issue: Worker not seeing sales option
**Solution**: Verify role permissions in `WorkerPermissions.rolePermissions` include 'sales' for that role.

### Issue: Permission denied on edit
**Solution**: Check if current user role has 'manage_*' permission in `WorkerPermissions`.

### Issue: Cart not persisting
**Solution**: Ensure `CartItem` class is properly serialized if adding persistence.

### Issue: Business not loading for worker
**Solution**: Verify `user.businessId` is set during worker creation in `AddWorkerScreen`.

## Support & Maintenance

For questions about:
- **Permissions**: Check `lib/core/utils/worker_permissions.dart`
- **UI Components**: Check respective screen files
- **Data Models**: Check `lib/data/models/`
- **State Management**: Check `lib/providers/`
- **Navigation**: Check `lib/routes/`

