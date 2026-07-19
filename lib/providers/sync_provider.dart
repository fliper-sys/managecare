import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/sync_service.dart';
import '../data/local/database_helper.dart';

/// Sync provider for offline sync state and operations
class SyncProvider extends ChangeNotifier {
  bool _isSyncing = false;
  int _pendingItems = 0;
  int _erroredItems = 0;
  DateTime? _lastSyncTime;
  String? _syncError;
  int _syncedCount = 0;

  bool get isSyncing => _isSyncing;
  int get pendingItems => _pendingItems;
  bool get hasPendingItems => _pendingItems > 0;
  /// Sales that have failed to sync repeatedly and need attention — a
  /// subset of [pendingItems], not additional to it.
  int get erroredItems => _erroredItems;
  bool get hasErroredItems => _erroredItems > 0;
  /// True once pending sales pile up enough to be a real data-loss risk if
  /// this device were lost, reset, or uninstalled before they sync.
  bool get hasHighRiskBacklog => _pendingItems >= dataLossRiskThreshold;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  int get syncedCount => _syncedCount;

  static const int dataLossRiskThreshold = 10;

  /// Sync all pending offline sales to Firestore — creates each queued
  /// sale's transaction record and applies its stock deduction.
  /// Called automatically by [ConnectivityProvider] when connectivity returns,
  /// and can be called manually from the UI (e.g. a "Push to Firebase" button).
  /// Returns a short human-readable summary suitable for a snackbar.
  Future<String> syncNow() async {
    if (_isSyncing) return 'Sync already in progress';
    _isSyncing = true;
    _syncError = null;
    _syncedCount = 0;
    notifyListeners();

    try {
      final syncService = SyncService(firestore: FirebaseFirestore.instance);
      final beforeCount = await syncService.getPendingSalesCount();
      await syncService.syncSales();
      final afterCount = await syncService.getPendingSalesCount();
      _syncedCount = (beforeCount - afterCount).clamp(0, beforeCount);
      _pendingItems = afterCount;
      _erroredItems = await syncService.getErroredSalesCount();
      _lastSyncTime = DateTime.now();

      if (beforeCount == 0) return 'No offline sales to sync';
      if (afterCount == 0) {
        return '$_syncedCount sale${_syncedCount == 1 ? '' : 's'} pushed to Firebase';
      }
      final errorNote = _erroredItems > 0
          ? ' ($_erroredItems repeatedly failing — check Sales History)'
          : ' (no connection, or a sync error)';
      return '$_syncedCount sale${_syncedCount == 1 ? '' : 's'} synced, '
          '$afterCount still pending$errorNote';
    } catch (e) {
      _syncError = e.toString();
      debugPrint('[SyncProvider] syncNow failed: $e');
      return 'Sync failed: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

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

  /// Check and update the pending-sales count from the local database.
  /// Call this right after an offline sale is queued (so the UI badge is
  /// accurate immediately) and on app start.
  Future<void> checkPendingItems() async {
    try {
      final syncService = SyncService(firestore: FirebaseFirestore.instance);
      _pendingItems = await syncService.getPendingSalesCount();
      _erroredItems = await syncService.getErroredSalesCount();
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

