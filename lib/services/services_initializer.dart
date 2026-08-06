import 'analytics_service.dart';
import 'barcode_service.dart';
import 'thermal_printing_service.dart';
import 'cloud_storage_service.dart';
import 'minio_storage_service.dart';
import 'self_hosted_push_service.dart';

/// Service initializer for all app services.
///
/// Firebase has been fully replaced by the self-hosted Supabase stack.
/// See managecare-1/database.md for the migration plan.
class ServicesInitializer {
  static final ServicesInitializer _instance = ServicesInitializer._internal();

  factory ServicesInitializer() {
    return _instance;
  }

  ServicesInitializer._internal();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize all services
  Future<void> initializeAll() async {
    if (_isInitialized) return;

    // Initialize self-hosted push notifications (replaces FCM)
    try {
      await SelfHostedPushService.instance.initialize();
      print('✓ SelfHostedPushService initialized');
    } catch (e) {
      print('SelfHostedPushService initialization: $e');
    }

    try {
      await MinioStorageService().initialize();
      print('✓ MinIO Storage Service initialized');
    } catch (e) {
      print('MinIO Storage initialization warning: $e');
    }

    // Initialize Analytics (non-critical)
    try {
      final analyticsService = AnalyticsService();
      await analyticsService.initialize();
      print('✓ Analytics Service initialized');
    } catch (e) {
      print('Analytics initialization warning: $e');
    }

    // Initialize Barcode Service (may not be available on all platforms)
    try {
      final barcodeService = BarcodeService();
      await barcodeService.initializeScanner();
      print('✓ Barcode Service initialized');
    } catch (e) {
      print('Barcode initialization warning: $e');
    }

    // Initialize Cloud Storage (no-op in this implementation)
    try {
      final cloudStorageService = CloudStorageService();
      await cloudStorageService.initialize();
      print('✓ Cloud Storage Service initialized');
    } catch (e) {
      print('Cloud storage initialization warning: $e');
    }

    _isInitialized = true;
    print('✓ All services initialization attempted');
  }

  /// Get analytics service instance
  AnalyticsService getAnalyticsService() {
    if (!_isInitialized) {
      throw Exception('Services not initialized. Call initializeAll() first.');
    }
    return AnalyticsService();
  }

  /// Get barcode service instance
  BarcodeService getBarcodeService() {
    if (!_isInitialized) {
      throw Exception('Services not initialized. Call initializeAll() first.');
    }
    return BarcodeService();
  }

  /// Get printer service instance
  ThermalPrintingService getPrinterService() {
    return ThermalPrintingService();
  }

  /// Get cloud storage service instance
  CloudStorageService getCloudStorageService() {
    if (!_isInitialized) {
      throw Exception('Services not initialized. Call initializeAll() first.');
    }
    return CloudStorageService();
  }
}
