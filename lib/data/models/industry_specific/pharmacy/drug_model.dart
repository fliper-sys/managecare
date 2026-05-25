import 'package:cloud_firestore/cloud_firestore.dart';

class DrugModel {
  final String id;
  final String name;
  final String manufacturer;
  final String dosageForm;
  final String strength;
  final DateTime expiryDate;
  final int quantity; // inventory quantity
  final double price; // unit price
  final double costPrice; // buying price / unit cost
  final List<Map<String, dynamic>> prescriptions;

  DrugModel({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.dosageForm,
    required this.strength,
    required this.expiryDate,
    this.quantity = 0,
    this.price = 0.0,
    this.costPrice = 0.0,
    this.prescriptions = const [],
  });

  factory DrugModel.fromJson(Map<String, dynamic> json) {
    // quantity may be stored as 'quantity' or 'stock'
    final qtyRaw = json['quantity'] ?? json['stock'] ?? 0;
    int quantity = 0;
    if (qtyRaw is num) {
      quantity = qtyRaw.toInt();
    } else if (qtyRaw is String) {
      quantity = int.tryParse(qtyRaw) ?? 0;
    }

    // price may be stored as number or string under different keys
    final priceRaw = json['price'] ?? json['unitPrice'] ?? json['unit_price'] ?? 0.0;
    double price = 0.0;
    if (priceRaw is num) {
      price = priceRaw.toDouble();
    } else if (priceRaw is String) {
      final cleaned = priceRaw.replaceAll(RegExp(r'[^0-9\.-]'), '');
      price = double.tryParse(cleaned) ?? 0.0;
    }

    final costRaw = json['cost'] ??
        json['costPrice'] ??
        json['buyingPrice'] ??
        json['purchasePrice'] ??
        json['unitCost'] ??
        0.0;
    double costPrice = 0.0;
    if (costRaw is num) {
      costPrice = costRaw.toDouble();
    } else if (costRaw is String) {
      final cleaned = costRaw.replaceAll(RegExp(r'[^0-9\.-]'), '');
      costPrice = double.tryParse(cleaned) ?? 0.0;
    }

    // manufacturer may be stored as 'manufacturer' or 'batch' in different schemas
    final manufacturer = (json['manufacturer'] as String?) ?? (json['batch'] as String?) ?? '';

    final rawPrescriptions =
        json['prescriptions'] ?? json['prescriptionRules'] ?? const [];
    final prescriptions = <Map<String, dynamic>>[];
    if (rawPrescriptions is List) {
      for (final entry in rawPrescriptions) {
        if (entry is Map<String, dynamic>) {
          prescriptions.add(Map<String, dynamic>.from(entry));
        } else if (entry is Map) {
          prescriptions.add(Map<String, dynamic>.from(entry));
        }
      }
    }

    // expiry can be a Firestore Timestamp, DateTime, int (ms), or ISO string
    DateTime expiry = DateTime.now();
    final rawExpiry = json['expiryDate'] ?? json['expiry'] ?? json['expiry_date'];
    if (rawExpiry != null) {
      if (rawExpiry is Timestamp) {
        expiry = rawExpiry.toDate();
      } else if (rawExpiry is DateTime) {
        expiry = rawExpiry;
      } else if (rawExpiry is num) {
        expiry = DateTime.fromMillisecondsSinceEpoch(rawExpiry.toInt());
      } else if (rawExpiry is String) {
        expiry = DateTime.tryParse(rawExpiry) ?? DateTime.now();
      }
    }

    return DrugModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      manufacturer: manufacturer,
      dosageForm: json['dosageForm'] as String? ?? json['form'] as String? ?? '',
      strength: json['strength'] as String? ?? '',
      expiryDate: expiry,
      quantity: quantity,
      price: price,
      costPrice: costPrice,
      prescriptions: prescriptions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manufacturer': manufacturer,
        'dosageForm': dosageForm,
        'strength': strength,
        'expiryDate': expiryDate.toIso8601String(),
        'quantity': quantity,
        'price': price,
        'cost': costPrice,
        'costPrice': costPrice,
        'prescriptions': prescriptions,
      };
}

