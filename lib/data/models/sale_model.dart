import 'package:cloud_firestore/cloud_firestore.dart';

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
  }
  return 0.0;
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

class SaleModel {

      // For compatibility with UI code expecting 'amount'
      double get amount => finalAmount;
    /// Returns a description for the sale, using notes if available, otherwise a summary of items.
    String? get description {
      if (notes != null && notes!.trim().isNotEmpty) {
        return notes;
      }
      if (items.isNotEmpty) {
        return items.map((e) => e.productName).join(', ');
      }
      return null;
    }
  final String id;
  final String businessId;
  final String? customerId;
  final String? customerName;
  final String? roomId;
  final String? guestId;
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
    this.roomId,
    this.guestId,
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
      businessId: (data['businessId'] ?? data['business_id'] ?? '').toString(),
      customerId: (data['customerId'] ?? data['customer_id'])?.toString(),
      customerName: (data['customerName'] ?? data['customer_name'])?.toString(),
      roomId: data['roomId'],
      guestId: data['guestId'],
      items: ((data['items'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => SaleItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      totalAmount:
          _readDouble(data['totalAmount'] ?? data['total_amount'] ?? data['total']),
      discountAmount: _readDouble(
          data['discountAmount'] ?? data['discount_amount'] ?? data['discount']),
      taxAmount: _readDouble(data['taxAmount'] ?? data['tax_amount'] ?? data['tax']),
      finalAmount: _readDouble(data['finalAmount'] ??
          data['final_amount'] ??
          data['totalAmount'] ??
          data['total_amount'] ??
          data['total']),
      paymentMethod:
          (data['paymentMethod'] ?? data['payment_method'] ?? 'cash').toString(),
      status: data['status'] ?? 'completed',
      receiptNumber: (data['receiptNumber'] ?? data['receipt_number'])?.toString(),
      notes: data['notes'],
      createdBy: (data['createdBy'] ?? data['created_by'] ?? '').toString(),
      createdAt: _readDate(data['createdAt'] ?? data['created_at']),
      updatedAt: data['updatedAt'] != null || data['updated_at'] != null
          ? _readDate(data['updatedAt'] ?? data['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'roomId': roomId,
      'guestId': guestId,
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
      'roomId': roomId,
      'guestId': guestId,
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
    String? roomId,
    String? guestId,
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
      roomId: roomId ?? this.roomId,
      guestId: guestId ?? this.guestId,
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
      productId: (json['productId'] ?? json['product_id'] ?? '').toString(),
      productName:
          (json['productName'] ?? json['product_name'] ?? json['name'] ?? '')
              .toString(),
      quantity: _readDouble(json['quantity'] ?? json['qty']),
      unitPrice: _readDouble(json['unitPrice'] ?? json['unit_price'] ?? json['price']),
      discount: _readDouble(json['discount']),
      total: _readDouble(json['total']),
      unit: (json['unit'] ?? json['saleUnit'] ?? json['sale_unit'])?.toString(),
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

