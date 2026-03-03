import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../data/local/database_helper.dart';

/// Sync provider for offline sync state and operations
class SyncProvider extends ChangeNotifier {
  bool _isSyncing = false;
  int _pendingItems = 0;
  DateTime? _lastSyncTime;
  String? _syncError;
  int _syncedCount = 0;

  bool get isSyncing => _isSyncing;
  int get pendingItems => _pendingItems;
  bool get hasPendingItems => _pendingItems > 0;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  int get syncedCount => _syncedCount;

  /// Start synchronizing offline data with Firebase
  Future<void> startSync() async {
    _isSyncing = true;
    _syncError = null;
    _syncedCount = 0;
    notifyListeners();

    try {
      // Get pending items from sync queue
      final dbHelper = DatabaseHelper.instance;
      final pendingItems = await dbHelper.getPendingSyncItems();

      _pendingItems = pendingItems.length;

      // Sync each pending item
      for (final item in pendingItems) {
        try {
          final syncId = item['id'] as int?;
          final collection = item['collection'] as String?;
          final docId = item['docId'] as String?;
          final data = item['data'] as Map<String, dynamic>?;

          if (syncId != null &&
              collection != null &&
              docId != null &&
              data != null) {
            // Use static method FirebaseService.saveData
            await FirebaseService.saveData(
              collection,
              docId,
              data,
              merge: true,
            );

            // Remove from sync queue after successful sync
            await dbHelper.removeSyncItem(syncId);
            _syncedCount++;
          }
        } catch (e) {
          final syncId = item['id'] as int?;
          if (syncId != null) {
            // Increment attempt count on failure
            await dbHelper.incrementSyncAttempt(syncId);
          }
          print('Error syncing item: $e');
          _syncError = 'Error syncing items: $e';
        }
      }

      _lastSyncTime = DateTime.now();
      _pendingItems = 0;
    } catch (e) {
      _syncError = 'Sync failed: $e';
      print('Sync error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Set pending items count (usually from database query)
  void setPendingItems(int count) {
    _pendingItems = count;
    notifyListeners();
  }

  /// Check and update pending items from database
  Future<void> checkPendingItems() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final pendingItems = await dbHelper.getPendingSyncItems();

      _pendingItems = pendingItems.length;
      notifyListeners();
    } catch (e) {
      print('Error checking pending items: $e');
    }
  }

  /// Clear sync error
  void clearError() {
    _syncError = null;
    notifyListeners();
  }

  /// Get sync status summary
  Map<String, dynamic> getSyncStatus() {
    return {
      'isSyncing': _isSyncing,
      'pendingItems': _pendingItems,
      'syncedCount': _syncedCount,
      'lastSyncTime': _lastSyncTime,
      'error': _syncError,
    };
  }
}

