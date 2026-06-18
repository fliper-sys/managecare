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
    try {
      // Get pending sales from local database using repository
      final pendingSales = await _salesRepository.getPendingOfflineSales();

      for (final saleData in pendingSales) {
        try {
          // Sync to Firestore using repository
          await _salesRepository.syncSaleToFirestore(saleData);

          // Mark as synced
          final saleId = saleData['id'].toString();
          await _salesRepository.markSaleAsSynced(saleId);
        } catch (e) {
          // Mark as failed
          final saleId = saleData['id'].toString();
          await _dbHelper.update(
            'sales',
            {'syncStatus': 'failed'},
            where: 'id = ?',
            whereArgs: [saleId],
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to sync sales: $e');
    }
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

