import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/datetime_utils.dart';
import 'dart:async';

/// Settings Provider - Manages all app settings including profile, notifications, printing, subscriptions, and exports
class SettingsProvider extends ChangeNotifier {
  FirebaseFirestore? _firestore;

  SettingsProvider({FirebaseFirestore? firestore}) {
    _firestore = firestore;
  }

  // Profile Settings
  String? _fullName;
  String? _email;
  String? _phoneNumber;
  String? _address;
  String? _jobTitle;
  String? _profilePhotoUrl;

  // Notification Settings
  bool _emailNotificationsEnabled = true;
  bool _smsNotificationsEnabled = false;
  bool _pushNotificationsEnabled = true;
  int _notificationFrequency = 1; // 1=immediate, 2=hourly, 3=daily
  List<String> _notificationTypes = [
    'sales',
    'inventory',
    'payments',
    'orders',
    'alerts'
  ];

  // Printer Settings
  bool _printerEnabled = true;
  String _printerModel = 'thermal'; // thermal, laser, inkjet
  String _paperWidth = '58'; // mm (default to 58mm thermal)
  String _connectionType = 'bluetooth'; // bluetooth, usb, wifi, network
  bool _autoConnect = true;
  bool _printHeader = true;
  bool _printFooter = true;
  String? _headerText;
  String? _footerText;
  // Selected printer device info (optional)
  String? _selectedPrinterMac;
  String? _selectedPrinterName;
  String? _selectedUsbDeviceId; // web-only: stores WebUSB device id (vendor:product:serial)

  // Subscription Settings
  String _currentPlan = 'tier1'; // tier1, tier2, tier3, unlimited
  bool _autoRenew = true;
  int _billingCycleMonths = 1; // 1=monthly, 12=yearly

  // Export Settings
  String _defaultExportFormat = 'pdf'; // pdf, csv, json
  bool _includeImages = false;
  bool _autoBackup = false;
  DateTime? _lastBackupDate;
  DateTime? _lastExportDate;

  // General Settings
  String _theme = 'light'; // light, dark
  String _language = 'en'; // en, es, fr, de
  String _currency = 'NGN'; // NGN, USD, EUR, GBP
  bool _offlineModeEnabled = true;
  bool _syncOnWifi = true;

  // State management
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _settingsSubscription;

  // Getters - Profile
  String? get fullName => _fullName;
  String? get email => _email;
  String? get phoneNumber => _phoneNumber;
  String? get address => _address;
  String? get jobTitle => _jobTitle;
  String? get profilePhotoUrl => _profilePhotoUrl;

  // Getters - Notifications
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;
  bool get smsNotificationsEnabled => _smsNotificationsEnabled;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  int get notificationFrequency => _notificationFrequency;
  List<String> get notificationTypes => _notificationTypes;

  // Getters - Printer
  bool get printerEnabled => _printerEnabled;
  String get printerModel => _printerModel;
  String get paperWidth => _paperWidth;
  String get connectionType => _connectionType;
  bool get autoConnect => _autoConnect;
  bool get printHeader => _printHeader;
  bool get printFooter => _printFooter;
  String? get headerText => _headerText;
  String? get footerText => _footerText;
  String? get selectedPrinterMac => _selectedPrinterMac;
  String? get selectedPrinterName => _selectedPrinterName;
  String? get selectedUsbDeviceId => _selectedUsbDeviceId;

  // Getters - Subscription
  String get currentPlan => _currentPlan;
  bool get autoRenew => _autoRenew;
  int get billingCycleMonths => _billingCycleMonths;

  // Getters - Export
  String get defaultExportFormat => _defaultExportFormat;
  bool get includeImages => _includeImages;
  bool get autoBackup => _autoBackup;
  DateTime? get lastBackupDate => _lastBackupDate;
  DateTime? get lastExportDate => _lastExportDate;

  // Getters - General
  String get theme => _theme;
  String get language => _language;
  String get currency => _currency;
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get syncOnWifi => _syncOnWifi;

