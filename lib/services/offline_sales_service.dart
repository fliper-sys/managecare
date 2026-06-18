import 'package:flutter/foundation.dart';
import '../domain/repositories/sales_repository.dart';
import '../providers/connectivity_provider.dart';
import '../core/utils/connectivity_helper.dart';
import 'sync_service.dart';

/// Service for handling sales creation with offline support
class OfflineSalesService {
  final SalesRepository _salesRepository;
  final ConnectivityProvider? _connectivityProvider;
  final Future<bool> Function()? _connectivityChecker;

  OfflineSalesService({
    required SalesRepository salesRepository,
    ConnectivityProvider? connectivityProvider,
    Future<bool> Function()? connectivityChecker,
  }) : _salesRepository = salesRepository,
       _connectivityProvider = connectivityProvider,
       _connectivityChecker = connectivityChecker;

  /// Create a sale, automatically choosing between online and offline storage
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    try {
      // Check connectivity
      final isConnected = await _checkConnectivity();

      if (isConnected) {
        // Create sale online
        final result = await _salesRepository.createSale(saleData);
        return {
          'success': true,
          'data': result,
          'mode': 'online',
        };
      } else {
        // Create sale offline
        final saleId = await _salesRepository.createSaleOffline(saleData);
        return {
          'success': true,
          'data': {'id': saleId, ...saleData},
          'mode': 'offline',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'mode': 'unknown',
      };
    }
  }

  /// Check if device is connected to internet
  Future<bool> _checkConnectivity() async {
    if (_connectivityChecker != null) {
      return await _connectivityChecker!();
    }

    if (_connectivityProvider != null) {
      return _connectivityProvider!.isConnected;
    }

    // Fallback to connectivity utils if provider not available
    try {
      return await ConnectivityHelper.hasInternetConnection();
    } catch (e) {
      debugPrint('[OfflineSalesService] Error checking connectivity: $e');
      // Assume connected if we can't check
      return true;
    }
  }

  /// Get count of pending offline sales
  Future<int> getPendingOfflineSalesCount() async {
    try {
      final pendingSales = await _salesRepository.getPendingOfflineSales();
      return pendingSales.length;
    } catch (e) {
      debugPrint('[OfflineSalesService] Error getting pending sales count: $e');
      return 0;
    }
  }

  /// Force sync all pending sales
  Future<void> forceSyncPendingSales() async {
    try {
      final syncService = SyncService();
      await syncService.syncSales();
    } catch (e) {
      debugPrint('[OfflineSalesService] Error syncing pending sales: $e');
      rethrow;
    }
  }
}
