/// Application constants
class AppConstants {
  // API Configuration
  static const String baseUrl = 'https://api.managecare.app';
  static const int apiTimeout = 30000; // milliseconds

  // App Info
  static const String appName = 'Manage Care';
  static const String appVersion = '1.0.0';

  // Cache
  static const Duration cacheExpiry = Duration(hours: 24);
  static const String userCacheKey = 'cached_user';
  static const String businessCacheKey = 'cached_business';

  // Pagination
  static const int itemsPerPage = 20;

  // Sync
  static const Duration syncInterval = Duration(hours: 1);
  static const int maxSyncRetries = 3;

  // Payment
  static const List<String> supportedPaymentMethods = [
    'cash',
    'card',
    'check',
    'mobile_money',
    'bank_transfer'
  ];
}

