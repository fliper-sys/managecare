import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/loyalty_member_model.dart';
import '../data/models/loyalty_transaction_model.dart';

class LoyaltyService {
  final FirebaseFirestore _firestore;

  LoyaltyService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Get all loyalty members for a business
  Future<List<LoyaltyMember>> fetchLoyaltyMembers(String businessId) async {
    try {
      print(
          '[LoyaltyService] ▶ Fetching loyalty members for business: $businessId');

      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('loyalty_members')
          .orderBy('pointsBalance', descending: true)
          .get();

      final members = snapshot.docs
          .map((doc) => LoyaltyMember.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      print('[LoyaltyService] ✓ Loaded ${members.length} loyalty members');
      return members;
    } catch (e) {
      print('[LoyaltyService] ✗ Error fetching loyalty members: $e');
      return [];
    }
  }

  /// Get loyalty member by ID
  Future<LoyaltyMember?> fetchMemberDetails(
      String businessId, String memberId) async {
    try {
      print('[LoyaltyService] ▶ Fetching member details: $memberId');

      final doc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('loyalty_members')
          .doc(memberId)
          .get();

      if (!doc.exists) {
        print('[LoyaltyService] ✗ Member not found: $memberId');
        return null;
      }

      final member = LoyaltyMember.fromJson(
          {...doc.data() as Map<String, dynamic>, 'id': doc.id});
      print('[LoyaltyService] ✓ Loaded member: ${member.customerId}');
      return member;
    } catch (e) {
      print('[LoyaltyService] ✗ Error fetching member details: $e');
      return null;
    }
  }

  /// Stream loyalty members real-time
  Stream<List<LoyaltyMember>> streamLoyaltyMembers(String businessId) {
    print('[LoyaltyService] ▶ Starting loyalty members stream');

    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('loyalty_members')
        .orderBy('pointsBalance', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoyaltyMember.fromJson({...doc.data(), 'id': doc.id}))
            .toList())
        .handleError((e) {
      print('[LoyaltyService] ✗ Stream error: $e');
    });
  }

