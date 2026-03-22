# Background Subscription System - 15-Minute Setup Guide

## Overview
Get background subscription checking and feature access control running in 15 minutes.

---

## ⏱️ 5-Minute: Core Setup

### Step 1: Update main.dart (2 minutes)

Find your main() function and update the MultiProvider:

```dart
// File: lib/main.dart

import 'package:provider/provider.dart';
import 'lib/providers/enhanced_subscription_provider.dart';

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
        
        // ✅ ADD THIS LINE
        ChangeNotifierProvider(create: (_) => EnhancedSubscriptionProvider()),
        
        // ... other providers
      ],
      child: MaterialApp(
        home: const SplashScreen(),
        // ... rest of config
      ),
    );
  }
}
```

### Step 2: Initialize on Login (3 minutes)

Find your login completion method in AuthProvider:

```dart
// File: lib/providers/auth_provider.dart

Future<void> _handleLoginSuccess(UserModel user) async {
  // ... existing login logic
  
  // ✅ ADD THESE LINES
  if (mounted) {
    final subscriptionProvider = 
        Provider.of<EnhancedSubscriptionProvider>(
          context, 
          listen: false,
        );
    
    subscriptionProvider.initializeForUser(user.id);
    print('[AuthProvider] Subscription checking initialized');
  }
  
  // ... rest of login logic
}
```

**That's it for core setup!** ✅

---

## ⏱️ 5-Minute: Test Basic Feature Access

### Step 3: Update a Feature Screen (5 minutes)

Pick any screen you want to protect. Example: EmailReceiptScreen

```dart
// File: lib/presentation/features/email_receipt_screen.dart

import 'package:provider/provider.dart';
import 'lib/providers/enhanced_subscription_provider.dart';

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

  // ✅ ADD THIS METHOD
  Future<void> _checkFeatureAccess() async {
    final businessProvider = 
        Provider.of<BusinessProvider>(context, listen: false);
    final subscriptionProvider = 
        Provider.of<EnhancedSubscriptionProvider>(context, listen: false);

    if (businessProvider.currentBusiness == null) {
      setState(() => _isChecking = false);
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
    }
  }

  // ✅ ADD THIS METHOD
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
      builder: (_) => AlertDialog(
        title: const Text('Feature Not Available'),
        content: Text(upgradePath.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to upgrade page
            },
            child: const Text('Upgrade Plan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ADD THIS CHECK
    if (_isChecking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasAccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            const Text('Premium Feature'),
            const SizedBox(height: 8),
            const Text('Upgrade to Pro or Enterprise plan'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showUpgradeDialog,
              child: const Text('Upgrade Now'),
            ),
          ],
        ),
      );
    }

    // Original content
    return SingleChildScrollView(
      child: Column(
        children: [
          // ... your email receipt UI
        ],
      ),
    );
  }
}
```

---

## ✅ Done! Test Now (5 minutes)

### Test 1: Check Background Monitoring
```dart
// In any screen
final subscriptionProvider = 
    Provider.of<EnhancedSubscriptionProvider>(context, listen: false);

final status = subscriptionProvider.getSubscriptionStatus('business-id');
print('Subscription: ${status?.tier}');
print('Expires: ${status?.expirationReadable}');
print('Valid: ${status?.isValid}');
```

### Test 2: Check Feature Access
```dart
final canAccess = await subscriptionProvider.canAccessFeature(
  business: currentBusiness,
  feature: 'email_receipts',
  context: 'test',
);

print('Can access email receipts: $canAccess');
```

### Test 3: View Access Logs
```dart
final logs = subscriptionProvider.getAccessLogs(limit: 5);
for (final log in logs) {
  print(log);
}
```

### Test 4: Simulate Expired Subscription
In Firestore console:
1. Find your business document
2. Change `subscriptionEndDate` to yesterday
3. Call `subscriptionProvider.refreshSubscriptionStatus(userId)`
4. Try accessing feature → Should be blocked

---

## 🔧 Troubleshooting

