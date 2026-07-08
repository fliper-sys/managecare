import 'package:cloud_firestore/cloud_firestore.dart';

class DistributorRepository {
  final FirebaseFirestore? _firestore;

  DistributorRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _effectiveFirestore => _firestore ?? FirebaseFirestore.instance;

  Future<void> recordDistributorSale({
    required String businessId,
    required String distributorId,
    required String distributorName,
    required String productId,
    required String productName,
    required num quantity,
    required num unitPrice,
    num discountPercent = 0,
    String? salesRepId,
    String? salesRepName,
    String? notes,
  }) async {
    if (businessId.isEmpty || distributorId.isEmpty || productId.isEmpty) {
      throw Exception('businessId, distributorId, and productId are required');
    }
    if (quantity <= 0) {
      throw Exception('quantity must be greater than zero');
    }

    final itemRef = _effectiveFirestore.collection('businesses').doc(businessId).collection('inventory').doc(productId);
    final saleRef = _effectiveFirestore.collection('businesses').doc(businessId).collection('distributor_sales').doc();
    final businessSaleRef = _effectiveFirestore.collection('businesses').doc(businessId).collection('sales').doc(saleRef.id);
    final distributorRef = _effectiveFirestore.collection('businesses').doc(businessId).collection('distributors').doc(distributorId);
    final historyRef = itemRef.collection('history').doc();
    final discountPercentValue = discountPercent.toDouble();
    final discountedUnitPrice = unitPrice.toDouble() * (1 - (discountPercentValue / 100));
    final totalAmount = discountedUnitPrice * quantity.toDouble();

    final itemEntry = {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discountPercent': discountPercentValue,
      'discountedUnitPrice': discountedUnitPrice,
      'totalAmount': totalAmount,
    };

    await _effectiveFirestore.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      final itemData = itemSnap.data() as Map<String, dynamic>? ?? {};
      final currentQuantity = ((itemData['quantity'] as num?) ?? (itemData['stock'] as num?) ?? 0).toDouble();
      final updatedQuantity = currentQuantity - quantity.toDouble();

      if (updatedQuantity < 0) {
        throw Exception('Insufficient stock for distributor sale');
      }

      tx.set(
        itemRef,
        {
          'quantity': updatedQuantity,
          'stock': updatedQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final salePayload = {
        'id': saleRef.id,
        'businessId': businessId,
        'saleType': 'distributor',
        'distributorId': distributorId,
        'distributorName': distributorName,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountPercent': discountPercentValue,
        'discountedUnitPrice': discountedUnitPrice,
        'totalAmount': totalAmount,
        'items': [itemEntry],
        'salesRepId': salesRepId ?? '',
        'salesRepName': salesRepName ?? '',
        'notes': notes ?? '',
        'status': 'completed',
        'paymentMethod': 'distributor',
        'createdAt': FieldValue.serverTimestamp(),
      };

      tx.set(saleRef, salePayload);
      tx.set(businessSaleRef, salePayload);
      tx.set(distributorRef.collection('sales').doc(saleRef.id), salePayload);
      tx.set(historyRef, {
        'action': 'distributor_sale',
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountPercent': discountPercentValue,
        'discountedUnitPrice': discountedUnitPrice,
        'totalAmount': totalAmount,
        'distributorId': distributorId,
        'distributorName': distributorName,
        'salesRepId': salesRepId ?? '',
        'salesRepName': salesRepName ?? '',
        'notes': notes ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<Map<String, dynamic>>> getDistributors(String businessId) async {
    if (businessId.isEmpty) return [];
    final snapshot = await _effectiveFirestore.collection('businesses').doc(businessId).collection('distributors').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<String> addDistributor({
    required String businessId,
    required String name,
    String? contactPerson,
    String? phone,
    String? notes,
  }) async {
    if (businessId.isEmpty || name.trim().isEmpty) {
      throw Exception('businessId and name are required');
    }

    final docRef = await _effectiveFirestore.collection('businesses').doc(businessId).collection('distributors').add({
      'name': name.trim(),
      'contactPerson': contactPerson ?? '',
      'phone': phone ?? '',
      'notes': notes ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }
}
