# Background Subscription Checking - Quick Implementation Guide

## Files Created

1. **`lib/services/background_subscription_checker.dart`** (400+ lines)
   - Core background subscription validator
   - Checks expiration, status changes, tier validity
   - 30-minute check interval with callbacks

2. **`lib/services/subscription_feature_guard.dart`** (350+ lines)
   - Runtime feature access enforcement
   - Feature-to-tier mapping with logging
   - Access logs for debugging (capped at 1000 entries)

3. **`lib/providers/enhanced_subscription_provider.dart`** (450+ lines)
   - High-level provider combining both services
   - Integrates with Provider pattern
   - Subscription comparison and details

4. **`BACKGROUND_SUBSCRIPTION_CHECKING_GUIDE.md`** (500+ lines)
   - Complete technical documentation
   - Feature matrix and access control flow
   - Troubleshooting and testing guide

## Step 1: Add to pubspec.yaml (if needed)

Already in dependencies:
- `provider: ^6.0.0`
- `cloud_firestore: ^4.0.0`
- `flutter: ^3.9.2`

## Step 2: Update main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BusinessProvider()),
        ChangeNotifierProvider(create: (_) => EnhancedSubscriptionProvider()),
        // ... other providers
      ],
      child: MaterialApp(
        home: const SplashScreen(),
        // ... other config
      ),
    );
  }
}
```

## Step 3: Initialize in AuthProvider (on login)

```dart
Future<void> _onLoginSuccess(UserModel user) async {
  // ... existing login logic
  
  // Initialize background subscription checking
  final subscriptionProvider = 
      Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
  subscriptionProvider.initializeForUser(user.id);
  
  print('[AuthProvider] Background subscription checking started for user: ${user.id}');
}
```

## Step 4: Use in Feature Screens

### Pattern 1: Check Before Showing Feature (Non-blocking)

```dart
class EmailReceiptScreen extends StatefulWidget {
  const EmailReceiptScreen({Key? key}) : super(key: key);

  @override
  State<EmailReceiptScreen> createState() => _EmailReceiptScreenState();
}

