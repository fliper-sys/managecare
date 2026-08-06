import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../data/local/database_helper.dart';
import '../data/repositories/inventory_repository_supabase.dart';
import '../data/repositories/customer_repository_supabase.dart';

/// Supabase/Postgres-backed SyncService.
///
/// Replaces the Firestore-based SyncService. Offline data is synced to the
/// self-hosted Express API (which writes to PostgreSQL) instead of Firestore.
class SyncService {
  static const String _lastSyncKey = 'last_sync_time';

  /// After this many failed attempts, a sale is escalated from 'failed' to
  /// 'error' so the UI can distinguish "hasn't had a chance to sync yet"
  /// from "keeps failing — needs a human to look at it".
  static const int maxAutoRetryAttempts = 5;

  /// Serializes sales sync to prevent concurrent runs from different call sites.
  static bool _salesSyncInProgress = false;

  static const Duration _syncTimeout = Duration(seconds: 30);

  final DatabaseHelper _dbHelper;
  final InventoryRepositorySupabase? _inventoryRepository;
  final CustomerRepositorySupabase? _customerRepository;
  final Dio _http;
  final SupabaseClient _supabase;

  SyncService({
    DatabaseHelper? dbHelper,
    InventoryRepositorySupabase? inventoryRepository,
    CustomerRepositorySupabase? customerRepository,
    Dio? http,
    SupabaseClient? supabase,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )),
        _supabase = supabase ?? Supabase.instance.client,
        _inventoryRepository = inventoryRepository,
        _customerRepository = customerRepository;

