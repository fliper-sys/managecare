import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/batch_operation_model.dart';

/// Service for executing batch operations with Firestore batch writes
class BatchOperationsService {
  final FirebaseFirestore _firestore;
  static const int BATCH_WRITE_LIMIT = 500; // Firestore batch write limit

  BatchOperationsService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Execute batch price update operation
  Future<bool> executePriceUpdate({
    required String businessId,
    required String operationId,
    required List<String> productIds,
    required double newPrice,
    double? discountPercentage,
    void Function(int, int)? onProgress,
  }) async {
    try {
      print('[BatchOperationsService] ▶ Executing price update: $operationId');
      print('[BatchOperationsService] Updating ${productIds.length} products');

      int totalBatches = (productIds.length / BATCH_WRITE_LIMIT).ceil();
      int totalProcessed = 0;

      // Process in batches
      for (int i = 0; i < totalBatches; i++) {
        final start = i * BATCH_WRITE_LIMIT;
        final end = (i + 1) * BATCH_WRITE_LIMIT;
        final batchProductIds = productIds.sublist(
            start, end > productIds.length ? productIds.length : end);

        // Execute batch write
        final batch = _firestore.batch();

        for (final productId in batchProductIds) {
          final productRef = _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('inventory')
              .doc(productId);

          batch.update(productRef, {
            'price': newPrice,
            if (discountPercentage != null)
              'discountPercentage': discountPercentage,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        totalProcessed += batchProductIds.length;

        print(
            '[BatchOperationsService] ✓ Batch ${i + 1}/$totalBatches processed ($totalProcessed/${productIds.length})');
        onProgress?.call(totalProcessed, productIds.length);
      }

      // Update operation status
      await _updateOperationStatus(
        businessId,
        operationId,
        BatchOperationStatus.completed,
        processedCount: totalProcessed,
      );

      print('[BatchOperationsService] ✓ Price update completed successfully');
      return true;
    } catch (e) {
      print('[BatchOperationsService] ✗ Error executing price update: $e');
      await _updateOperationStatus(
        businessId,
        operationId,
        BatchOperationStatus.failed,
        errorDetails: e.toString(),
      );
      return false;
    }
  }

  /// Execute batch inventory update operation
  Future<bool> executeBulkInventoryUpdate({
    required String businessId,
    required String operationId,
    required Map<String, int> productIdToQuantity,
    required String operation, // 'add', 'set', 'subtract'
    void Function(int, int)? onProgress,
  }) async {
    try {
      print(
          '[BatchOperationsService] ▶ Executing inventory update: $operationId');
      print(
          '[BatchOperationsService] Updating ${productIdToQuantity.length} products with operation: $operation');

      final productIds = productIdToQuantity.keys.toList();
      int totalBatches = (productIds.length / BATCH_WRITE_LIMIT).ceil();
      int totalProcessed = 0;

      // Process in batches
      for (int i = 0; i < totalBatches; i++) {
        final start = i * BATCH_WRITE_LIMIT;
        final end = (i + 1) * BATCH_WRITE_LIMIT;
        final batchProductIds = productIds.sublist(
            start, end > productIds.length ? productIds.length : end);

        final batch = _firestore.batch();

        for (final productId in batchProductIds) {
          final productRef = _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('inventory')
              .doc(productId);

          final quantity = productIdToQuantity[productId] ?? 0;

          switch (operation) {
            case 'add':
              batch.update(productRef, {
                'quantity': FieldValue.increment(quantity),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              break;
            case 'set':
              batch.update(productRef, {
                'quantity': quantity,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              break;
            case 'subtract':
              batch.update(productRef, {
                'quantity': FieldValue.increment(-quantity),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              break;
          }
        }

        await batch.commit();
        totalProcessed += batchProductIds.length;

        print(
            '[BatchOperationsService] ✓ Batch ${i + 1}/$totalBatches processed ($totalProcessed/${productIds.length})');
        onProgress?.call(totalProcessed, productIds.length);
      }

      await _updateOperationStatus(
        businessId,
        operationId,
        BatchOperationStatus.completed,
        processedCount: totalProcessed,
      );

      print(
          '[BatchOperationsService] ✓ Inventory update completed successfully');
      return true;
    } catch (e) {
      print('[BatchOperationsService] ✗ Error executing inventory update: $e');
      await _updateOperationStatus(
        businessId,
        operationId,
        BatchOperationStatus.failed,
        errorDetails: e.toString(),
      );
      return false;
    }
  }

  /// Execute batch customer data update
  Future<bool> executeBulkCustomerUpdate({
    required String businessId,
    required String operationId,
    required Map<String, Map<String, dynamic>> customerUpdates,
    void Function(int, int)? onProgress,
  }) async {
    try {
      print(
          '[BatchOperationsService] ▶ Executing customer data update: $operationId');
      print(
          '[BatchOperationsService] Updating ${customerUpdates.length} customers');

      final customerIds = customerUpdates.keys.toList();
      int totalBatches = (customerIds.length / BATCH_WRITE_LIMIT).ceil();
      int totalProcessed = 0;

      // Process in batches
      for (int i = 0; i < totalBatches; i++) {
        final start = i * BATCH_WRITE_LIMIT;
        final end = (i + 1) * BATCH_WRITE_LIMIT;
        final batchCustomerIds = customerIds.sublist(
            start, end > customerIds.length ? customerIds.length : end);

        final batch = _firestore.batch();

        for (final customerId in batchCustomerIds) {
          final customerRef = _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('customers')
              .doc(customerId);

          final updateData = customerUpdates[customerId] ?? {};
          updateData['updatedAt'] = DateTime.now().toIso8601String();

          batch.update(customerRef, updateData);
        }

        await batch.commit();
        totalProcessed += batchCustomerIds.length;

        print(
            '[BatchOperationsService] ✓ Batch ${i + 1}/$totalBatches processed ($totalProcessed/${customerIds.length})');
        onProgress?.call(totalProcessed, customerIds.length);
      }

      await _updateOperationStatus(
        businessId,
        operationId,
        BatchOperationStatus.completed,
        processedCount: totalProcessed,
      );

      print(
          '[BatchOperationsService] ✓ Customer data update completed successfully');
      return true;
    } catch (e) {
      print('[BatchOperationsService] ✗ Error executing customer update: $e');
      await _updateOperationStatus(
        businessId,
        operationId,
        BatchOperationStatus.failed,
        errorDetails: e.toString(),
      );
      return false;
    }
  }

  /// Update batch operation status
  Future<void> _updateOperationStatus(
    String businessId,
    String operationId,
    BatchOperationStatus status, {
    int? processedCount,
    String? errorDetails,
  }) async {
    try {
      final updateData = {
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (processedCount != null) {
        updateData['processed'] = processedCount.toString();
      }

      if (errorDetails != null) {
        updateData['errorDetails'] = errorDetails;
      }

      if (status == BatchOperationStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('batch_operations')
          .doc(operationId)
          .update(updateData);

      print('[BatchOperationsService] ✓ Operation status updated: $status');
    } catch (e) {
      print('[BatchOperationsService] ✗ Error updating operation status: $e');
    }
  }

  /// Get operation details
  Future<BatchOperation?> getOperationDetails(
    String businessId,
    String operationId,
  ) async {
    try {
      final doc = await _firestore
          .collection('batch_operations')
          .doc(operationId)
          .get();

      if (!doc.exists) return null;

      return BatchOperation.fromJson(
          {...doc.data() as Map<String, dynamic>, 'id': doc.id});
    } catch (e) {
      print('[BatchOperationsService] ✗ Error getting operation details: $e');
      return null;
    }
  }

  /// Stream operation progress
  Stream<BatchOperation?> streamOperationProgress(String operationId) {
    return _firestore
        .collection('batch_operations')
        .doc(operationId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return BatchOperation.fromJson(
          {...doc.data() as Map<String, dynamic>, 'id': doc.id});
    }).handleError((e) {
      print('[BatchOperationsService] ✗ Stream error: $e');
    });
  }

  /// Cancel batch operation
  Future<bool> cancelOperation(
    String businessId,
    String operationId,
  ) async {
    try {
      print('[BatchOperationsService] ▶ Cancelling operation: $operationId');

      await _firestore.collection('batch_operations').doc(operationId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('[BatchOperationsService] ✓ Operation cancelled successfully');
      return true;
    } catch (e) {
      print('[BatchOperationsService] ✗ Error cancelling operation: $e');
      return false;
    }
  }

  /// Retry failed operation
  Future<bool> retryOperation(
    String businessId,
    String operationId,
  ) async {
    try {
      print('[BatchOperationsService] ▶ Retrying operation: $operationId');

      final operation = await getOperationDetails(businessId, operationId);
      if (operation == null) {
        print('[BatchOperationsService] ✗ Operation not found');
        return false;
      }

      // Reset operation status
      await _firestore.collection('batch_operations').doc(operationId).update({
        'status': 'processing',
        'processedProducts': 0,
        'errorDetails': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Re-execute based on operation type
      switch (operation.type) {
        case BatchOperationType.priceUpdate:
          return await executePriceUpdate(
            businessId: businessId,
            operationId: operationId,
            productIds: operation.targetProductIds,
            newPrice: operation.operationData['newPrice'] ?? 0.0,
            discountPercentage: operation.operationData['discountPercentage'],
          );
        case BatchOperationType.stockUpdate:
          // Parse inventory update data
          return await executeBulkInventoryUpdate(
            businessId: businessId,
            operationId: operationId,
            productIdToQuantity:
                Map.from(operation.operationData['quantities'] ?? {}),
            operation: operation.operationData['operation'] ?? 'set',
          );
        case BatchOperationType.deleteProducts:
          return await executeBulkCustomerUpdate(
            businessId: businessId,
            operationId: operationId,
            customerUpdates: Map.from(operation.operationData['updates'] ?? {}),
          );
        default:
          print('[BatchOperationsService] ✗ Unknown operation type');
          return false;
      }
    } catch (e) {
      print('[BatchOperationsService] ✗ Error retrying operation: $e');
      return false;
    }
  }
}

