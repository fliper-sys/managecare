# Subscription Feature Access - Developer Quick Reference

## Setup (5 minutes)

### 1. Add to main.dart
```dart
ChangeNotifierProvider(
  create: (_) => EnhancedSubscriptionProvider(),
),
```

### 2. Initialize on Login
```dart
final subscriptionProvider = 
    Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
subscriptionProvider.initializeForUser(user.id);
```

---

## Common Tasks

### Check if Feature Available
```dart
final canAccess = await subscriptionProvider.canAccessFeature(
  business: currentBusiness,
  feature: 'email_receipts',
  context: 'email_screen',
);

if (canAccess) {
  // Show feature
} else {
  // Show upgrade dialog
}
```

### Show Upgrade Dialog
```dart
final upgradePath = subscriptionProvider.getUpgradePath(
  business: currentBusiness,
  feature: 'email_receipts',
);

showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Upgrade Required'),
    content: Text(upgradePath.message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => _navigateToUpgrade(),
        child: const Text('Upgrade Now'),
      ),
    ],
  ),
);
```

### Get Subscription Status
```dart
final details = subscriptionProvider.getSubscriptionDetails(
  currentBusiness.id,
);

print('Tier: ${details?.tier}');
print('Expires: ${details?.expirationReadable}');
print('Needs Action: ${details?.actionNeeded}');
```

### List All Accessible Features
```dart
final details = subscriptionProvider.getSubscriptionDetails(
  currentBusiness.id,
);

for (final feature in details?.accessibleFeatures ?? []) {
  print(feature);
}
```

---

## Feature Matrix Cheat Sheet

| Feature | Free | Basic | Pro | Tier3 |
|---------|------|-------|-----|------------|
| Basic Sales | ✅ | ✅ | ✅ | ✅ |
| Product Mgmt | ✅ | ✅ | ✅ | ✅ |
| Basic Reports | ✅ | ✅ | ✅ | ✅ |
| Unlimited Workers | ❌ | ✅ | ✅ | ✅ |
| Advanced Analytics | ❌ | ✅ | ✅ | ✅ |
| Email Receipts | ❌ | ✅ | ✅ | ✅ |
| SMS Notifications | ❌ | ✅ | ✅ | ✅ |
| Multi-Location | ❌ | ❌ | ✅ | ✅ |
| API Access | ❌ | ❌ | ✅ | ✅ |
| Payment Processing | ❌ | ❌ | ✅ | ✅ |
| Custom Reports | ❌ | ❌ | ✅ | ✅ |
| Priority Support | ❌ | ❌ | ✅ | ✅ |
| White-Label | ❌ | ❌ | ❌ | ✅ |
| SSO Login | ❌ | ❌ | ❌ | ✅ |
| Dedicated Support | ❌ | ❌ | ❌ | ✅ |
| Custom Dev | ❌ | ❌ | ❌ | ✅ |

---

## Tier Hierarchy

```
free (0)
  ↓
basic/starter (1)
  ↓
pro/professional (2)
  ↓
enterprise (3)
```

---

## Status Messages

| Status | Message | Action |
|--------|---------|--------|
| Active | "Active" | None |
| Expiring 7-3 days | "Expiring in X days" | Remind |
| Expiring 3-0 days | "Expires soon" | Urgent |
| Expired | "Subscription expired" | Renew now |
| Inactive | "Subscription inactive" | Activate |

---

## Error Handling

```dart
try {
  await subscriptionProvider.assertFeatureAccess(
    business: currentBusiness,
    feature: 'email_receipts',
    context: 'email_screen',
  );
} on FeatureAccessDeniedException catch (e) {
  print('Feature: ${e.feature}');
  print('Tier: ${e.tier}');
  print('Reason: ${e.message}');
  
  _showUpgradeDialog(e.feature);
}
```

---

## Debugging

### Check Last Error
```dart
if (subscriptionProvider.lastError != null) {
  print('Error: ${subscriptionProvider.lastError}');
}
```

### View Access Logs
```dart
final logs = subscriptionProvider.getAccessLogs(
  businessId: 'biz-123',
  limit: 10,
);

for (final log in logs) {
  print(log);
}
```

### Check Subscription Status
```dart
final status = subscriptionProvider.getSubscriptionStatus('biz-123');
print('Valid: ${status?.isValid}');
print('Expires: ${status?.endDate}');
print('Days Left: ${status?.daysUntilExpiration}');
```

### View Feature Matrix
```dart
final matrix = subscriptionProvider.getFeatureMatrix();
print(jsonEncode(matrix));
```

---

## Commonly Used Features

