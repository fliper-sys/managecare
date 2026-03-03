import 'package:cloud_firestore/cloud_firestore.dart';

enum BatchOperationType {
  priceUpdate,
  stockUpdate,
  categoryUpdate,
  discountApply,
  statusUpdate,
  deleteProducts,
}

enum BatchOperationStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

class BatchOperation {
  final String id;
  final String businessId;
  final BatchOperationType type;
  final BatchOperationStatus status;
  final List<String> targetProductIds;
  final Map<String, dynamic> operationData;
  final int totalProducts;
  final int processedProducts;
  final String? description;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  BatchOperation({
    required this.id,
    required this.businessId,
    required this.type,
    required this.status,
    required this.targetProductIds,
    required this.operationData,
    required this.totalProducts,
    required this.processedProducts,
    this.description,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    required this.updatedAt,
  });

  factory BatchOperation.fromJson(Map<String, dynamic> json) {
    return BatchOperation(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      type: BatchOperationType.values.firstWhere(
        (t) => t.toString() == 'BatchOperationType.${json['type']}',
        orElse: () => BatchOperationType.priceUpdate,
      ),
      status: BatchOperationStatus.values.firstWhere(
        (s) => s.toString() == 'BatchOperationStatus.${json['status']}',
        orElse: () => BatchOperationStatus.pending,
      ),
      targetProductIds:
          List<String>.from(json['targetProductIds'] as List? ?? []),
      operationData: json['operationData'] as Map<String, dynamic>? ?? {},
      totalProducts: json['totalProducts'] as int? ?? 0,
      processedProducts: json['processedProducts'] as int? ?? 0,
      description: json['description'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: json['completedAt'] is Timestamp
          ? (json['completedAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'targetProductIds': targetProductIds,
      'operationData': operationData,
      'totalProducts': totalProducts,
      'processedProducts': processedProducts,
      'description': description,
      'errorMessage': errorMessage,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BatchOperation copyWith({
    String? id,
    String? businessId,
    BatchOperationType? type,
    BatchOperationStatus? status,
    List<String>? targetProductIds,
    Map<String, dynamic>? operationData,
    int? totalProducts,
    int? processedProducts,
    String? description,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return BatchOperation(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      type: type ?? this.type,
      status: status ?? this.status,
      targetProductIds: targetProductIds ?? this.targetProductIds,
      operationData: operationData ?? this.operationData,
      totalProducts: totalProducts ?? this.totalProducts,
      processedProducts: processedProducts ?? this.processedProducts,
      description: description ?? this.description,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get progressPercentage {
    if (totalProducts == 0) return 0;
    return ((processedProducts / totalProducts) * 100).toInt();
  }

  bool get isCompleted =>
      status == BatchOperationStatus.completed ||
      status == BatchOperationStatus.failed ||
      status == BatchOperationStatus.cancelled;

  bool get isProcessing => status == BatchOperationStatus.processing;

  String getTypeLabel() {
    switch (type) {
      case BatchOperationType.priceUpdate:
        return 'Price Update';
      case BatchOperationType.stockUpdate:
        return 'Stock Update';
      case BatchOperationType.categoryUpdate:
        return 'Category Update';
      case BatchOperationType.discountApply:
        return 'Apply Discount';
      case BatchOperationType.statusUpdate:
        return 'Status Update';
      case BatchOperationType.deleteProducts:
        return 'Delete Products';
    }
  }

  String getStatusLabel() {
    switch (status) {
      case BatchOperationStatus.pending:
        return 'Pending';
      case BatchOperationStatus.processing:
        return 'Processing';
      case BatchOperationStatus.completed:
        return 'Completed';
      case BatchOperationStatus.failed:
        return 'Failed';
      case BatchOperationStatus.cancelled:
        return 'Cancelled';
    }
  }
}

