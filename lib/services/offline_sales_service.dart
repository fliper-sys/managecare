import 'package:flutter/foundation.dart';
import '../domain/repositories/sales_repository.dart';
import '../providers/connectivity_provider.dart';
import '../core/utils/connectivity_helper.dart';
import 'sync_service.dart';

/// Service for handling sales creation with offline support.
/// Routes sales to either Postgres API (online) or SQLite (offline).
class OfflineSalesService {
  final SalesRepository _salesRepository;
  final ConnectivityProvider? _connectivityProvider;
  final Future<bool> Function()? _connectivityChecker;

  OfflineSalesService({
    required SalesRepository salesRepository,
    ConnectivityProvider? connectivityProvider,
    Future<bool> Function()? connectivityChecker,
  })  : _salesRepository = salesRepository,
        _connectivityProvider = connectivityProvider,
        _connectivityChecker = connectivityChecker;

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    try {
      final isConnected = await _checkConnectivity();
      if (isConnected) {
        final result = await _salesRepository.createSale(saleData);
        return {
          'success': true,
          'data': result,
          'mode': 'online',
        };
      } else {
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

  Future<bool> _checkConnectivity() async {
    if (_connectivityChecker != null) {
      return await _connectivityChecker!();
    }
    if (_connectivityProvider != null) {
      return _connectivityProvider!.isConnected;
    }
    try {
      return await ConnectivityHelper.hasInternetConnection();
    } catch (e) {
      debugPrint('[OfflineSalesService] Error checking connectivity: $e');
      return true;
    }
  }

  Future<int> getPendingOfflineSalesCount() async {
    try {
      final pendingSales = await _salesRepository.getPendingOfflineSales();
      return pendingSales.length;
    } catch (e) {
      debugPrint('[OfflineSalesService] Error getting pending sales count: $e');
      return 0;
    }
  }

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
