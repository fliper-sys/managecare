# Phase 3 Settings Implementation - Quick Reference

## Files Created/Modified

### New Files
1. **currency_management_screen.dart** - Full currency and exchange rate management
2. **notification_preferences_screen.dart** - Notification settings and quiet hours
3. **backup_and_restore_screen.dart** - Data backup and restore functionality

### Modified Files
1. **settings_screen.dart** - Added imports and updated navigation routes

## Screen Overview

### Currency Management Screen
```
├── Currencies Tab
│   ├── List all currencies
│   ├── Mark default currency
│   ├── Add new currencies
│   └── View currency details (code, symbol, decimals)
└── Exchange Rates Tab
    ├── List all exchange rates
    ├── Show expiration status
    ├── Update expired rates
    └── Add new rates
```

### Notification Preferences Screen
```
├── Notification Channels
│   ├── Push Notifications
│   ├── Email Notifications
│   ├── SMS Notifications
│   └── In-App Notifications
├── Notification Types
│   ├── Sales Alerts
│   ├── Inventory Alerts
│   ├── Payment Alerts
│   ├── Customer Alerts
│   └── System Alerts
├── Quiet Hours
│   ├── Enable/Disable toggle
│   ├── Start time picker
│   └── End time picker
└── Notification Frequency
    ├── Real-time
    ├── Hourly Digest
    └── Daily Digest
```

### Backup & Restore Screen
```
├── Create Backup Tab
│   ├── Select backup items
│   │   ├── Business Data
│   │   ├── Sales Records
│   │   ├── Inventory
│   │   ├── Customers
│   │   ├── Reports
│   │   └── Settings
│   ├── Choose destination
│   │   ├── Local Storage
│   │   ├── Cloud (Firebase)
│   │   └── Both
│   └── Create Backup button
└── Backups List Tab
    ├── List all backups
    ├── Show backup info
    │   ├── Created date/time
    │   ├── Size
    │   └── Destination
    └── Actions
        ├── Restore button
        └── Delete button
```

## Provider Classes Needed

### 1. CurrencyProvider
```dart
// Location: lib/providers/currency_provider.dart

class Currency {
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final bool isDefault;
  final DateTime createdAt;
}

class CurrencyRate {
  final String baseCurrency;
  final String targetCurrency;
  final double rate;
  final DateTime expiryDate;
  
  bool get isExpired => DateTime.now().isAfter(expiryDate);
}

class CurrencyProvider extends ChangeNotifier {
  List<Currency> _currencies = [];
  List<CurrencyRate> _rates = [];
  
  List<Currency> get currencies => _currencies;
  List<CurrencyRate> get rates => _rates;
  
  // Methods to implement:
  Future<bool> addCurrency({...})
  Future<bool> addExchangeRate({...})
  void setDefaultCurrency(String code)
  Future<void> loadCurrencies()
  Future<void> loadRates()
}
```

### 2. NotificationProvider
```dart
// Location: lib/providers/notification_provider.dart

enum NotificationFrequency { realTime, hourly, daily }

class NotificationProvider extends ChangeNotifier {
  // Channels
  bool _isPushEnabled = true;
  bool _isEmailEnabled = true;
  bool _isSmsEnabled = false;
  bool _isInAppEnabled = true;
  
  // Types
  bool _salesAlertsEnabled = true;
  bool _inventoryAlertsEnabled = true;
  bool _paymentAlertsEnabled = true;
  bool _customerAlertsEnabled = true;
  bool _systemAlertsEnabled = true;
  
  // Quiet Hours
  bool _isQuietHoursEnabled = false;
  TimeOfDay _quietHoursStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = TimeOfDay(hour: 8, minute: 0);
  
  // Frequency
  NotificationFrequency _frequency = NotificationFrequency.realTime;
  
  // Getters (implement for all above)
  bool get isPushEnabled => _isPushEnabled;
  // ... etc
  
  // Setters
  void setPushNotifications(bool value)
  void setEmailNotifications(bool value)
  void setSmsNotifications(bool value)
  void setInAppNotifications(bool value)
  
  void setSalesAlerts(bool value)
  void setInventoryAlerts(bool value)
  void setPaymentAlerts(bool value)
  void setCustomerAlerts(bool value)
  void setSystemAlerts(bool value)
  
  void setQuietHoursEnabled(bool value)
  void setQuietHoursStart(TimeOfDay time)
  void setQuietHoursEnd(TimeOfDay time)
  
  void setFrequency(NotificationFrequency frequency)
}
```

