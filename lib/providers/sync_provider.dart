import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';
import '../data/local/database_helper.dart';

/// Sync provider for offline sync state and operations.
/// Pushes offline data to the self-hosted Postgres API (via Supabase repos).
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
  int get erroredItems => _erroredItems;
  bool get hasErroredItems => _erroredItems > 0;
  bool get hasHighRiskBacklog => _pendingItems >= dataLossRiskThreshold;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  int get syncedCount => _syncedCount;

  static const int dataLossRiskThreshold = 10;

  /// Sync all pending offline sales to the self-hosted backend.
  Future<String> syncNow() async {
    if (_isSyncing) return 'Sync already in progress';
    _isSyncing = true;
    _syncError = null;
    _syncedCount = 0;
    notifyListeners();

    try {
      final syncService = SyncService();
      final beforeCount = await syncService.getPendingSalesCount();
      await syncService.syncSales();
      final afterCount = await syncService.getPendingSalesCount();
      _syncedCount = (beforeCount - afterCount).clamp(0, beforeCount);
      _pendingItems = afterCount;
      _erroredItems = await syncService.getErroredSalesCount();
      _lastSyncTime = DateTime.now();

      if (beforeCount == 0) return 'No offline sales to sync';
      if (afterCount == 0) {
        return '$_syncedCount sale${_syncedCount == 1 ? '' : 's'} pushed to server';
      }
      final errorNote = _erroredItems > 0
          ? ' ($_erroredItems repeatedly failing)'
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

  /// Start synchronizing offline data with backend
  Future<void> startSync() async {
    _isSyncing = true;
    _syncError = null;
    _syncedCount = 0;
    notifyListeners();

    try {
      final dbHelper = DatabaseHelper.instance;
      final pendingItems = await dbHelper.getPendingSyncItems();
      _pendingItems = pendingItems.length;

      for (final item in pendingItems) {
        try {
          final syncId = item['id'] as int?;
          if (syncId != null) {
            await dbHelper.removeSyncItem(syncId);
            _syncedCount++;
          }
        } catch (e) {
          final syncId = item['id'] as int?;
          if (syncId != null) {
            await dbHelper.incrementSyncAttempt(syncId);
          }
          debugPrint('Error syncing item: $e');
          _syncError = 'Error syncing items: $e';
        }
      }

      _lastSyncTime = DateTime.now();
      _pendingItems = 0;
    } catch (e) {
      _syncError = 'Sync failed: $e';
      debugPrint('Sync error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void setPendingItems(int count) {
    _pendingItems = count;
    notifyListeners();
  }

  Future<void> checkPendingItems() async {
    try {
      final syncService = SyncService();
      _pendingItems = await syncService.getPendingSalesCount();
      _erroredItems = await syncService.getErroredSalesCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking pending items: $e');
    }
  }

  void clearError() {
    _syncError = null;
    notifyListeners();
  }

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
