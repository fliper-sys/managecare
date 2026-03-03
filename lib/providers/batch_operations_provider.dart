import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/batch_operation_model.dart';
import '../services/batch_operations_service.dart';

class BatchOperationsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final BatchOperationsService _batchService;
  final String _collectionName = 'batch_operations';

  List<BatchOperation> _operations = [];
  BatchOperation? _currentOperation;
  bool _isLoading = false;
  String? _error;
  String? _businessId;
  int _currentProgress = 0;
  int _totalItems = 0;

  // Getters
  List<BatchOperation> get operations => _operations;
  List<BatchOperation> get pendingOperations => _operations
      .where((op) => op.status == BatchOperationStatus.pending)
      .toList();
  List<BatchOperation> get processingOperations => _operations
      .where((op) => op.status == BatchOperationStatus.processing)
      .toList();
  List<BatchOperation> get completedOperations =>
      _operations.where((op) => op.isCompleted).toList();
  BatchOperation? get currentOperation => _currentOperation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentProgress => _currentProgress;
  int get totalItems => _totalItems;
  double get progressPercentage =>
      _totalItems > 0 ? (_currentProgress / _totalItems) * 100 : 0;

  BatchOperationsProvider() {
    _batchService = BatchOperationsService(firestore: _firestore);
  }

  /// Initialize with business ID
  void initialize(String businessId) {
    _businessId = businessId;
    print(
        '[BatchOperationsProvider] ▶ Initializing with business: $businessId');
    loadOperations();
  }

  /// Load all operations for business
  Future<void> loadOperations() async {
    if (_businessId == null) return;

    try {
      print('[BatchOperationsProvider] ▶ Loading batch operations');
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection(_collectionName)
          .where('businessId', isEqualTo: _businessId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _operations = snapshot.docs
          .map((doc) => BatchOperation.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      _isLoading = false;
      _error = null;
      print(
          '[BatchOperationsProvider] ✓ Loaded ${_operations.length} operations');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load operations: $e';
      _isLoading = false;
      print('[BatchOperationsProvider] ✗ Error: $_error');
      notifyListeners();
    }
  }

  /// Execute price update via service
  Future<bool> executePriceUpdate({
    required List<String> productIds,
    required double newPrice,
    double? discountPercentage,
    String? description,
    Function(int, int)? onProgress,
  }) async {
    if (_businessId == null) return false;

    try {
      print(
          '[BatchOperationsProvider] ▶ Starting price update for ${productIds.length} items');

      _currentProgress = 0;
      _totalItems = productIds.length;
      _isLoading = true;
      notifyListeners();

      final success = await _batchService.executePriceUpdate(
        operationId: const Uuid().v4(),
        businessId: _businessId!,
        productIds: productIds,
        newPrice: newPrice,
        discountPercentage: discountPercentage,
        onProgress: (processed, total) {
          _currentProgress = processed;
          _totalItems = total;
          onProgress?.call(processed, total);
          notifyListeners();
        },
      );

      if (success) {
        print('[BatchOperationsProvider] ✓ Price update completed');
        await loadOperations();
      } else {
        print('[BatchOperationsProvider] ✗ Price update failed');
      }

      _isLoading = false;
      return success;
    } catch (e) {
      _error = 'Price update error: $e';
      _isLoading = false;
      print('[BatchOperationsProvider] ✗ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  /// Execute inventory update via service
  Future<bool> executeInventoryUpdate({
    required List<String> productIds,
    required Map<String, int> productIdToQuantity,
    String? description,
    Function(int, int)? onProgress,
  }) async {
    if (_businessId == null) return false;

    try {
      print(
          '[BatchOperationsProvider] ▶ Starting inventory update for ${productIds.length} items');

      _currentProgress = 0;
      _totalItems = productIds.length;
      _isLoading = true;
      notifyListeners();

      final operation = BatchOperation(
        id: const Uuid().v4(),
        businessId: _businessId!,
        type: BatchOperationType.stockUpdate,
        status: BatchOperationStatus.pending,
        targetProductIds: productIds,
        operationData: {},
        totalProducts: productIds.length,
        processedProducts: 0,
        description:
            description ?? 'Update inventory for ${productIds.length} products',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await _batchService.executeBulkInventoryUpdate(
        operationId: operation.id,
        businessId: _businessId!,
        productIdToQuantity: productIdToQuantity,
        operation: operation.id,
        onProgress: (processed, total) {
          _currentProgress = processed;
          _totalItems = total;
          onProgress?.call(processed, total);
          notifyListeners();
        },
      );

      if (success) {
        print('[BatchOperationsProvider] ✓ Inventory update completed');
        await loadOperations();
      } else {
        print('[BatchOperationsProvider] ✗ Inventory update failed');
      }

      _isLoading = false;
      return success;
    } catch (e) {
      _error = 'Inventory update error: $e';
      _isLoading = false;
      print('[BatchOperationsProvider] ✗ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  /// Execute customer data bulk update via service
  Future<bool> executeCustomerUpdate({
    required List<String> customerIds,
    required Map<String, Map<String, dynamic>> customerUpdates,
    String? description,
    Function(int, int)? onProgress,
  }) async {
    if (_businessId == null) return false;

    try {
      print(
          '[BatchOperationsProvider] ▶ Starting customer update for ${customerIds.length} items');

      _currentProgress = 0;
      _totalItems = customerIds.length;
      _isLoading = true;
      notifyListeners();

      final success = await _batchService.executeBulkCustomerUpdate(
        operationId: const Uuid().v4(),
        businessId: _businessId!,
        customerUpdates: customerUpdates,
        onProgress: (processed, total) {
          _currentProgress = processed;
          _totalItems = total;
          onProgress?.call(processed, total);
          notifyListeners();
        },
      );

      if (success) {
        print('[BatchOperationsProvider] ✓ Customer update completed');
        await loadOperations();
      } else {
        print('[BatchOperationsProvider] ✗ Customer update failed');
      }

      _isLoading = false;
      return success;
    } catch (e) {
      _error = 'Customer update error: $e';
      _isLoading = false;
      print('[BatchOperationsProvider] ✗ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  /// Stream operation progress
  Stream<Map<String, dynamic>> streamOperationProgress(String operationId) {
    return _batchService.streamOperationProgress(operationId).map((op) {
      if (op != null) {
        _currentProgress = op.processedProducts;
        _totalItems = op.totalProducts;
        notifyListeners();
        return {
          'processed': op.processedProducts,
          'total': op.totalProducts,
          'status': op.status.toString(),
        };
      }
      return {'processed': 0, 'total': 0};
    });
  }

  /// Retry failed operation
  Future<bool> retryOperation(String operationId) async {
    try {
      print('[BatchOperationsProvider] ▶ Retrying operation: $operationId');

      final operation = _operations.firstWhere((op) => op.id == operationId);
      if (operation.status != BatchOperationStatus.failed) {
        _error = 'Only failed operations can be retried';
        return false;
      }

      final success = await _batchService.retryOperation(
        operationId,
        _businessId!,
      );

      if (success) {
        print('[BatchOperationsProvider] ✓ Operation retry started');
        await loadOperations();
      }

      return success;
    } catch (e) {
      _error = 'Retry error: $e';
      print('[BatchOperationsProvider] ✗ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  /// Cancel operation
  Future<bool> cancelOperation(String operationId) async {
    try {
      print('[BatchOperationsProvider] ▶ Canceling operation: $operationId');

      final operation = _operations.firstWhere((op) => op.id == operationId);

      if (operation.isCompleted) {
        _error = 'Cannot cancel completed operation';
        notifyListeners();
        return false;
      }

      final cancelledOp = operation.copyWith(
        status: BatchOperationStatus.cancelled,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_collectionName)
          .doc(operationId)
          .update(cancelledOp.toJson());

      final index = _operations.indexWhere((op) => op.id == operationId);
      if (index != -1) {
        _operations[index] = cancelledOp;
      }

      print('[BatchOperationsProvider] ✓ Operation cancelled');
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Cancel error: $e';
      print('[BatchOperationsProvider] ✗ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  /// Get operation statistics
  Map<String, int> getOperationStats() {
    return {
      'total': _operations.length,
      'pending': pendingOperations.length,
      'processing': processingOperations.length,
      'completed': completedOperations.length,
      'failed': _operations
          .where((op) => op.status == BatchOperationStatus.failed)
          .length,
      'cancelled': _operations
          .where((op) => op.status == BatchOperationStatus.cancelled)
          .length,
    };
  }

  /// Clear completed operations
  Future<void> clearCompletedOperations() async {
    try {
      print('[BatchOperationsProvider] ▶ Clearing completed operations');

      for (final op in completedOperations) {
        await _firestore.collection(_collectionName).doc(op.id).delete();
      }

      _operations.removeWhere((op) => op.isCompleted);
      notifyListeners();

      print('[BatchOperationsProvider] ✓ Cleared completed operations');
    } catch (e) {
      _error = 'Clear error: $e';
      print('[BatchOperationsProvider] ✗ Error: $_error');
      notifyListeners();
    }
  }

  /// Clear all operations
  Future<void> clearAllOperations() async {
    try {
      print('[BatchOperationsProvider] ▶ Clearing all operations');

      for (final op in _operations) {
        await _firestore.collection(_collectionName).doc(op.id).delete();
      }

      _operations.clear();
      notifyListeners();

      print('[BatchOperationsProvider] ✓ Cleared all operations');
    } catch (e) {
      _error = 'Clear error: $e';
      print('[BatchOperationsProvider] ✗ Error: $_error');
      notifyListeners();
    }
  }

  /// Dispose
  @override
  void dispose() {
    _operations.clear();
    _currentOperation = null;
    super.dispose();
  }
}

