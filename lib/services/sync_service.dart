import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:business_manager/data/repositories/sales_repository_supabase.dart';
import 'package:business_manager/data/repositories/inventory_repository_supabase.dart';
import 'package:business_manager/data/repositories/customer_repository_supabase.dart';
import '../data/local/database_helper.dart';
import '../domain/repositories/sales_repository.dart';

/// Sync service that targets the self-hosted Postgres API (Express backend)
/// instead of Firebase Firestore.
class SyncService {
  static const String _lastSyncKey = 'last_sync_time';

  static const int maxAutoRetryAttempts = 5;

  static bool _salesSyncInProgress = false;

  static const Duration _syncTimeout = Duration(seconds: 30);

  final DatabaseHelper _dbHelper;
  late final SalesRepository _salesRepository;
  InventoryRepositorySupabase? _inventoryRepository;
  CustomerRepositorySupabase? _customerRepository;

  SyncService({
    DatabaseHelper? dbHelper,
    SalesRepository? salesRepository,
    InventoryRepositorySupabase? inventoryRepository,
    CustomerRepositorySupabase? customerRepository,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance {
    _salesRepository = salesRepository ?? SalesRepositorySupabase();
    _inventoryRepository = inventoryRepository;
    _customerRepository = customerRepository;
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncKey);
    return timestamp != null ? parseTimestamp(timestamp) : null;
  }

  Future<void> _setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, time.toIso8601String());
  }

  Future<int> getPendingItemsCount() async {
    final pendingItems = await _dbHelper.getPendingSyncItems();
    return pendingItems.length;
  }

  Future<int> getPendingSalesCount() async {
    final pending = await _salesRepository.getPendingOfflineSales();
    return pending.length;
  }

  Future<int> getErroredSalesCount() async {
    final errored = await _dbHelper.query('sales', where: 'syncStatus = ?', whereArgs: ['error']);
    return errored.length;
  }

  Future<void> syncAll() async {
    try {
      await syncSales();
      await syncInventory();
      await syncCustomers();
      await _setLastSyncTime(DateTime.now());
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  Future<void> syncSales() async {
    if (_salesSyncInProgress) {
      debugPrint('[SyncService] Sales sync already in progress elsewhere, skipping this call');
      return;
    }
    _salesSyncInProgress = true;
    try {
      final pendingSales = await _salesRepository.getPendingOfflineSales();
      for (final saleData in pendingSales) {
        final saleId = saleData['id']?.toString() ?? '';
        if (saleId.isEmpty) continue;
        final businessId = saleData['businessId']?.toString() ?? '';
        if (businessId.isEmpty) {
          await _recordSyncFailure(saleId, saleData, 'Missing businessId - cannot sync', forceError: true);
          continue;
        }
        try {
          await _salesRepository.syncSaleToFirestore(saleData).timeout(_syncTimeout);
          await _salesRepository.markSaleAsSynced(saleId);
        } catch (e) {
          await _recordSyncFailure(saleId, saleData, e.toString());
        }
      }
    } catch (e) {
      throw Exception('Failed to sync sales: $e');
    } finally {
      _salesSyncInProgress = false;
    }
  }

  Future<void> _recordSyncFailure(
    String saleId,
    Map<String, dynamic> saleData,
    String error, {
    bool forceError = false,
  }) async {
    final priorAttempts = (saleData['syncAttempts'] as num?)?.toInt() ?? 0;
    final attempts = priorAttempts + 1;
    final status = forceError || attempts >= maxAutoRetryAttempts ? 'error' : 'failed';
    await _dbHelper.update(
      'sales',
      {
        'syncStatus': status,
        'syncAttempts': attempts,
        'lastSyncError': error.length > 300 ? error.substring(0, 300) : error,
        'lastSyncAttemptAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }

  Future<void> syncInventory() async {
    try {
      final inventoryRepository = _inventoryRepository;
      if (inventoryRepository == null) {
        throw StateError('Inventory repository is not configured');
      }
      final pendingItems = await _dbHelper.query(
        'inventory',
        where: 'syncStatus = ?',
        whereArgs: ['pending'],
      );
      for (final itemData in pendingItems) {
        try {
          await inventoryRepository.syncInventoryToFirestore(itemData);
          await _dbHelper.update(
            'inventory',
            {'syncStatus': 'synced'},
            where: 'id = ?',
            whereArgs: [itemData['id']],
          );
        } catch (e) {
          await _dbHelper.update(
            'inventory',
            {'syncStatus': 'failed'},
            where: 'id = ?',
            whereArgs: [itemData['id']],
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to sync inventory: $e');
    }
  }

  Future<void> syncCustomers() async {
    try {
      final customerRepository = _customerRepository;
      if (customerRepository == null) {
        throw StateError('Customer repository is not configured');
      }
      final pendingCustomers = await _dbHelper.query(
        'customers',
        where: 'syncStatus = ?',
        whereArgs: ['pending'],
      );
      for (final customerData in pendingCustomers) {
        try {
          await customerRepository.syncCustomerToFirestore(customerData);
          await _dbHelper.update(
            'customers',
            {'syncStatus': 'synced'},
            where: 'id = ?',
            whereArgs: [customerData['id']],
          );
        } catch (e) {
          await _dbHelper.update(
            'customers',
            {'syncStatus': 'failed'},
            where: 'id = ?',
            whereArgs: [customerData['id']],
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to sync customers: $e');
    }
  }

  Future<void> processSyncQueue() async {
    try {
      final pendingItems = await _dbHelper.getPendingSyncItems();
      for (final item in pendingItems) {
        try {
          switch (item['entityType']) {
            case 'sale':
              await syncSales();
              break;
            case 'inventory':
              await syncInventory();
              break;
            case 'customer':
              await syncCustomers();
              break;
          }
          await _dbHelper.removeSyncItem(item['id']);
        } catch (e) {
          await _dbHelper.incrementSyncAttempt(item['id']);
        }
      }
    } catch (e) {
      throw Exception('Failed to process sync queue: $e');
    }
  }

  Future<void> clearSyncQueue() async {
    final db = await _dbHelper.database;
    await db.delete('sync_queue');
  }

  Future<bool> hasUnSyncedData() async {
    final count = await getPendingItemsCount();
    return count > 0;
  }
}
