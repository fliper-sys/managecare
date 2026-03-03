import 'analytics_service.dart';
import 'barcode_service.dart';
import 'thermal_printing_service.dart';
import 'cloud_storage_service.dart';
import 'firebase_service.dart';

/// Service initializer for all app services
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

    try {
      // Initialize Firebase (must be done first) - safe to call multiple times
      try {
        await FirebaseService.initialize();
        print('✓ Firebase Service initialized');
      } catch (e) {
        print('Firebase Service initialization: $e');
      }

      // Initialize Analytics
      final analyticsService = AnalyticsService();
      await analyticsService.initialize();
      print('✓ Analytics Service initialized');

      // Initialize Barcode Service
      final barcodeService = BarcodeService();
      await barcodeService.initializeScanner();
      print('✓ Barcode Service initialized');

      // Initialize Cloud Storage
      final cloudStorageService = CloudStorageService();
      await cloudStorageService.initialize();
      print('✓ Cloud Storage Service initialized');

      _isInitialized = true;
      print('✓ All services initialized successfully');
    } catch (e) {
      print('✗ Error initializing services: $e');
      rethrow;
    }
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

  /// Get Firebase service instance
  FirebaseService getFirebaseService() {
    if (!FirebaseService().isInitialized) {
      throw Exception('Firebase Service not initialized.');
    }
    return FirebaseService();
  }
}

