import 'package:hive/hive.dart';
import '../../domain/repositories/offline_sync_repository.dart';

/// Hive implementation of offline sync repository
class OfflineSyncRepositoryImpl implements OfflineSyncRepository {
  static const String _pendingSalesBox = 'pending_sales';
  static const String _pendingInventoryBox = 'pending_inventory';

  @override
  Future<void> savePendingSale(Map<String, dynamic> saleData) async {
    try {
      final box = await Hive.openBox(_pendingSalesBox);
      await box.add(saleData);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> savePendingInventory(Map<String, dynamic> inventoryData) async {
    try {
      final box = await Hive.openBox(_pendingInventoryBox);
      await box.add(inventoryData);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getPendingSales(String businessId) async {
    try {
      final box = await Hive.openBox(_pendingSalesBox);
      return box.values
          .where((item) => (item as Map)['businessId'] == businessId)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getPendingInventory(String businessId) async {
    try {
      final box = await Hive.openBox(_pendingInventoryBox);
      return box.values
          .where((item) => (item as Map)['businessId'] == businessId)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> clearPendingSale(String saleId) async {
    try {
      final box = await Hive.openBox(_pendingSalesBox);
      final index = box.values
          .toList()
          .indexWhere((item) => (item as Map)['id'] == saleId);
      if (index != -1) {
        await box.deleteAt(index);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> clearPendingInventory(String inventoryId) async {
    try {
      final box = await Hive.openBox(_pendingInventoryBox);
      final index = box.values
          .toList()
          .indexWhere((item) => (item as Map)['id'] == inventoryId);
      if (index != -1) {
        await box.deleteAt(index);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> syncAllPending(String businessId) async {
    try {
      // TODO: Implement sync logic with Firebase
      // This would typically:
      // 1. Get all pending items
      // 2. Upload to Firebase
      // 3. Clear local cache on success
    } catch (e) {
      rethrow;
    }
  }
}