class _EmailReceiptScreenState extends State<EmailReceiptScreen> {
  bool _hasAccess = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkFeatureAccess();
  }

  Future<void> _checkFeatureAccess() async {
    final businessProvider = 
        Provider.of<BusinessProvider>(context, listen: false);
    final subscriptionProvider = 
        Provider.of<EnhancedSubscriptionProvider>(context, listen: false);

    if (businessProvider.currentBusiness == null) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
      return;
    }

    final canAccess = await subscriptionProvider.canAccessFeature(
      business: businessProvider.currentBusiness!,
      feature: 'email_receipts',
      context: 'email_receipt_screen',
    );

    if (mounted) {
      setState(() {
        _hasAccess = canAccess;
        _isChecking = false;
      });

      if (!canAccess) {
        _showUpgradeDialog();
      }
    }
  }

  void _showUpgradeDialog() {
    final subscriptionProvider = 
        Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
    final businessProvider = 
        Provider.of<BusinessProvider>(context, listen: false);

    final upgradePath = subscriptionProvider.getUpgradePath(
      business: businessProvider.currentBusiness!,
      feature: 'email_receipts',
    );

    showDialog(
      context: context,
      builder: (_) => FeatureUpgradeDialog(
        featureName: 'Email Receipts',
        currentTier: upgradePath.currentTier,
        requiredTier: upgradePath.requiredTier,
        message: upgradePath.message,
        daysLeft: upgradePath.daysUntilExpiration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasAccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Feature Not Available'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showUpgradeDialog,
              child: const Text('Upgrade Plan'),
            ),
          ],
        ),
      );
    }

    return const EmailReceiptContent();
  }
}
```

### Pattern 2: Assert Feature Access (Blocking)

```dart
Future<void> sendEmailReceipt(String receiptId) async {
  final subscriptionProvider = 
      Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
  final businessProvider = 
      Provider.of<BusinessProvider>(context, listen: false);

  try {
    // Will throw if access denied
    await subscriptionProvider.assertFeatureAccess(
      business: businessProvider.currentBusiness!,
      feature: 'email_receipts',
      context: 'send_email_receipt',
    );

    // Send email (access granted)
    await _emailService.sendReceipt(receiptId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt sent successfully')),
    );
  } on FeatureAccessDeniedException catch (e) {
    _showUpgradeDialog(e.feature);
  }
}
```

### Pattern 3: Check if Upgrade Needed

```dart
Future<void> _checkSubscriptionStatus() async {
  final subscriptionProvider = 
      Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
  final businessProvider = 
      Provider.of<BusinessProvider>(context, listen: false);

  if (businessProvider.currentBusiness == null) return;

  // Check multiple features
  final features = [
    'email_receipts',
    'sms_notifications',
    'advanced_analytics',
  ];

  for (final feature in features) {
    if (subscriptionProvider.needsUpgrade(
      business: businessProvider.currentBusiness!,
      feature: feature,
    )) {
      print('Upgrade needed for: $feature');
    }
  }

  // Get detailed info
  final details = subscriptionProvider.getSubscriptionDetails(
    businessProvider.currentBusiness!.id,
  );

  if (details != null && details.actionNeeded) {
    print('Action: ${details.actionType}');
    print('Days left: ${details.daysUntilExpiration}');
  }
}
```

## Step 5: Show Subscription Status

```dart
class SubscriptionStatusWidget extends StatelessWidget {
  const SubscriptionStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<BusinessProvider, EnhancedSubscriptionProvider>(
      builder: (context, businessProvider, subscriptionProvider, _) {
        if (businessProvider.currentBusiness == null) {
          return const SizedBox.shrink();
        }

        final details = subscriptionProvider.getSubscriptionDetails(
          businessProvider.currentBusiness!.id,
        );

        if (details == null) {
          return const SizedBox.shrink();
        }

        // Show warning if action needed
        if (!details.actionNeeded) {
          return const SizedBox.shrink();
        }

        Color statusColor = Colors.green;
        String statusText = 'Active';

        if (details.actionType == 'RENEW_IMMEDIATELY') {
          statusColor = Colors.red;
          statusText = 'Expired - Renew Now';
        } else if (details.actionType == 'RENEW_SOON') {
          statusColor = Colors.orange;
          statusText = 'Expiring Soon';
        }

        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            border: Border.all(color: statusColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      details.expirationReadable,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Navigate to subscription management
                },
                child: const Text('Manage'),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## Step 6: Manual Refresh (Optional)

```dart
Future<void> _refreshSubscriptionStatus() async {
  final subscriptionProvider = 
      Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
  final authProvider = 
      Provider.of<AuthProvider>(context, listen: false);

  await subscriptionProvider.refreshSubscriptionStatus(
    authProvider.currentUser!.id,
  );

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Subscription status updated')),
  );
}
```

## Feature Access Decision Tree

```
User clicks feature button
    ↓
Is business loaded?
    ├─ No → Show error
    └─ Yes ↓
    
Is subscription active?
    ├─ No → Show "Renew Subscription" dialog
    └─ Yes ↓
    
Is subscription expired?
    ├─ Yes → Show "Subscription Expired" dialog
    └─ No ↓
    
Does tier have feature?
    ├─ No → Show "Upgrade Required" dialog
    └─ Yes ↓
    
Execute feature / Log access
```

## Testing

### Test Feature Matrix
```dart
void testFeatureMatrix() {
  final provider = EnhancedSubscriptionProvider();
  final matrix = provider.getFeatureMatrix();
  
  // Free tier should not have email_receipts
  expect(matrix['free']!['email_receipts'], false);
  
  // Pro tier should have email_receipts
  expect(matrix['pro']!['email_receipts'], true);
  
  // Enterprise should have everything
  expect(matrix['tier3']!['sso_login'], true);
}
```

### Test Feature Access
```dart
void testFeatureAccess() async {
  final checker = BackgroundSubscriptionChecker(
    firestore: mockFirestore,
    localBusinessStorage: mockStorage,
  );
  
  final business = BusinessModel(
    // ... with tier: 'basic', isSubscriptionActive: true
  );
  
  final (canAccess, reason) = await checker.validateFeatureAccess(
    business,
    'email_receipts',
  );
  
  expect(canAccess, true);
  expect(reason, null);
}
```

## Monitoring

### Check Access Logs
```dart
final logs = subscriptionProvider.getAccessLogs(
  businessId: 'biz-123',
  limit: 50,
);

for (final log in logs) {
  print(log);
  // [2024-01-15T10:30:45.123Z] email_receipts (email_screen): GRANTED
}
```

### Export for Analysis
```dart
final allLogs = subscriptionProvider.exportAccessLogs();
final jsonLogs = jsonEncode(allLogs);
// Save to file or send to analytics
```

## Common Issues

### Issue: Feature still accessible after expiry
**Check:**
- `subscriptionEndDate` set correctly in Firestore
- `isSubscriptionActive` is true

**Fix:**
```dart
// Force refresh
await subscriptionProvider.refreshSubscriptionStatus(userId);
```

### Issue: Background checking not running
**Check:**
- `initializeForUser()` called after login
- `EnhancedSubscriptionProvider` in Provider list
- No errors in logs

**Fix:**
```dart
// Verify initialization
final subscriptionProvider = 
    Provider.of<EnhancedSubscriptionProvider>(context);
print('Initialized: ${subscriptionProvider.isInitialized}');
```

### Issue: Wrong tier showing
**Check:**
- Cache staleness (should be < 60 minutes)
- Last sync timestamp

**Fix:**
```dart
// Clear cache and resync
final businessProvider = 
    Provider.of<BusinessProvider>(context, listen: false);
await businessProvider.loadUserBusinesses(userId);
```

## Migration Checklist

- [ ] Add to pubspec.yaml (already done)
- [ ] Update main.dart with provider
- [ ] Call `initializeForUser()` in AuthProvider
- [ ] Replace `hasFeatureAccess()` calls with new implementation
- [ ] Add subscription status widget to dashboard
- [ ] Update feature screens to check access
- [ ] Test upgrade flows
- [ ] Monitor access logs
- [ ] Remove deprecated `hasFeatureAccess()` method
- [ ] Update documentation

## Performance Notes

- **Background checks**: Every 30 minutes (configurable)
- **Cache usage**: Instant responses (milliseconds)
- **Firebase calls**: Only on cache expiration
- **Memory footprint**: ~50KB per business
- **Access logs**: Auto-purge at 1000 entries

## Next Steps

1. **Integration**: Add to existing screens one by one
2. **Testing**: Run e2e tests with expired subscriptions
3. **Analytics**: Track feature usage by tier
4. **Alerts**: Show notifications on expiration
5. **Automation**: Auto-renew for recurring plans

