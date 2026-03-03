import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String id;
  final String businessId;
  final String? customerId;
  final String? customerName;
  final List<SaleItem> items;
  final double totalAmount;
  final double discountAmount;
  final double taxAmount;
  final double finalAmount;
  final String paymentMethod; // cash, card, mobile, bank_transfer
  final String status; // completed, pending, cancelled, refunded
  final String? receiptNumber;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SaleModel({
    required this.id,
    required this.businessId,
    this.customerId,
    this.customerName,
    required this.items,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    required this.finalAmount,
    required this.paymentMethod,
    this.status = 'completed',
    this.receiptNumber,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory SaleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SaleModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      customerId: data['customerId'],
      customerName: data['customerName'],
      items: (data['items'] as List<dynamic>)
          .map((item) => SaleItem.fromJson(item))
          .toList(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      discountAmount: (data['discountAmount'] ?? 0).toDouble(),
      taxAmount: (data['taxAmount'] ?? 0).toDouble(),
      finalAmount: (data['finalAmount'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      status: data['status'] ?? 'completed',
      receiptNumber: data['receiptNumber'],
      notes: data['notes'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'receiptNumber': receiptNumber,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'receiptNumber': receiptNumber,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  SaleModel copyWith({
    String? id,
    String? businessId,
    String? customerId,
    String? customerName,
    List<SaleItem>? items,
    double? totalAmount,
    double? discountAmount,
    double? taxAmount,
    double? finalAmount,
    String? paymentMethod,
    String? status,
    String? receiptNumber,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SaleItem {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double total;
  final String? unit;

  SaleItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
    required this.total,
    this.unit,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      unit: json['unit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'total': total,
      'unit': unit,
    };
  }
}

