import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import '../data/local/database_helper.dart';
import '../domain/repositories/sales_repository.dart';
import '../data/repositories/sales_repository_impl.dart';
import '../data/repositories/inventory_repository_impl.dart';
import '../data/repositories/customer_repository_impl.dart';

class SyncService {
  static const String _lastSyncKey = 'last_sync_time';

  /// After this many failed attempts, a sale is escalated from 'failed' to
  /// 'error' so the UI can tell "hasn't had a chance to sync yet" apart
  /// from "keeps failing — needs a human to look at it" (e.g. its product
  /// was deleted from inventory, or the local record is malformed).
  static const int maxAutoRetryAttempts = 5;

  /// Sync entry points fire from several independent places (app startup,
  /// reconnect, the manual "push to Firebase" button, and each provider's
  /// own post-checkout trigger) that don't share a single SyncService
  /// instance. Without a process-wide guard, two of those firing close
  /// together could both read the same pending rows and sync them twice.
  /// syncSaleToFirestore's inventorySyncApplied flag stops that from
  /// double-deducting stock, but it's still wasted writes and a race on
  /// which one wins the final syncStatus update — cheap enough to just
  /// prevent outright by serializing sales sync.
  static bool _salesSyncInProgress = false;

  static const Duration _syncTimeout = Duration(seconds: 30);

  final DatabaseHelper _dbHelper;
  late final SalesRepository _salesRepository;
  InventoryRepositoryImpl? _inventoryRepository;
  CustomerRepositoryImpl? _customerRepository;

  SyncService({
    DatabaseHelper? dbHelper,
    SalesRepository? salesRepository,
    FirebaseFirestore? firestore,
    InventoryRepositoryImpl? inventoryRepository,
    CustomerRepositoryImpl? customerRepository,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;
    _salesRepository =
        salesRepository ?? SalesRepositoryImpl(firestore: resolvedFirestore);
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

  /// Count of offline sales still awaiting (or needing retry of) sync.
  ///
  /// Deliberately reads the `sales` table's syncStatus rather than
  /// `sync_queue` — rows added to sync_queue are never removed by
  /// [syncSales], so a badge sourced from it only ever grows and never
  /// reflects reality once sales actually finish syncing.
  Future<int> getPendingSalesCount() async {
    final pending = await _salesRepository.getPendingOfflineSales();
    return pending.length;
  }

  /// Count of sales that have failed to sync [maxAutoRetryAttempts] times
  /// or more — distinct from the general pending count so the UI can flag
  /// "these need a human to look at them" separately from "just hasn't
  /// synced yet".
  Future<int> getErroredSalesCount() async {
    final errored = await _dbHelper.query('sales', where: 'syncStatus = ?', whereArgs: ['error']);
    return errored.length;
  }

  Future<void> syncAll() async {
    try {
      // Sync sales
      await syncSales();

      // Sync inventory
      await syncInventory();

      // Sync customers
      await syncCustomers();

      // Update last sync time
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
      // Get pending sales from local database using repository
      final pendingSales = await _salesRepository.getPendingOfflineSales();

      for (final saleData in pendingSales) {
        final saleId = saleData['id']?.toString() ?? '';
        if (saleId.isEmpty) continue;

        // Fail fast on sales that can never sync rather than burning a
        // network round-trip (and an attempt) on something no retry can
        // fix — e.g. a record that lost its businessId to a bad write.
        final businessId = saleData['businessId']?.toString() ?? '';
        if (businessId.isEmpty) {
          await _recordSyncFailure(saleId, saleData, 'Missing businessId — cannot sync', forceError: true);
          continue;
        }

        try {
          // Sync to Firestore using repository, bounded so a hung
          // connection can't leave this loop (and _isSyncing) stuck.
          await _salesRepository.syncSaleToFirestore(saleData).timeout(_syncTimeout);

          // Mark as synced
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
        // Truncated — this is a diagnostic breadcrumb for the UI, not a log.
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

      // Get pending inventory items
      final pendingItems = await _dbHelper.query(
        'inventory',
        where: 'syncStatus = ?',
        whereArgs: ['pending'],
      );

      for (final itemData in pendingItems) {
        try {
          // Sync to Firestore
          await inventoryRepository.syncInventoryToFirestore(itemData);

          // Update sync status
          await _dbHelper.update(
            'inventory',
            {'syncStatus': 'synced'},
            where: 'id = ?',
            whereArgs: [itemData['id']],
          );
        } catch (e) {
          // Mark as failed
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

      // Get pending customers
      final pendingCustomers = await _dbHelper.query(
        'customers',
        where: 'syncStatus = ?',
        whereArgs: ['pending'],
      );

      for (final customerData in pendingCustomers) {
        try {
          // Sync to Firestore
          await customerRepository.syncCustomerToFirestore(customerData);

          // Update sync status
          await _dbHelper.update(
            'customers',
            {'syncStatus': 'synced'},
            where: 'id = ?',
            whereArgs: [customerData['id']],
          );
        } catch (e) {
          // Mark as failed
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
          // Process based on entity type
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

          // Remove from sync queue
          await _dbHelper.removeSyncItem(item['id']);
        } catch (e) {
          // Increment attempt counter
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

