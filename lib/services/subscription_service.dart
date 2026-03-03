import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import '../data/models/user_model.dart';

/// Subscription plans and pricing
class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final int durationInDays;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationInDays,
    required this.features,
  });
}

/// Service for handling subscription validation and management
class SubscriptionService {
  final FirebaseFirestore _firestore;

  // Available subscription plans (3 / 6 / 12 month fixed durations)
  // Plans are now split by business class: tier1, tier2, tier3
  // Plan IDs follow pattern: t{class}_{basic|pro}_{3m|6m|12m}
  static final List<SubscriptionPlan> plans = [
    // Tier 1 — Basic only
    const SubscriptionPlan(
      id: 't1_basic_3m',
      name: 'Tier 1 — Basic (3 months)',
      price: 23750.0,
      durationInDays: 90,
      features: [
        'Single business',
        'Up to 5 users',
        'Basic reports',
      ],
    ),
    const SubscriptionPlan(
      id: 't1_basic_6m',
      name: 'Tier 1 — Basic (6 months)',
      price: 42250.0,
      durationInDays: 180,
      features: [
        'Single business',
        'Up to 5 users',
        'Basic reports',
      ],
    ),
    const SubscriptionPlan(
      id: 't1_basic_12m',
      name: 'Tier 1 — Basic (12 months)',
      price: 77850.0,
      durationInDays: 365,
      features: [
        'Single business',
        'Up to 5 users',
        'Basic reports',
      ],
    ),

    // Tier 2 — Basic
    const SubscriptionPlan(
      id: 't2_basic_3m',
      name: 'Tier 2 — Basic (3 months)',
      price: 28980.0,
      durationInDays: 90,
      features: [
        'Single business',
        'Up to 10 users',
        'Enhanced reports',
      ],
    ),
    const SubscriptionPlan(
      id: 't2_basic_6m',
      name: 'Tier 2 — Basic (6 months)',
      price: 48480.0,
      durationInDays: 180,
      features: [
        'Single business',
        'Up to 10 users',
        'Enhanced reports',
      ],
    ),
    const SubscriptionPlan(
      id: 't2_basic_12m',
      name: 'Tier 2 — Basic (12 months)',
      price: 88180.0,
      durationInDays: 365,
      features: [
        'Single business',
        'Up to 10 users',
        'Enhanced reports',
      ],
    ),

    // Tier 2 — Pro
    const SubscriptionPlan(
      id: 't2_pro_3m',
      name: 'Tier 2 — Pro (3 months)',
      price: 32780.0,
      durationInDays: 90,
      features: [
        'Multi-location support',
        'Up to 50 users',
        'Advanced reports',
        'Payment processing',
      ],
    ),
    const SubscriptionPlan(
      id: 't2_pro_6m',
      name: 'Tier 2 — Pro (6 months)',
      price: 81880.0,
      durationInDays: 180,
      features: [
        'Multi-location support',
        'Up to 50 users',
        'Advanced reports',
        'Payment processing',
      ],
    ),
    const SubscriptionPlan(
      id: 't2_pro_12m',
      name: 'Tier 2 — Pro (12 months)',
      price: 91900.0,
      durationInDays: 365,
      features: [
        'Multi-location support',
        'Up to 50 users',
        'Advanced reports',
        'Payment processing',
      ],
    ),

    // Tier 3 — Basic
    const SubscriptionPlan(
      id: 't3_basic_3m',
      name: 'Tier 3 — Basic (3 months)',
      price: 36580.0,
      durationInDays: 90,
      features: [
        'Multi-location support',
        'Up to 100 users',
        'Enhanced analytics',
      ],
    ),
    const SubscriptionPlan(
      id: 't3_basic_6m',
      name: 'Tier 3 — Basic (6 months)',
      price: 53980.0,
      durationInDays: 180,
      features: [
        'Multi-location support',
        'Up to 100 users',
        'Enhanced analytics',
      ],
    ),
    const SubscriptionPlan(
      id: 't3_basic_12m',
      name: 'Tier 3 — Basic (12 months)',
      price: 93780.0,
      durationInDays: 365,
      features: [
        'Multi-location support',
        'Up to 100 users',
        'Enhanced analytics',
      ],
    ),

    // Tier 3 — Pro
    const SubscriptionPlan(
      id: 't3_pro_3m',
      name: 'Tier 3 — Pro (3 months)',
      price: 37900.0,
      durationInDays: 90,
      features: [
        'Full enterprise features',
        'Priority support',
        'SSO & white-label',
      ],
    ),
    const SubscriptionPlan(
      id: 't3_pro_6m',
      name: 'Tier 3 — Pro (6 months)',
      price: 56100.0,
      durationInDays: 180,
      features: [
        'Full enterprise features',
        'Priority support',
        'SSO & white-label',
      ],
    ),
    const SubscriptionPlan(
      id: 't3_pro_12m',
      name: 'Tier 3 — Pro (12 months)',
      price: 97780.0,
      durationInDays: 365,
      features: [
        'Full enterprise features',
        'Priority support',
        'SSO & white-label',
      ],
    ),
  ];