```dart
// Email receipts - Basic tier minimum
'email_receipts'

// SMS notifications - Basic tier minimum
'sms_notifications'

// Advanced analytics - Basic tier minimum
'advanced_analytics'

// Multi-location - Pro tier minimum
'multi_location'

// API access - Pro tier minimum
'api_access'

// Payment processing - Pro tier minimum
'payment_processing'

// White-label - Enterprise only
'white_label'

// SSO login - Enterprise only
'sso_login'
```

---

## Response Format

### canAccessFeature()
```dart
(bool, String?) // (canAccess, denialReason)
```

Example:
```dart
(true, null)                              // ✅ Allowed
(false, 'Feature available in Basic tier and above')  // ❌ Denied
(false, 'Subscription expired')           // ❌ Denied
```

### getSubscriptionDetails()
```dart
SubscriptionDetails? {
  String businessId
  String businessName
  String tier            // 'free', 'basic', 'pro', 'enterprise'
  bool isActive         // From Firestore
  bool isValid          // Active + not expired
  DateTime? startDate
  DateTime? endDate
  int? daysUntilExpiration
  bool isExpiringWithinDays
  String statusMessage  // 'Active', 'Expired', 'Expiring in 5 days'
  bool needsAction      // Expired or expiring soon
  List<String> accessibleFeatures
}
```

---

## Initialization Flow

```
App Start
  ↓
Firebase Ready
  ↓
MultiProvider Setup
  ├─ AuthProvider
  ├─ BusinessProvider
  └─ EnhancedSubscriptionProvider ← New
  ↓
User Login
  ↓
Load User Data
  ↓
Call initializeForUser(userId) ← Important!
  ↓
Background checking starts (30-min intervals)
  ↓
Feature access checks now work
```

---

## Code Snippets

### Full Screen Example
```dart
class ProFeatureScreen extends StatefulWidget {
  const ProFeatureScreen({Key? key}) : super(key: key);

  @override
  State<ProFeatureScreen> createState() => _ProFeatureScreenState();
}

class _ProFeatureScreenState extends State<ProFeatureScreen> {
  bool _hasAccess = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final subscriptionProvider = 
        Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
    final businessProvider = 
        Provider.of<BusinessProvider>(context, listen: false);

    if (businessProvider.currentBusiness == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final canAccess = await subscriptionProvider.canAccessFeature(
      business: businessProvider.currentBusiness!,
      feature: 'email_receipts',
      context: 'email_screen_init',
    );

    if (mounted) {
      setState(() {
        _hasAccess = canAccess;
        _isLoading = false;
      });
    }
  }

  void _showUpgrade() {
    final subscriptionProvider = 
        Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
    final businessProvider = 
        Provider.of<BusinessProvider>(context, listen: false);

    final path = subscriptionProvider.getUpgradePath(
      business: businessProvider.currentBusiness!,
      feature: 'email_receipts',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upgrade Required'),
        content: Text(path.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to upgrade page
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasAccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            const Text('Pro Feature'),
            const SizedBox(height: 8),
            const Text('Upgrade your subscription to access this'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showUpgrade,
              child: const Text('Upgrade Plan'),
            ),
          ],
        ),
      );
    }

    return const ProFeatureContent();
  }
}
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Feature still accessible after expiry | Call `refreshSubscriptionStatus(userId)` |
| Background checking not running | Verify `initializeForUser()` called |
| Wrong tier showing | Check cache (should be < 60 min old) |
| Import errors | Ensure all 4 files created in lib/services and lib/providers |
| Type errors | Run `dart fix --apply` and rebuild |

---

## Key Files Reference

- **Services**: `lib/services/background_subscription_checker.dart`
- **Feature Guard**: `lib/services/subscription_feature_guard.dart`
- **Provider**: `lib/providers/enhanced_subscription_provider.dart`
- **Full Guide**: `BACKGROUND_SUBSCRIPTION_CHECKING_GUIDE.md`
- **Implementation**: `BACKGROUND_SUBSCRIPTION_IMPLEMENTATION_GUIDE.md`

---

## Version History

**v1.0** - Initial implementation
- Background subscription checking (30-min intervals)
- Feature access enforcement with expiration validation
- Access logging (1000-entry cap)
- Subscription status tracking
- Feature matrix with 17 features across 4 tiers
- Complete documentation

---

## Support

For issues:
1. Check logs: `subscriptionProvider.getAccessLogs()`
2. Verify status: `subscriptionProvider.getSubscriptionStatus(businessId)`
3. Check feature matrix: `subscriptionProvider.getFeatureMatrix()`
4. Read full guide: `BACKGROUND_SUBSCRIPTION_CHECKING_GUIDE.md`