  // State getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load user settings from Firestore
  Future<void> loadSettings(String businessId, String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      final doc = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        // Profile
        _fullName = data['fullName'];
        _email = data['email'];
        _phoneNumber = data['phoneNumber'];
        _address = data['address'];
        _jobTitle = data['jobTitle'];
        _profilePhotoUrl = data['profilePhotoUrl'];

        // Notifications
        _emailNotificationsEnabled = data['emailNotificationsEnabled'] ?? true;
        _smsNotificationsEnabled = data['smsNotificationsEnabled'] ?? false;
        _pushNotificationsEnabled = data['pushNotificationsEnabled'] ?? true;
        _notificationFrequency = data['notificationFrequency'] ?? 1;
        _notificationTypes =
            List<String>.from(data['notificationTypes'] ?? _notificationTypes);

        // Printer
        _printerEnabled = data['printerEnabled'] ?? true;
        _printerModel = data['printerModel'] ?? 'thermal';
        _paperWidth = data['paperWidth'] ?? '58';
        _connectionType = data['connectionType'] ?? 'bluetooth';
        _autoConnect = data['autoConnect'] ?? true;
        _printHeader = data['printHeader'] ?? true;
        _printFooter = data['printFooter'] ?? true;
        _headerText = data['headerText'];
        _footerText = data['footerText'];
        _selectedPrinterMac = data['selectedPrinterMac'];
        _selectedPrinterName = data['selectedPrinterName'];
        _selectedUsbDeviceId = data['selectedUsbDeviceId'];

        // Subscription
        _currentPlan = data['currentPlan'] ?? 'tier1';
        _autoRenew = data['autoRenew'] ?? true;
        _billingCycleMonths = data['billingCycleMonths'] ?? 1;

        // Export
        _defaultExportFormat = data['defaultExportFormat'] ?? 'pdf';
        _includeImages = data['includeImages'] ?? false;
        _autoBackup = data['autoBackup'] ?? false;
        if (data['lastBackupDate'] != null) {
          _lastBackupDate = parseTimestamp(data['lastBackupDate']);
        }
        if (data['lastExportDate'] != null) {
          _lastExportDate = parseTimestamp(data['lastExportDate']);
        }

        // General
        _theme = data['theme'] ?? 'light';
        _language = data['language'] ?? 'en';
        _currency = data['currency'] ?? 'NGN';
        _offlineModeEnabled = data['offlineModeEnabled'] ?? true;
        _syncOnWifi = data['syncOnWifi'] ?? true;
      } else {
        await _createDefaultSettings(businessId, userId);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load settings: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create default settings if none exist
  Future<void> _createDefaultSettings(String businessId, String userId) async {
    try {
      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'fullName': _fullName,
        'email': _email,
        'phoneNumber': _phoneNumber,
        'address': _address,
        'jobTitle': _jobTitle,
        'profilePhotoUrl': _profilePhotoUrl,
        'emailNotificationsEnabled': _emailNotificationsEnabled,
        'smsNotificationsEnabled': _smsNotificationsEnabled,
        'pushNotificationsEnabled': _pushNotificationsEnabled,
        'notificationFrequency': _notificationFrequency,
        'notificationTypes': _notificationTypes,
        'printerEnabled': _printerEnabled,
        'printerModel': _printerModel,
        'paperWidth': _paperWidth,
        'connectionType': _connectionType,
        'autoConnect': _autoConnect,
        'printHeader': _printHeader,
        'printFooter': _printFooter,
        'headerText': _headerText,
        'footerText': _footerText,
        'selectedPrinterMac': _selectedPrinterMac,
        'selectedPrinterName': _selectedPrinterName,
        'selectedUsbDeviceId': _selectedUsbDeviceId,
        'currentPlan': _currentPlan,
        'autoRenew': _autoRenew,
        'billingCycleMonths': _billingCycleMonths,
        'defaultExportFormat': _defaultExportFormat,
        'includeImages': _includeImages,
        'autoBackup': _autoBackup,
        'theme': _theme,
        'language': _language,
        'currency': _currency,
        'offlineModeEnabled': _offlineModeEnabled,
        'syncOnWifi': _syncOnWifi,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _error = 'Failed to create default settings: $e';
      notifyListeners();
    }
  }

  /// Update profile settings
  Future<bool> updateProfile(
    String businessId,
    String userId, {
    required String fullName,
    required String email,
    required String phoneNumber,
    String? address,
    String? jobTitle,
    String? profilePhotoUrl,
  }) async {
    try {
      _fullName = fullName;
      _email = email;
      _phoneNumber = phoneNumber;
      if (address != null) _address = address;
      if (jobTitle != null) _jobTitle = jobTitle;
      if (profilePhotoUrl != null) {
        _profilePhotoUrl = profilePhotoUrl;
      }

      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'address': _address,
        'jobTitle': _jobTitle,
        'profilePhotoUrl': _profilePhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update notification settings
  Future<bool> updateNotificationSettings(
    String businessId,
    String userId, {
    bool? emailEnabled,
    bool? smsEnabled,
    bool? pushEnabled,
    int? frequency,
    List<String>? types,
  }) async {
    try {
      if (emailEnabled != null) _emailNotificationsEnabled = emailEnabled;
      if (smsEnabled != null) _smsNotificationsEnabled = smsEnabled;
      if (pushEnabled != null) _pushNotificationsEnabled = pushEnabled;
      if (frequency != null) _notificationFrequency = frequency;
      if (types != null) _notificationTypes = types;

      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'emailNotificationsEnabled': _emailNotificationsEnabled,
        'smsNotificationsEnabled': _smsNotificationsEnabled,
        'pushNotificationsEnabled': _pushNotificationsEnabled,
        'notificationFrequency': _notificationFrequency,
        'notificationTypes': _notificationTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update notification settings: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update printer settings
  Future<bool> updatePrinterSettings(
    String businessId,
    String userId, {
    bool? enabled,
    String? model,
    String? paperWidth,
    String? connectionType,
    bool? autoConnect,
    bool? printHeader,
    bool? printFooter,
    String? headerText,
    String? footerText,
    String? selectedPrinterMac,
    String? selectedPrinterName,
    String? selectedUsbDeviceId,
  }) async {
    try {
      if (enabled != null) _printerEnabled = enabled;
      if (model != null) _printerModel = model;
      if (paperWidth != null) _paperWidth = paperWidth;
      if (connectionType != null) _connectionType = connectionType;
      if (autoConnect != null) _autoConnect = autoConnect;
      if (printHeader != null) _printHeader = printHeader;
      if (printFooter != null) _printFooter = printFooter;
      if (headerText != null) _headerText = headerText;
      if (footerText != null) _footerText = footerText;
      if (selectedPrinterMac != null) _selectedPrinterMac = selectedPrinterMac;
      if (selectedPrinterName != null) _selectedPrinterName = selectedPrinterName;
      if (selectedUsbDeviceId != null) _selectedUsbDeviceId = selectedUsbDeviceId;

      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'printerEnabled': _printerEnabled,
        'printerModel': _printerModel,
        'paperWidth': _paperWidth,
        'connectionType': _connectionType,
        'autoConnect': _autoConnect,
        'printHeader': _printHeader,
        'printFooter': _printFooter,
        'headerText': _headerText,
        'footerText': _footerText,
        'selectedPrinterMac': _selectedPrinterMac,
        'selectedPrinterName': _selectedPrinterName,
        'selectedUsbDeviceId': _selectedUsbDeviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update printer settings: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update subscription settings
  Future<bool> updateSubscriptionSettings(
    String businessId,
    String userId, {
    String? plan,
    bool? autoRenew,
    int? billingCycleMonths,
  }) async {
    try {
      if (plan != null) _currentPlan = plan;
      if (autoRenew != null) _autoRenew = autoRenew;
      if (billingCycleMonths != null) _billingCycleMonths = billingCycleMonths;

      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'currentPlan': _currentPlan,
        'autoRenew': _autoRenew,
        'billingCycleMonths': _billingCycleMonths,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update subscription settings: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update export settings
  Future<bool> updateExportSettings(
    String businessId,
    String userId, {
    String? format,
    bool? includeImages,
    bool? autoBackup,
  }) async {
    try {
      if (format != null) _defaultExportFormat = format;
      if (includeImages != null) _includeImages = includeImages;
      if (autoBackup != null) _autoBackup = autoBackup;

      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'defaultExportFormat': _defaultExportFormat,
        'includeImages': _includeImages,
        'autoBackup': _autoBackup,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update export settings: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update general settings
  Future<bool> updateGeneralSettings(
    String businessId,
    String userId, {
    String? theme,
    String? language,
    String? currency,
    bool? offlineMode,
    bool? syncOnWifi,
  }) async {
    try {
      if (theme != null) _theme = theme;
      if (language != null) _language = language;
      if (currency != null) _currency = currency;
      if (offlineMode != null) _offlineModeEnabled = offlineMode;
      if (syncOnWifi != null) _syncOnWifi = syncOnWifi;

      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'theme': _theme,
        'language': _language,
        'currency': _currency,
        'offlineModeEnabled': _offlineModeEnabled,
        'syncOnWifi': _syncOnWifi,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update general settings: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update last backup date
  Future<void> updateLastBackupDate(String businessId, String userId) async {
    try {
      _lastBackupDate = DateTime.now();
      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'lastBackupDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update backup date: $e';
      notifyListeners();
    }
  }

  /// Update last export date
  Future<void> updateLastExportDate(String businessId, String userId) async {
    try {
      _lastExportDate = DateTime.now();
      await _firestore
          ?.collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc(userId)
          .set({
        'lastExportDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update export date: $e';
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset to defaults
  void resetToDefaults() {
    _fullName = null;
    _email = null;
    _phoneNumber = null;
    _profilePhotoUrl = null;
    _emailNotificationsEnabled = true;
    _smsNotificationsEnabled = false;
    _pushNotificationsEnabled = true;
    _notificationFrequency = 1;
    _notificationTypes = ['sales', 'inventory', 'payments', 'orders', 'alerts'];
    _printerEnabled = true;
    _printerModel = 'thermal';
    _paperWidth = '58';
    _connectionType = 'bluetooth';
    _autoConnect = true;
    _printHeader = true;
    _printFooter = true;
    _headerText = null;
    _footerText = null;
    _currentPlan = 'tier1';
    _autoRenew = true;
    _billingCycleMonths = 1;
    _defaultExportFormat = 'pdf';
    _includeImages = false;
    _autoBackup = false;
    _lastBackupDate = null;
    _lastExportDate = null;
    _theme = 'light';
    _language = 'en';
    _currency = 'NGN';
    _offlineModeEnabled = true;
    _syncOnWifi = true;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }
}