  /// Determine business tier from size metrics
  /// - products: number of products
  /// - staff: number of staff workers
  /// - monthlyIncome: reported monthly income in NGN
  /// Rules: enterprise tier removed; highest tier is now 'pro'
  /// Heuristics applied:
  /// - Pro: products >= 1000 || staff >= 50 || monthlyIncome >= 5000000
  /// - Pro: products >= 400 || staff >= 10 || monthlyIncome >= 500000
  /// - Basic: otherwise
  static String detectTier({required int products, required int staff, required double monthlyIncome}) {
    // Map previous enterprise thresholds into 'pro' (enterprise tier deprecated)
    if (products >= 1000 || staff >= 50 || monthlyIncome >= 5000000.0) return 'pro';
    if (products >= 400 || staff >= 10 || monthlyIncome >= 500000.0) return 'pro';
    return 'basic';
  }

  /// Determine business class (tier1, tier2, tier3) from size metrics
  /// Rules (all criteria must match for tier1 or tier2):
  /// - Tier1: products < 400 AND staff < 4 AND monthlyIncome <= 100000
  /// - Tier2: products in [401,1000] AND staff in [4,9] AND monthlyIncome in [1_000_000,2_000_000]
  /// - Tier3: everything else
  static String detectBusinessClass({required int products, required int staff, required double monthlyIncome}) {
    if (products < 400 && staff < 4 && monthlyIncome <= 100000.0) return 'tier1';
    if (products >= 401 && products <= 1000 && staff >= 4 && staff <= 9 && monthlyIncome >= 1000000.0 && monthlyIncome <= 2000000.0) return 'tier2';
    return 'tier3';
  }

  SubscriptionService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Check if user has active subscription (owner must have valid subscription).
  /// Non-owners (workers) are always granted access even if subscription is inactive.
  static bool isSubscriptionActive(UserModel user) {
    // Non-owners do not require an active subscription to use the app
    if (!user.isOwner) return true;

    if (!user.hasActiveSubscription || user.subscriptionEndDate == null) {
      return false;
    }
    return DateTime.now().isBefore(user.subscriptionEndDate!);
  }

  /// Get subscription plan by ID
  static SubscriptionPlan? getPlanById(String planId) {
    try {
      return plans.firstWhere((plan) => plan.id == planId);
    } catch (e) {
      return null;
    }
  }

  /// Returns plans available for a given business class (tier1/tier2/tier3).
  /// If class is null or unrecognized, defaults to tier1.
  static List<SubscriptionPlan> getPlansForClass(String? businessClass) {
    final cls = (businessClass ?? 'tier1').toLowerCase();
    if (cls == 'tier1' || cls == 't1') {
      return plans.where((p) => p.id.startsWith('t1_')).toList();
    }
    if (cls == 'tier2' || cls == 't2') {
      return plans.where((p) => p.id.startsWith('t2_')).toList();
    }
    if (cls == 'tier3' || cls == 't3') {
      return plans.where((p) => p.id.startsWith('t3_')).toList();
    }
    // Default
    return plans.where((p) => p.id.startsWith('t1_')).toList();
  }