### "Feature still accessible after expiry"
```dart
// Force refresh
await subscriptionProvider.refreshSubscriptionStatus(userId);
```

### "Background checking not running"
```dart
// Verify initialization
print(subscriptionProvider.isInitialized);

// Check for errors
if (subscriptionProvider.lastError != null) {
  print('Error: ${subscriptionProvider.lastError}');
}
```

### "Import not found errors"
```bash
# Rebuild after creating new files
flutter clean
flutter pub get
flutter pub upgrade
```

---

## 📊 What You Get

### Automatic Features:
✅ Background subscription monitoring every 30 minutes  
✅ Expiration detection with 7-day warning  
✅ Feature access enforcement  
✅ Detailed access logging  
✅ Offline support with local cache  
✅ Clean error messages for users  

### New Methods Available:
```dart
// Check feature access
await subscriptionProvider.canAccessFeature(
  business: currentBusiness,
  feature: 'email_receipts',
  context: 'screen_name',
);

// Get upgrade information
subscriptionProvider.getUpgradePath(
  business: currentBusiness,
  feature: 'email_receipts',
);

// Get subscription details
final details = subscriptionProvider.getSubscriptionDetails(businessId);

// View access logs
subscriptionProvider.getAccessLogs(limit: 100);

// Manual refresh
await subscriptionProvider.refreshSubscriptionStatus(userId);

// Get feature matrix
subscriptionProvider.getFeatureMatrix();
```

---

## 📚 Next Steps

1. **Test with all feature screens** (Optional)
   - Update other screens that need feature gating
   - Test upgrade dialog
   - Test expiration scenarios

2. **Add subscription status widget** (Optional)
   - Show status on dashboard
   - Display days until expiration
   - Link to renewal page

3. **Monitor & debug** (Recommended)
   - Check access logs periodically
   - Monitor error messages
   - Collect user upgrade patterns

4. **Read full documentation** (For Advanced Usage)
   - `BACKGROUND_SUBSCRIPTION_CHECKING_GUIDE.md` - Technical deep dive
   - `SUBSCRIPTION_QUICK_REFERENCE.md` - Cheat sheet
   - `BACKGROUND_SUBSCRIPTION_IMPLEMENTATION_GUIDE.md` - Complete examples

---

## 🎯 Key Points to Remember

1. **Always initialize**: Call `initializeForUser(userId)` on login
2. **Check subscriptions**: Use `canAccessFeature()` before showing features
3. **Show clear messages**: Use `getUpgradePath()` to explain why access denied
4. **Cache helps offline**: Feature access works offline using cached data
5. **Logs are helpful**: Check `getAccessLogs()` for debugging

---

## 🚀 You're Ready!

The system is now running in the background, checking subscriptions every 30 minutes and enforcing feature access. 

**Features protected:** ✅  
**Background monitoring:** ✅  
**Offline support:** ✅  
**Ready for production:** ✅

---

## Quick Reference

| Task | Code |
|------|------|
| Check feature access | `await subscriptionProvider.canAccessFeature(...)` |
| Get upgrade info | `subscriptionProvider.getUpgradePath(...)` |
| Get subscription status | `subscriptionProvider.getSubscriptionStatus(businessId)` |
| View access logs | `subscriptionProvider.getAccessLogs()` |
| Refresh status | `await subscriptionProvider.refreshSubscriptionStatus(userId)` |
| Feature matrix | `subscriptionProvider.getFeatureMatrix()` |
| Check if upgrade needed | `subscriptionProvider.needsUpgrade(...)` |
| Get feature requirement | `subscriptionProvider.getFeatureTierRequirement(feature)` |

---

## Support

Having issues? Check:
1. ✅ Is `initializeForUser()` called on login?
2. ✅ Is provider in main.dart?
3. ✅ Did you rebuild/hot reload?
4. ✅ Check error: `subscriptionProvider.lastError`
5. ✅ View logs: `subscriptionProvider.getAccessLogs()`

**Still stuck?** Read `BACKGROUND_SUBSCRIPTION_CHECKING_GUIDE.md` → Troubleshooting section


