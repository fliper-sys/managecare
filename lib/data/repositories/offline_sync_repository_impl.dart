import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'sales_repository_impl.dart';
import 'inventory_repository_impl.dart';
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
      if (businessId.trim().isEmpty) {
        throw Exception('businessId is required to sync pending data');
      }

      final firestore = FirebaseFirestore.instance;
      final salesRepository = SalesRepositoryImpl(firestore: firestore);
      final inventoryRepository = InventoryRepositoryImpl(firestore: firestore);

      final salesBox = await Hive.openBox(_pendingSalesBox);
      final inventoryBox = await Hive.openBox(_pendingInventoryBox);

      final pendingSales = salesBox.toMap().entries
          .where((entry) => (entry.value as Map)['businessId'] == businessId)
          .toList();

      for (final entry in pendingSales) {
        try {
          final saleData = Map<String, dynamic>.from(entry.value as Map);
          saleData['id'] ??= entry.key.toString();
          saleData['businessId'] = businessId;

          await salesRepository.syncSaleToFirestore(saleData);
          await salesBox.delete(entry.key);
        } catch (e) {
          print('[OfflineSyncRepository] Failed to sync sale ${entry.key}: $e');
        }
      }

      final pendingInventory = inventoryBox.toMap().entries
          .where((entry) => (entry.value as Map)['businessId'] == businessId)
          .toList();

      for (final entry in pendingInventory) {
        try {
          final inventoryData = Map<String, dynamic>.from(entry.value as Map);
          inventoryData['id'] ??= entry.key.toString();
          inventoryData['businessId'] = businessId;

          await inventoryRepository.syncInventoryToFirestore(inventoryData);
          await inventoryBox.delete(entry.key);
        } catch (e) {
          print(
              '[OfflineSyncRepository] Failed to sync inventory ${entry.key}: $e');
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}