  /// Create subscription for user after payment
  Future<bool> createSubscription({
    required String userId,
    required String planId,
    required String transactionId,
    required double amount,
  }) async {
    try {
      final plan = getPlanById(planId);
      if (plan == null) {
        throw Exception('Invalid subscription plan');
      }

      final now = DateTime.now();
      final endDate = now.add(Duration(days: plan.durationInDays));

      await _firestore.collection('users').doc(userId).set({
        'hasActiveSubscription': true,
        'subscriptionPlan': planId,
        'subscriptionStartDate': now.toIso8601String(),
        'subscriptionEndDate': endDate.toIso8601String(),
        'subscriptionPaymentRequired': false,
        'subscriptionTransactionId': transactionId,
        'subscriptionAmount': amount,
        'updatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      // Log subscription event
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'action': 'subscription_created',
        'planId': planId,
        'amount': amount,
        'transactionId': transactionId,
        'startDate': now.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error creating subscription: $e');
      return false;
    }
  }

  /// Renew subscription for user
  Future<bool> renewSubscription({
    required String userId,
    required String planId,
    required String transactionId,
    required double amount,
  }) async {
    try {
      final plan = getPlanById(planId);
      if (plan == null) {
        throw Exception('Invalid subscription plan');
      }

      final now = DateTime.now();
      final endDate = now.add(Duration(days: plan.durationInDays));

      await _firestore.collection('users').doc(userId).set({
        'subscriptionPlan': planId,
        'subscriptionStartDate': now.toIso8601String(),
        'subscriptionEndDate': endDate.toIso8601String(),
        'subscriptionPaymentRequired': false,
        'subscriptionTransactionId': transactionId,
        'subscriptionAmount': amount,
        'updatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      // Log renewal event
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'action': 'subscription_renewed',
        'planId': planId,
        'amount': amount,
        'transactionId': transactionId,
        'startDate': now.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error renewing subscription: $e');
      return false;
    }
  }

  /// Mark subscription as expired
  Future<bool> expireSubscription(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'hasActiveSubscription': false,
        'subscriptionPaymentRequired': true,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Log expiration event
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'action': 'subscription_expired',
        'createdAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error expiring subscription: $e');
      return false;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'hasActiveSubscription': false,
        'subscriptionPaymentRequired': false,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Log cancellation event
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'action': 'subscription_cancelled',
        'createdAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error cancelling subscription: $e');
      return false;
    }
  }

  /// Get user subscription details
  Future<Map<String, dynamic>?> getUserSubscription(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return {
        'hasActiveSubscription': data['hasActiveSubscription'] ?? false,
        'subscriptionPlan': data['subscriptionPlan'],
        'subscriptionStartDate': data['subscriptionStartDate'],
        'subscriptionEndDate': data['subscriptionEndDate'],
        'subscriptionPaymentRequired':
            data['subscriptionPaymentRequired'] ?? true,
        'subscriptionAmount': data['subscriptionAmount'],
      };
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }

  /// Validate and update subscription status based on end date
  Future<bool> validateAndUpdateSubscriptionStatus(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return false;

      if (subscription['hasActiveSubscription'] == true &&
          subscription['subscriptionEndDate'] != null) {
        final endDate = parseTimestamp(subscription['subscriptionEndDate']);
        if (DateTime.now().isAfter(endDate)) {
          // Subscription has expired
          await expireSubscription(userId);
          return false;
        }
      }
      return subscription['hasActiveSubscription'] == true;
    } catch (e) {
      print('Error validating subscription status: $e');
      return false;
    }
  }

  /// Activate subscription immediately after plan selection
  /// This ensures user won't be disturbed about subscription until next reminder
  /// Only updates local cache and user record, NOT the business
  Future<bool> activateSubscriptionImmediately({
    required String userId,
    required String planId,
    required String receiptUrl,
    required double amount,
    String? businessId,
  }) async {
    try {
      print(
          '[SubscriptionService] ▶ Activating subscription immediately for user: $userId');
      print('[SubscriptionService]   Plan: $planId | Amount: $amount');

      final plan = getPlanById(planId);
      if (plan == null) {
        print('[SubscriptionService] ✗ Invalid plan: $planId');
        return false;
      }

      final now = DateTime.now();
      final endDate = now.add(Duration(days: plan.durationInDays));

      // Update user record with subscription info
      // Use set with merge to handle case where user doc might not exist yet
      await _firestore.collection('users').doc(userId).set({
        'hasActiveSubscription': true,
        'subscriptionPlan': planId,
        'subscriptionStatus': 'active', // Set to active immediately
        'subscriptionStartDate': now.toIso8601String(),
        'subscriptionEndDate': endDate.toIso8601String(),
        'subscriptionPaymentRequired': false,
        'subscriptionReceiptUrl': receiptUrl,
        'subscriptionAmount': amount,
        'subscriptionActivatedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      print('[SubscriptionService] ✓ Subscription activated successfully');
      print('[SubscriptionService]   Start: ${now.toIso8601String()}');
      print('[SubscriptionService]   End: ${endDate.toIso8601String()}');
      // If a businessId was supplied, sync subscription details to that business
      if (businessId != null && businessId.isNotEmpty) {
        await syncSubscriptionToBusiness(
            businessId: businessId,
            planId: planId,
            startDate: now,
            endDate: endDate);
      }

      return true;
    } catch (e) {
      print('[SubscriptionService] ✗ Error activating subscription: $e');
      return false;
    }
  }

  /// Activate or renew subscription using a receipt
  /// If user has an active subscription with a future end date, this method
  /// extends the current end date by the plan duration. Otherwise it activates
  /// a new subscription starting now.
  Future<bool> activateOrRenewSubscription({
    required String userId,
    required String planId,
    required String receiptUrl,
    required double amount,
    String? businessId,
  }) async {
    try {
      print('[SubscriptionService] ▶ Activate or renew subscription for $userId | plan: $planId | amount: $amount');

      final plan = getPlanById(planId);
      if (plan == null) {
        print('[SubscriptionService] ✗ Invalid plan: $planId');
        return false;
      }

      final now = DateTime.now();

      // Fetch existing user subscription info
      final userDoc = await _firestore.collection('users').doc(userId).get();
      DateTime? existingStart;
      DateTime? existingEnd;
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          if (data['subscriptionStartDate'] != null) {
            try {
              existingStart = parseTimestamp(data['subscriptionStartDate']);
            } catch (_) {}
          }
          if (data['subscriptionEndDate'] != null) {
            try {
              existingEnd = parseTimestamp(data['subscriptionEndDate']);
            } catch (_) {}
          }
        }
      }

      // If existing end date is in future, extend from that date, otherwise start now
      final startDate = existingStart ?? now;
      final baseStartForExtension = (existingEnd != null && existingEnd.isAfter(now)) ? existingEnd : now;
      final newEndDate = baseStartForExtension.add(Duration(days: plan.durationInDays));

      // Write to user doc
      await _firestore.collection('users').doc(userId).set({
        'hasActiveSubscription': true,
        'subscriptionPlan': planId,
        'subscriptionStatus': 'active',
        'subscriptionStartDate': startDate.toIso8601String(),
        'subscriptionEndDate': newEndDate.toIso8601String(),
        'subscriptionPaymentRequired': false,
        'subscriptionReceiptUrl': receiptUrl,
        'subscriptionAmount': amount,
        'subscriptionActivatedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      // Log event as either 'subscription_activated' or 'subscription_renewed'
      final action = (existingEnd != null && existingEnd.isAfter(now)) ? 'subscription_renewed' : 'subscription_activated';
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'action': action,
        'planId': planId,
        'amount': amount,
        'receiptUrl': receiptUrl,
        'startDate': startDate.toIso8601String(),
        'endDate': newEndDate.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });

      // Sync to business if provided
      if (businessId != null && businessId.isNotEmpty) {
        await syncSubscriptionToBusiness(
            businessId: businessId, planId: planId, startDate: startDate, endDate: newEndDate);
      }

      print('[SubscriptionService] ✓ Activate/Renew completed; new end: ${newEndDate.toIso8601String()}');
      return true;
    } catch (e) {
      print('[SubscriptionService] ✗ Error in activateOrRenewSubscription: $e');
      return false;
    }
  }