  /// Register a new customer for loyalty program
  Future<bool> registerCustomer({
    required String businessId,
    required String customerId,
    required String customerName,
    required String phoneNumber,
    String tier = 'bronze',
  }) async {
    try {
      print('[LoyaltyService] ▶ Registering customer for loyalty: $customerId');

      final member = LoyaltyMember(
        id: customerId,
        customerId: customerId,
        currentTier: tier,
        totalPoints: 0,
        availablePoints: 0,
        pointsUsed: 0,
        totalTransactions: 0,
        totalSpent: 0.0,
        joinedDate: DateTime.now(),
        lastTransactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('loyalty_members')
          .doc(customerId)
          .set(member.toJson());

      print('[LoyaltyService] ✓ Customer registered successfully');
      return true;
    } catch (e) {
      print('[LoyaltyService] ✗ Error registering customer: $e');
      return false;
    }
  }

  /// Update member points
  Future<bool> updateMemberPoints({
    required String businessId,
    required String memberId,
    required int pointsToAdd,
    required String description,
    String? relatedSaleId,
  }) async {
    try {
      print(
          '[LoyaltyService] ▶ Updating points for member: $memberId (+$pointsToAdd)');

      final batch = _firestore.batch();

      // Update member points
      final memberRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('loyalty_members')
          .doc(memberId);

      batch.update(memberRef, {
        'pointsBalance': FieldValue.increment(pointsToAdd),
        'totalPointsEarned': FieldValue.increment(pointsToAdd),
        'lastActivityDate': DateTime.now().toIso8601String(),
      });

      // Create transaction record
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
      final transactionRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('loyalty_transactions')
          .doc(transactionId);

      batch.set(transactionRef, {
        'memberId': memberId,
        'type': 'earn',
        'amount': pointsToAdd,
        'description': description,
        'relatedSaleId': relatedSaleId,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await batch.commit();
      print('[LoyaltyService] ✓ Points updated successfully');
      return true;
    } catch (e) {
      print('[LoyaltyService] ✗ Error updating points: $e');
      return false;
    }
  }

  /// Redeem rewards
  Future<bool> redeemRewards({
    required String businessId,
    required String memberId,
    required int pointsToRedeem,
    required String rewardDescription,
  }) async {
    try {
      print(
          '[LoyaltyService] ▶ Redeeming reward for member: $memberId (-$pointsToRedeem)');

      final batch = _firestore.batch();

      // Update member points
      final memberRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('loyalty_members')
          .doc(memberId);

      batch.update(memberRef, {
        'pointsBalance': FieldValue.increment(-pointsToRedeem),
        'lastActivityDate': DateTime.now().toIso8601String(),
      });

      // Create redemption transaction
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
      final transactionRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('loyalty_transactions')
          .doc(transactionId);

      batch.set(transactionRef, {
        'memberId': memberId,
        'type': 'redeem',
        'amount': pointsToRedeem,
        'description': rewardDescription,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await batch.commit();
      print('[LoyaltyService] ✓ Reward redeemed successfully');
      return true;
    } catch (e) {
      print('[LoyaltyService] ✗ Error redeeming reward: $e');
      return false;
    }
  }

  /// Get loyalty transactions for a member
  Future<List<LoyaltyTransaction>> fetchMemberTransactions(
    String businessId,
    String memberId,
  ) async {
    try {
      print('[LoyaltyService] ▶ Fetching transactions for member: $memberId');

      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('loyalty_transactions')
          .where('memberId', isEqualTo: memberId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final transactions = snapshot.docs
          .map((doc) =>
              LoyaltyTransaction.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      print('[LoyaltyService] ✓ Loaded ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      print('[LoyaltyService] ✗ Error fetching transactions: $e');
      return [];
    }
  }

  /// Calculate tier based on points
  String calculateTier(int totalPoints) {
    if (totalPoints >= 5000) return 'gold';
    if (totalPoints >= 2500) return 'silver';
    return 'bronze';
  }

  /// Get tier benefits
  Map<String, dynamic> getTierBenefits(String tier) {
    const benefits = {
      'bronze': {
        'name': 'Bronze',
        'minPoints': 0,
        'pointsMultiplier': 1.0,
        'discountPercentage': 0,
        'benefits': [
          '1 point per ₦100 spent',
          'Birthday bonus',
        ],
      },
      'silver': {
        'name': 'Silver',
        'minPoints': 2500,
        'pointsMultiplier': 1.5,
        'discountPercentage': 2,
        'benefits': [
          '1.5x points on purchases',
          '2% discount on all items',
          'Priority customer support',
          'Early access to sales',
        ],
      },
      'gold': {
        'name': 'Gold',
        'minPoints': 5000,
        'pointsMultiplier': 2.0,
        'discountPercentage': 5,
        'benefits': [
          '2x points on purchases',
          '5% discount on all items',
          'VIP customer support',
          'Exclusive member-only events',
          'Free shipping on online orders',
        ],
      },
    };

    return benefits[tier] ?? benefits['bronze']!;
  }

  /// Search members by name or phone
  Future<List<LoyaltyMember>> searchMembers(
    String businessId,
    String query,
  ) async {
    try {
      print('[LoyaltyService] ▶ Searching members: $query');

      final allMembers = await fetchLoyaltyMembers(businessId);
      final filtered = allMembers
          .where((member) =>
              member.customerId.toLowerCase().contains(query.toLowerCase()))
          .toList();

      print('[LoyaltyService] ✓ Found ${filtered.length} matching members');
      return filtered;
    } catch (e) {
      print('[LoyaltyService] ✗ Error searching members: $e');
      return [];
    }
  }

  /// Get loyalty statistics
  Future<Map<String, dynamic>> getLoyaltyStats(String businessId) async {
    try {
      print('[LoyaltyService] ▶ Calculating loyalty statistics');

      final members = await fetchLoyaltyMembers(businessId);

      int totalMembers = members.length;
      int goldMembers = members.where((m) => m.currentTier == 'gold').length;
      int silverMembers =
          members.where((m) => m.currentTier == 'silver').length;
      int bronzeMembers =
          members.where((m) => m.currentTier == 'bronze').length;

      int totalPointsIssued =
          members.fold<int>(0, (sum, m) => sum + m.totalPoints);
      int totalPointsRedeemed =
          members.fold<int>(0, (sum, m) => sum + m.pointsUsed);

      print('[LoyaltyService] ✓ Stats calculated');

      return {
        'totalMembers': totalMembers,
        'goldMembers': goldMembers,
        'silverMembers': silverMembers,
        'bronzeMembers': bronzeMembers,
        'totalPointsIssued': totalPointsIssued,
        'totalPointsRedeemed': totalPointsRedeemed,
        'averagePointsPerMember': totalMembers > 0
            ? (totalPointsIssued / totalMembers).toStringAsFixed(2)
            : '0',
      };
    } catch (e) {
      print('[LoyaltyService] ✗ Error calculating stats: $e');
      return {};
    }
  }
}