  String? get _accessToken => _supabase.auth.currentSession?.accessToken;
  Map<String, dynamic> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncKey);
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, time.toIso8601String());
  }

  Future<int> getPendingItemsCount() async {
    final pendingItems = await _dbHelper.getPendingSyncItems();
    return pendingItems.length;
  }

  /// Count of offline sales still awaiting sync.
  Future<int> getPendingSalesCount() async {
    try {
      final pending = await _dbHelper.query(
        'sales',
        where: 'syncStatus = ?',
        whereArgs: ['pending'],
      );
      final failed = await _dbHelper.query(
        'sales',
        where: 'syncStatus = ?',
        whereArgs: ['failed'],
      );
      final errored = await _dbHelper.query(
        'sales',
        where: 'syncStatus = ?',
        whereArgs: ['error'],
      );
      return pending.length + failed.length + errored.length;
    } catch (e) {
      debugPrint('[SyncService] Error counting pending sales: $e');
      return 0;
    }
  }

  /// Count of sales that have failed to sync [maxAutoRetryAttempts] times.
  Future<int> getErroredSalesCount() async {
    try {
      final errored = await _dbHelper.query(
        'sales',
        where: 'syncStatus = ?',
        whereArgs: ['error'],
      );
      return errored.length;
    } catch (e) {
      return 0;
    }
  }

  /// Sync all pending data (sales, inventory, customers) to the Postgres API.
  Future<void> syncAll() async {
    try {
      await syncSales();
      await syncInventory();
      await syncCustomers();
      await _setLastSyncTime(DateTime.now());
      debugPrint('[SyncService] SyncAll completed');
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  /// Sync pending offline sales to the Postgres API.
  Future<void> syncSales() async {
    if (_salesSyncInProgress) {
      debugPrint('[SyncService] Sales sync already in progress, skipping');
      return;
    }
    _salesSyncInProgress = true;

    try {
      final pendingSales = await _dbHelper.query(
        'sales',
        where: 'syncStatus = ? OR syncStatus = ? OR syncStatus = ?',
        whereArgs: ['pending', 'failed', 'error'],
      );

      for (final saleData in pendingSales) {
        final saleId = saleData['id']?.toString() ?? '';
        if (saleId.isEmpty) continue;

        final businessId = saleData['businessId']?.toString() ?? '';
        if (businessId.isEmpty) {
          await _recordSyncFailure(
            saleId,
            saleData,
            'Missing businessId — cannot sync',
            forceError: true,
          );
          continue;
        }

        try {
          await _syncSaleToApi(saleData).timeout(_syncTimeout);
          await _dbHelper.update(
            'sales',
            {'syncStatus': 'synced'},
            where: 'id = ?',
            whereArgs: [saleId],
          );
        } catch (e) {
          await _recordSyncFailure(saleId, saleData, e.toString());
        }
      }
    } catch (e) {
      debugPrint('[SyncService] syncSales error: $e');
    } finally {
      _salesSyncInProgress = false;
    }
  }

  /// Sync a single sale record to the Express API with last-writer-wins conflict
  /// resolution based on `updated_at` timestamp.
  Future<void> _syncSaleToApi(Map<String, dynamic> saleData) async {
    final businessId = saleData['businessId']?.toString() ?? '';
    final saleId = saleData['id']?.toString() ?? '';

    final localItems = await _dbHelper.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
    );

    // A completed sale always has at least one cart item
    // (_saveSaleOfflineItems only runs on a non-empty cart), so finding zero
    // local sale_items rows here means either they haven't finished writing
    // yet or something went wrong locally - either way, syncing now would
    // permanently create an itemless sale on the server (the backend has no
    // record of what was actually sold, and there's no local copy left to
    // repair it from once this sale is marked 'synced'). Throwing here - and
    // doing it before any PUT/POST call - keeps the sale in 'pending'/
    // 'failed' status so the normal retry loop tries again shortly instead
    // of silently losing the line items.
    if (localItems.isEmpty) {
      throw Exception(
          'Sale $saleId has no local items to sync yet - retrying later');
    }

    // The local offline-sale queue is written in the old Firestore-era
    // camelCase shape (see retail_provider.dart's _saveSaleOffline), but the
    // backend's sales route reads Postgres's snake_case columns - sending
    // saleData through unmapped means every field the server requires
    // (final_amount, payment_method, ...) reads as undefined and the sync
    // fails every time. created_at is forwarded explicitly so a sale synced
    // the next day still lands on the day it actually happened, not the
    // sync day.
    final payload = <String, dynamic>{
      'id': saleId,
      'customer_id': saleData['customerId'],
      'store_id': saleData['storeId'],
      'worker_id': saleData['workerId'],
      'worker_name': saleData['workerName'],
      'total_amount': saleData['totalAmount'],
      'discount_amount': saleData['discountAmount'],
      'tax_amount': saleData['taxAmount'],
      'final_amount': saleData['finalAmount'] ?? saleData['totalAmount'],
      'payment_method': saleData['paymentMethod'] ?? 'Cash',
      'status': saleData['status'] ?? 'completed',
      'notes': saleData['notes'],
      'created_by': saleData['createdBy'],
      'sale_type': saleData['saleType'] ?? 'retail',
      'created_at': saleData['createdAt'],
      'updated_at': saleData['updated_at'] ??
          DateTime.now().toUtc().toIso8601String(),
      'items': localItems
          .map((item) => {
                'product_id': item['productId'],
                'product_name': item['productName'],
                'quantity': item['quantity'],
                'unit_price': item['unitPrice'],
                'discount': item['discount'] ?? 0,
                'total': item['total'],
                'pricing_mode': item['pricingMode'],
                'inventory_unit': item['inventoryUnit'],
                'sale_unit': item['saleUnit'],
                'sale_unit_multiplier': item['saleUnitMultiplier'] ?? 1,
              })
          .toList(),
    }..removeWhere((key, value) => value == null);

    try {
      // Try PUT first (update existing record)
      await _http.put(
        '/sales/$businessId/$saleId',
        data: payload,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Record doesn't exist on server yet — create it
        await _http.post(
          '/sales/$businessId',
          data: payload,
          options: Options(headers: _headers),
        );
        return;
      }
      // Re-throw other errors for the caller to handle
      rethrow;
    }
  }

  // ignore: unused_element - Reserved for future per-entity conflict resolution
  /// Timestamp-based conflict resolver.
  ///
  /// On conflict, the record with the most recent `updated_at` wins
  /// (last-writer-wins). The server is the source of truth for `synced`
  /// records; local overrides if local `updated_at` is more recent.
  Future<Map<String, dynamic>?> _resolveConflict({
    required String entityType,
    required String businessId,
    required String entityId,
    required Map<String, dynamic> localData,
  }) async {
    try {
      final response = await _http.get(
        '/$entityType/$businessId/$entityId',
        options: Options(headers: _headers),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final serverData = response.data as Map<String, dynamic>;
        final localUpdated = _parseUpdatedAt(localData['updated_at']);
        final serverUpdated = _parseUpdatedAt(serverData['updated_at']);

        if (localUpdated != null && serverUpdated != null) {
          if (localUpdated.isAfter(serverUpdated)) {
            // Local is newer — push local version to server
            await _http.put(
              '/$entityType/$businessId/$entityId',
              data: localData,
              options: Options(headers: _headers),
            );
            return localData;
          } else {
            // Server is newer or equal — accept server version
            debugPrint('[SyncService] Server version is newer for $entityType/$entityId');
            return serverData;
          }
        }
      }
    } catch (e) {
      debugPrint('[SyncService] Conflict resolution error for $entityType/$entityId: $e');
    }
    // Fallback: return null so caller proceeds with local data
    return null;
  }

  /// Parse updated_at from various formats.
  DateTime? _parseUpdatedAt(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
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
    final status =
        forceError || attempts >= maxAutoRetryAttempts ? 'error' : 'failed';

    await _dbHelper.update(
      'sales',
      {
        'syncStatus': status,
        'syncAttempts': attempts,
        'lastSyncError':
            error.length > 300 ? error.substring(0, 300) : error,
        'lastSyncAttemptAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }

  /// Sync pending inventory items to the Postgres API.
  Future<void> syncInventory() async {
    try {
      if (_inventoryRepository == null) {
        debugPrint('[SyncService] Inventory repository not configured, skipping');
        return;
      }

      final pendingItems = await _dbHelper.query(
        'inventory',
        where: 'syncStatus = ?',
        whereArgs: ['pending'],
      );

      for (final itemData in pendingItems) {
        try {
          final businessId = itemData['businessId']?.toString() ?? '';
          final itemId = itemData['id']?.toString() ?? '';
          if (businessId.isEmpty || itemId.isEmpty) continue;

          try {
            await _http.put(
              '/inventory/$businessId/$itemId',
              data: itemData,
              options: Options(headers: _headers),
            );
          } catch (_) {
            await _http.post(
              '/inventory/$businessId',
              data: itemData,
              options: Options(headers: _headers),
            );
          }

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
      debugPrint('[SyncService] syncInventory error: $e');
    }
  }

  /// Sync pending customers to the Postgres API.
  Future<void> syncCustomers() async {
    try {
      if (_customerRepository == null) {
        debugPrint('[SyncService] Customer repository not configured, skipping');
        return;
      }

      final pendingCustomers = await _dbHelper.query(
        'customers',
        where: 'syncStatus = ?',
        whereArgs: ['pending'],
      );

      for (final customerData in pendingCustomers) {
        try {
          final businessId = customerData['businessId']?.toString() ?? '';
          final customerId = customerData['id']?.toString() ?? '';
          if (businessId.isEmpty || customerId.isEmpty) continue;

          try {
            await _http.put(
              '/customers/$businessId/$customerId',
              data: customerData,
              options: Options(headers: _headers),
            );
          } catch (_) {
            await _http.post(
              '/customers/$businessId',
              data: customerData,
              options: Options(headers: _headers),
            );
          }

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
      debugPrint('[SyncService] syncCustomers error: $e');
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
      debugPrint('[SyncService] processSyncQueue error: $e');
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