  /// Sync activated subscription to business
  /// This should be called later (after admin approval or separately)
  /// to apply subscription benefits to all business locations
  Future<bool> syncSubscriptionToBusiness({
    required String businessId,
    required String planId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print(
          '[SubscriptionService] ▶ Syncing subscription to business: $businessId');

      final plan = getPlanById(planId);
      if (plan == null) {
        print('[SubscriptionService] ✗ Invalid plan: $planId');
        return false;
      }

      // Update business record (store base tier in 'subscriptionTier' and full plan id in 'subscriptionPlan')
      final baseTier = planId.split('_').first;
      await _firestore.collection('businesses').doc(businessId).update({
        'subscriptionTier': baseTier,
        'subscriptionPlan': planId,
        'subscriptionStartDate': startDate.toIso8601String(),
        'subscriptionEndDate': endDate.toIso8601String(),
        'isSubscriptionActive': true,
        'subscriptionSyncedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('[SubscriptionService] ✓ Subscription synced to business');
      return true;
    } catch (e) {
      print(
          '[SubscriptionService] ✗ Error syncing subscription to business: $e');
      return false;
    }
  }

  /// Update subscription with all related businesses
  /// Useful for admin approvals or subscription changes
  Future<bool> updateSubscriptionWithBusinesses({
    required String userId,
    required String businessIds, // comma-separated or list
    required String planId,
    required DateTime endDate,
  }) async {
    try {
      print('[SubscriptionService] ▶ Updating subscription for user: $userId');

      // Parse business IDs (expected to be comma-separated string)
      final businessIdList =
          businessIds.split(',').map((e) => e.trim()).toList();

      // Update user subscription
      // Use set with merge to handle case where user doc might not exist
      final baseTier = planId.split('_').first;
      await _firestore.collection('users').doc(userId).set({
        'subscriptionPlan': planId,
        'subscriptionTier': baseTier,
        'subscriptionEndDate': endDate.toIso8601String(),
        'hasActiveSubscription': true,
        'subscriptionStatus': 'active',
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Update all businesses
      for (final businessId in businessIdList) {
        await _firestore.collection('businesses').doc(businessId).update({
          'subscriptionTier': baseTier,
          'subscriptionPlan': planId,
          'subscriptionEndDate': endDate.toIso8601String(),
          'isSubscriptionActive': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      print(
          '[SubscriptionService] ✓ Subscription updated for ${businessIdList.length} businesses');
      return true;
    } catch (e) {
      print('[SubscriptionService] ✗ Error updating subscription: $e');
      return false;
    }
  }
}

