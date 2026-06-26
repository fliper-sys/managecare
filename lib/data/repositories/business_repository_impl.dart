import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';

class BusinessRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'businesses';

  BusinessRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<BusinessModel?> getBusinessById(String id) async {
    try {
      print(
          '[BusinessRepositoryImpl.getBusinessById] Fetching business with ID: $id');

      // Try direct doc lookup with a couple of short retries to handle eventual consistency
      DocumentSnapshot? doc;
      const retries = 3;
      for (var attempt = 0; attempt < retries; attempt++) {
        doc = await _firestore.collection(_collection).doc(id).get();
        if (doc.exists) break;
        // small delay before retrying
        await Future.delayed(const Duration(milliseconds: 250));
      }

      if (doc != null && doc.exists) {
        final business = BusinessModel.fromFirestore(doc);
        print(
            '[BusinessRepositoryImpl.getBusinessById] Found business by doc id: ${business.name}');
        return business;
      }

      print(
          '[BusinessRepositoryImpl.getBusinessById] Business document does NOT exist for ID: $id; attempting fallback queries');

      // Fallback queries: some imports or legacy imports stored the business id in fields
      final fallbackFields = ['id', 'externalId', 'legacyId', 'code', 'businessCode'];
      for (final field in fallbackFields) {
        try {
          final q = await _firestore
              .collection(_collection)
              .where(field, isEqualTo: id)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            final foundDoc = q.docs.first;
            final business = BusinessModel.fromFirestore(foundDoc);
            print(
                '[BusinessRepositoryImpl.getBusinessById] Found business by field "$field": ${business.name} (doc ${foundDoc.id})');
            return business;
          }
        } catch (e) {
          // ignore per-field errors and continue
          print('[BusinessRepositoryImpl.getBusinessById] fallback query error for field $field: $e');
        }
      }

      // No business found via fallback
      print(
          '[BusinessRepositoryImpl.getBusinessById] No business found for ID via doc or fallback fields: $id');
      return null;
    } catch (e) {
      print('[BusinessRepositoryImpl.getBusinessById] ERROR: $e');
      throw Exception('Failed to get business: $e');
    }
  }

  Future<List<BusinessModel>> getUserBusinesses(String userId) async {
    try {
      print(
          '[BusinessRepositoryImpl.getUserBusinesses] Fetching businesses for user: $userId');

      // First, verify the collection exists and check for any documents
      final allDocs = await _firestore.collection(_collection).limit(5).get();
      print(
          '[BusinessRepositoryImpl.getUserBusinesses] Collection "$_collection" has ${allDocs.docs.length} total documents (checking first 5)');

      if (allDocs.docs.isNotEmpty) {
        print(
            '[BusinessRepositoryImpl.getUserBusinesses] Sample documents in collection:');
        for (final doc in allDocs.docs.take(3)) {
          final data = doc.data();
          print(
              '[BusinessRepositoryImpl.getUserBusinesses]   - Doc ${doc.id}: ownerId=${data['ownerId']}, name=${data['name']}');
        }
      }

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('ownerId', isEqualTo: userId)
          // Note: removed isActive filter to avoid composite index requirement
          // Note: orderBy removed to avoid requiring a composite index
          // Filtering and sorting are done client-side after retrieval
          .get();

      print(
          '[BusinessRepositoryImpl.getUserBusinesses] Query for ownerId="$userId" returned ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isEmpty) {
        print(
            '[BusinessRepositoryImpl.getUserBusinesses] No businesses found for user $userId');
        print(
            '[BusinessRepositoryImpl.getUserBusinesses] This is expected if the user has not created any businesses yet');
        print(
            '[BusinessRepositoryImpl.getUserBusinesses] User needs to create their first business via the Create Business button');
        return [];
      }

      final businesses = <BusinessModel>[];
      for (final doc in querySnapshot.docs) {
        try {
          print(
              '[BusinessRepositoryImpl.getUserBusinesses] Processing document: ${doc.id}');
          final b = BusinessModel.fromFirestore(doc);
          if (b.isActive) businesses.add(b);
        } catch (e, st) {
          // Don't fail the whole load because a single doc is malformed. Log and continue.
          print('[BusinessRepositoryImpl.getUserBusinesses] Skipping doc ${doc.id} due to parse error: $e');
          print(st);
          continue;
        }
      }

      print(
          '[BusinessRepositoryImpl.getUserBusinesses] After filtering by isActive: ${businesses.length} businesses (some docs may have been skipped due to parse errors)');

      // Sort by createdAt descending on client side
      businesses.sort((a, b) {
        final aTime = a.createdAt.millisecondsSinceEpoch;
        final bTime = b.createdAt.millisecondsSinceEpoch;
        return bTime.compareTo(aTime); // Descending order
      });

      return businesses;
    } catch (e) {
      print('[BusinessRepositoryImpl.getUserBusinesses] ERROR: $e');
      rethrow;
    }
  }

  Future<void> createBusiness(BusinessModel business) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(business.id)
          .set(business.toFirestore());
    } catch (e) {
      throw Exception('Failed to create business: $e');
    }
  }

  /// Create default fuel products (Petrol, Diesel, Kerosene) for a gas business.
  /// This will only create docs if they don't already exist.
  Future<void> createDefaultFuelProducts(String businessId, {String fuelUnit = 'L'}) async {
    try {
      final inventoryRef = _firestore.collection(_collection).doc(businessId).collection('inventory');

      final defaultProducts = [
        {
          'id': 'petrol',
          'name': 'Petrol',
          'price': 200.0,
          'cost': 0.0,
          'quantity': 0,
          'category': 'Fuel',
          'unit': fuelUnit,
          'emoji': '⛽',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'diesel',
          'name': 'Diesel',
          'price': 180.0,
          'cost': 0.0,
          'quantity': 0,
          'category': 'Fuel',
          'unit': fuelUnit,
          'emoji': '🛢️',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'kerosene',
          'name': 'Kerosene',
          'price': 150.0,
          'cost': 0.0,
          'quantity': 0,
          'category': 'Fuel',
          'unit': fuelUnit,
          'emoji': '🔥',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'cooking_gas',
          'name': 'Cooking Gas (LPG)',
          'price': 12000.0,
          'cost': 0.0,
          'quantity': 0,
          'category': 'Fuel',
          'unit': 'cyl',
          'emoji': '🧯',
          'createdAt': FieldValue.serverTimestamp(),
        }
      ];

      final batch = _firestore.batch();
      var hasWrites = false;

      for (final p in defaultProducts) {
        final docRef = inventoryRef.doc(p['id'] as String);
        final snapshot = await docRef.get();
        if (!snapshot.exists) {
          final data = Map<String, dynamic>.from(p);
          data.remove('id');
          batch.set(docRef, data);
          hasWrites = true;
        }
      }

      // Commit only if we added operations
      if (hasWrites) {
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to create default fuel products: $e');
    }
  }

  /// Create starter bakery products so a bakery can begin selling immediately.
  Future<void> createDefaultBakeryProducts(String businessId) async {
    try {
      final inventoryRef =
          _firestore.collection(_collection).doc(businessId).collection('inventory');

      final defaultProducts = [
        {
          'id': 'bread_loaf',
          'name': 'Bread Loaf',
          'price': 1000.0,
          'cost': 0.0,
          'quantity': 0,
          'category': 'Bakery',
          'unit': 'pcs',
          'emoji': 'bread',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'meat_pie',
          'name': 'Meat Pie',
          'price': 800.0,
          'cost': 0.0,
          'quantity': 0,
          'category': 'Pastry',
          'unit': 'pcs',
          'emoji': 'pie',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'cupcake',
          'name': 'Cupcake',
          'price': 500.0,
          'cost': 0.0,
          'quantity': 0,
          'category': 'Cake',
          'unit': 'pcs',
          'emoji': 'cake',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'small_chops_pack',
          'name': 'Small Chops Pack',
          'price': 1500.0,
          'cost': 0.0,
          'quantity': 0,
          'category': 'Snacks',
          'unit': 'pack',
          'emoji': 'snack',
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      final batch = _firestore.batch();
      var hasWrites = false;

      for (final p in defaultProducts) {
        final docRef = inventoryRef.doc(p['id'] as String);
        final snapshot = await docRef.get();
        if (!snapshot.exists) {
          final data = Map<String, dynamic>.from(p);
          data.remove('id');
          batch.set(docRef, data);
          hasWrites = true;
        }
      }

      if (hasWrites) {
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to create default bakery products: $e');
    }
  }

  Future<void> updateBusiness(BusinessModel business) async {
    try {
      await _firestore.collection(_collection).doc(business.id).update({
        ...business.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update business: $e');
    }
  }

  Future<void> deleteBusiness(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete business: $e');
    }
  }

  Stream<BusinessModel?> businessStream(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? BusinessModel.fromFirestore(doc) : null);
  }

  Future<void> updateBusinessStats({
    required String businessId,
    int? totalWorkers,
    int? totalProducts,
    int? totalCustomers,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (totalWorkers != null) updates['totalWorkers'] = totalWorkers;
      if (totalProducts != null) updates['totalProducts'] = totalProducts;
      if (totalCustomers != null) updates['totalCustomers'] = totalCustomers;

      await _firestore.collection(_collection).doc(businessId).update(updates);
    } catch (e) {
      throw Exception('Failed to update business stats: $e');
    }
  }

  Future<void> updateSubscription({
    required String businessId,
    required String tier,
    required DateTime startDate,
    required DateTime endDate,
    bool isActive = true,
  }) async {
    try {
      await _firestore.collection(_collection).doc(businessId).update({
        'subscriptionTier': tier,
        'subscriptionStartDate': Timestamp.fromDate(startDate),
        'subscriptionEndDate': Timestamp.fromDate(endDate),
        'isSubscriptionActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update subscription: $e');
    }
  }

  Future<List<BusinessModel>> getBusinessesByType(String businessType) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('businessType', isEqualTo: businessType)
          .where('isActive', isEqualTo: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get businesses by type: $e');
    }
  }

  Future<int> getBusinessCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get business count: $e');
    }
  }
}