### 3. BackupProvider
```dart
// Location: lib/providers/backup_provider.dart

enum BackupDestination { local, cloud, both }

class Backup {
  final String id;
  final String name;
  final DateTime createdAt;
  final int size;
  final BackupDestination destination;
  final Map<String, bool> includedData;
}

class BackupProvider extends ChangeNotifier {
  List<Backup> _backups = [];
  bool _isBackingUp = false;
  
  // Backup selections
  bool _backupBusinessData = true;
  bool _backupSalesData = true;
  bool _backupInventory = true;
  bool _backupCustomers = true;
  bool _backupReports = true;
  bool _backupSettings = true;
  
  BackupDestination _destination = BackupDestination.cloud;
  
  // Getters
  List<Backup> get backups => _backups;
  bool get isBackingUp => _isBackingUp;
  
  // Backup selection setters
  void setBackupBusinessData(bool value)
  void setBackupSalesData(bool value)
  void setBackupInventory(bool value)
  void setBackupCustomers(bool value)
  void setBackupReports(bool value)
  void setBackupSettings(bool value)
  void setDestination(BackupDestination dest)
  
  // Actions
  Future<bool> createBackup()
  Future<bool> restoreBackup(Backup backup)
  Future<void> deleteBackup(Backup backup)
  Future<void> loadBackups()
}
```

### 4. SettingsProvider
```dart
// Location: lib/providers/settings_provider.dart

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  double _textScale = 1.0;
  bool _twoFactorEnabled = false;
  bool _autoBackupEnabled = true;
  bool _biometricEnabled = true;
  
  // Getters
  bool get isDarkMode => _isDarkMode;
  double get textScale => _textScale;
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get autoBackupEnabled => _autoBackupEnabled;
  bool get biometricEnabled => _biometricEnabled;
  
  // Setters
  void setDarkMode(bool value)
  void setTextScale(double value)
  void setTwoFactorEnabled(bool value)
  void setAutoBackupEnabled(bool value)
  void setBiometricEnabled(bool value)
}
```

## Usage Examples

### In Settings Screen
```dart
// Already integrated - just navigate to new screens:

// Currency Management
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const CurrencyManagementScreen(),
  ),
);

// Notification Preferences
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const NotificationPreferencesScreen(),
  ),
);

// Backup & Restore
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const BackupAndRestoreScreen(),
  ),
);
```

### Using Providers in Screens
```dart
// Read provider data
Consumer<CurrencyProvider>(
  builder: (context, provider, _) {
    return Text('Currencies: ${provider.currencies.length}');
  },
);

// Call provider methods
final provider = context.read<NotificationProvider>();
provider.setSalesAlerts(true);
```

## Implementation Roadmap

### Phase 1: Providers (1-2 days)
- [ ] Create CurrencyProvider with Firestore integration
- [ ] Create NotificationProvider with SharedPreferences
- [ ] Create BackupProvider with cloud and local storage
- [ ] Create SettingsProvider with SharedPreferences

### Phase 2: Models (1 day)
- [ ] Currency model with Firestore serialization
- [ ] CurrencyRate model with Firestore serialization
- [ ] Backup model with Firestore serialization
- [ ] Database schema for each model

### Phase 3: Services (2-3 days)
- [ ] BackupService for local storage
- [ ] CloudStorageService for Firebase
- [ ] CurrencyService for API integration
- [ ] NotificationService for Firebase Cloud Messaging

### Phase 4: Integration & Testing (2-3 days)
- [ ] Wire up all providers to screens
- [ ] Test all functionality
- [ ] Error handling and validation
- [ ] User feedback (snackbars, dialogs)

### Phase 5: Polish & Optimization (1-2 days)
- [ ] Performance optimization
- [ ] Edge case handling
- [ ] Accessibility improvements
- [ ] Documentation

## Common Tasks

### Add New Currency
1. User taps FAB on CurrencyManagementScreen
2. Dialog appears with form
3. Provider.addCurrency() is called
4. Data saved to Firestore
5. UI refreshes with new currency

### Create Backup
1. User selects items to backup
2. User selects destination
3. User taps "Create Backup"
4. Backup is created and saved
5. Added to backups list

### Update Notification Settings
1. User toggles preference
2. Provider setter is called
3. Data saved to SharedPreferences
4. Notification service updated
5. No manual refresh needed (uses Consumer)

## Testing Checklist

- [ ] All screens render without errors
- [ ] Tab switching works smoothly
- [ ] All buttons are clickable
- [ ] Dialogs open and close properly
- [ ] Notifications display correctly
- [ ] Empty states show appropriate messages
- [ ] Data persists after app restart
- [ ] Responsive design on different screen sizes
- [ ] Error handling works
- [ ] Loading states display correctly

## Notes

- All screens use Material Design 3
- Consistent with existing app design system
- Provider package for state management
- Firestore for cloud data
- SharedPreferences for local app settings
- Ready for internationalization
- Accessible to users with disabilities

---

**Status**: Ready for Provider Implementation
**Estimated Time**: 8-12 hours total development

