import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/business_model.dart';
import '../services/background_subscription_checker.dart';
import '../services/subscription_feature_guard.dart';
import '../services/subscription_service.dart';
import '../services/local_business_storage.dart';

/// Provider for subscription management with background checking and feature enforcement
class EnhancedSubscriptionProvider extends ChangeNotifier {
  late final BackgroundSubscriptionChecker _subscriptionChecker;
  late final SubscriptionFeatureGuard _featureGuard;
  late final FirebaseFirestore _firestore;

  // State
  final Map<String, SubscriptionStatus> _subscriptionStatuses = {};
  String? _lastError;
  bool _isInitialized = false;
  bool _isChecking = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isChecking => _isChecking;
  String? get lastError => _lastError;
  Map<String, SubscriptionStatus> get subscriptionStatuses =>
      _subscriptionStatuses;

  EnhancedSubscriptionProvider({
    FirebaseFirestore? firestore,
    LocalBusinessStorage? localBusinessStorage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    // Initialize services if localBusinessStorage is provided
    if (localBusinessStorage != null) {
      _subscriptionChecker = BackgroundSubscriptionChecker(
        firestore: _firestore,
        localBusinessStorage: localBusinessStorage,
        onSubscriptionStatusChanged: _onSubscriptionStatusChanged,
        onFeatureAccessDenied: _onFeatureAccessDenied,
        onSubscriptionExpiringSoon: _onSubscriptionExpiringSoon,
        onSubscriptionRenewalReminder: _onSubscriptionRenewalReminder,
      );

      _featureGuard = SubscriptionFeatureGuard(
        subscriptionChecker: _subscriptionChecker,
      );

      _isInitialized = true;
    }
  }

  /// Initialize the provider with a LocalBusinessStorage instance.
  /// This can be called after construction when async creation is needed.
  Future<void> initialize(LocalBusinessStorage localBusinessStorage) async {
    if (_isInitialized) return;

    _subscriptionChecker = BackgroundSubscriptionChecker(
      firestore: _firestore,
      localBusinessStorage: localBusinessStorage,
      onSubscriptionStatusChanged: _onSubscriptionStatusChanged,
      onFeatureAccessDenied: _onFeatureAccessDenied,
      onSubscriptionExpiringSoon: _onSubscriptionExpiringSoon,
      onSubscriptionRenewalReminder: _onSubscriptionRenewalReminder,
    );

    _featureGuard = SubscriptionFeatureGuard(
      subscriptionChecker: _subscriptionChecker,
    );

    _isInitialized = true;
    notifyListeners();
  }

  // Public methods

  /// Initialize background checking for user
  void initializeForUser(String userId, {String? userRole}) {
    // Do not start background checks for worker users
    if (userRole != null && userRole.toLowerCase() == 'worker') {
      debugPrint('[EnhancedSubscriptionProvider] Skipping background checks for worker: $userId');
      return;
    }

    _subscriptionChecker.startBackgroundChecking(userId, userRole: userRole);
  }

  /// Check if user can access a feature
  Future<bool> canAccessFeature({
    required BusinessModel business,
    required String feature,
    required String context,
    String? userRole,
  }) async {
    if (!_isInitialized) {
      try {
        final local = await LocalBusinessStorage.create();
        await initialize(local);
      } catch (e) {
        _lastError = 'Subscription system not ready: $e';
        debugPrint(_lastError);
        return false;
      }
    }

    return await _featureGuard.canAccessFeature(
      business: business,
      feature: feature,
      context: context,
      userRole: userRole,
    );
  }

  /// Assert feature access (throws if denied)
  Future<void> assertFeatureAccess({
    required BusinessModel business,
    required String feature,
    required String context,
    String? userRole,
  }) async {
    return await _featureGuard.assertFeatureAccess(
      business: business,
      feature: feature,
      context: context,
      userRole: userRole,
    );
  }

  /// Check if feature requires upgrade
  bool needsUpgrade({
    required BusinessModel business,
    required String feature,
    String? userRole,
  }) {
    return _featureGuard.needsUpgrade(
      business: business,
      feature: feature,
      userRole: userRole,
    );
  }

  /// Get upgrade path for feature
  UpgradePath getUpgradePath({
    required BusinessModel business,
    required String feature,
    String? userRole,
  }) {
    return _featureGuard.getUpgradePath(
      business: business,
      feature: feature,
      userRole: userRole,
    );
  }

  /// Get subscription status for business
  SubscriptionStatus? getSubscriptionStatus(String businessId) {
    return _subscriptionStatuses[businessId];
  }

  /// Get all subscription statuses
  Future<List<SubscriptionStatus>> getAllSubscriptionStatuses(
      String userId) async {
    return await _subscriptionChecker.getAllSubscriptionStatuses(userId);
  }

  /// Get feature availability matrix
  Map<String, Map<String, bool>> getFeatureMatrix() {
    return _featureGuard.getFeatureMatrix();
  }

  /// Get feature tier requirement
  String? getFeatureTierRequirement(String feature) {
    return _featureGuard.getFeatureTierRequirement(feature);
  }

  /// Get access logs
  List<FeatureAccessLog> getAccessLogs({
    String? businessId,
    String? feature,
    int limit = 100,
  }) {
    return _featureGuard.getAccessLogs(
      businessId: businessId,
      feature: feature,
      limit: limit,
    );
  }

  /// Export access logs
  List<Map<String, dynamic>> exportAccessLogs() {
    return _featureGuard.exportAccessLogs();
  }

  /// Clear access logs
  void clearAccessLogs() {
    _featureGuard.clearAccessLogs();
  }

  /// Check subscription status now (manual check)
  Future<void> refreshSubscriptionStatus(String userId) async {
    try {
      _isChecking = true;
      _lastError = null;
      notifyListeners();

      final statuses =
          await _subscriptionChecker.getAllSubscriptionStatuses(userId);
      for (final status in statuses) {
        _subscriptionStatuses[status.businessId] = status;
      }
    } catch (e) {
      _lastError = 'Error refreshing subscription status: $e';
      debugPrint(_lastError);
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Stop background checking
  void stopBackgroundChecking() {
    _subscriptionChecker.stopBackgroundChecking();
  }

  /// Activate subscription immediately after plan selection
  /// Ensures user won't be disturbed about subscription until next reminder (30 min)
  Future<bool> activateSubscriptionForUser({
    required String userId,
    required String planId,
    required String receiptUrl,
    required double amount,
    String? businessId,
    String? userRole,
  }) async {
    // Prevent workers from performing subscription payments
    if (userRole != null && userRole.toLowerCase() == 'worker') {
      _lastError = 'Worker accounts cannot perform subscription payments';
      notifyListeners();
      debugPrint('[EnhancedSubscriptionProvider] Blocked subscription activation for worker: $userId');
      return false;
    }

    try {
      debugPrint(
          '[EnhancedSubscriptionProvider] Activating subscription for user: $userId');
      debugPrint(
          '[EnhancedSubscriptionProvider] Plan: $planId | Amount: $amount');

      // Create a subscription service instance
      final subscriptionService = SubscriptionService(
        firestore: FirebaseFirestore.instance,
      );

      // Activate immediately
      final success = await subscriptionService.activateOrRenewSubscription(
        userId: userId,
        planId: planId,
        receiptUrl: receiptUrl,
        amount: amount,
        businessId: businessId,
      );

      if (success) {
        debugPrint(
            '[EnhancedSubscriptionProvider] ✓ Subscription activated successfully');

        // Refresh status to update UI
        await Future.delayed(const Duration(milliseconds: 500));
        await refreshSubscriptionStatus(userId);

        return true;
      } else {
        _lastError = 'Failed to activate subscription';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Error activating subscription: $e';
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  /// Admin-initiated subscription activation for a target user/business
  Future<bool> adminActivateSubscription({
    required String adminId,
    required String targetUserId,
    required String planId,
    required String receiptUrl,
    required double amount,
    String? businessId,
  }) async {
    try {
      debugPrint('[EnhancedSubscriptionProvider] Admin ($adminId) activating subscription for user: $targetUserId');

      final subscriptionService = SubscriptionService(firestore: FirebaseFirestore.instance);
      final success = await subscriptionService.activateOrRenewSubscription(
        userId: targetUserId,
        planId: planId,
        receiptUrl: receiptUrl,
        amount: amount,
        businessId: businessId,
      );

      if (!success) {
        _lastError = 'Subscription activation failed';
        notifyListeners();
        return false;
      }

      // Log admin action to subscription_events for audit
      try {
        await FirebaseFirestore.instance.collection('subscription_events').add({
          'adminId': adminId,
          'userId': targetUserId,
          'action': 'admin_activated',
          'planId': planId,
          'amount': amount,
          'receiptUrl': receiptUrl,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[EnhancedSubscriptionProvider] Warning: failed to log admin activation: $e');
      }

      // Refresh subscription statuses for UI
      await Future.delayed(const Duration(milliseconds: 500));
      await refreshSubscriptionStatus(targetUserId);

      return true;
    } catch (e) {
      _lastError = 'Error during admin activation: $e';
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  /// Get detailed subscription info
  SubscriptionDetails? getSubscriptionDetails(String businessId) {
    final status = _subscriptionStatuses[businessId];
    if (status == null) return null;

    return SubscriptionDetails(
      businessId: status.businessId,
      businessName: status.businessName,
      tier: status.tier,
      isActive: status.isActive,
      isValid: status.isValid,
      startDate: status.startDate,
      endDate: status.endDate,
      daysUntilExpiration: status.daysUntilExpiration,
      isExpiringWithinDays: status.isExpiringWithinDays,
      statusMessage: status.statusMessage,
      needsAction: status.needsAction,
      accessibleFeatures: _getAccessibleFeatures(status.tier),
    );
  }

  /// Get comparison of tiers
  Map<String, dynamic> getSubscriptionComparison() {
    return {
      'free': {
        'name': 'Free',
        'price': 0.0,
        'billingCycle': 'forever',
        'features': _getFeaturesForTier('free'),
      },
      'tier1': {
        'name': 'Tier 1',
        'price': 0.0,
        'billingCycle': 'varies by business',
        'features': _getFeaturesForTier('tier1'),
      },
      'tier2': {
        'name': 'Tier 2',
        'price': 0.0,
        'billingCycle': 'varies by business',
        'features': _getFeaturesForTier('tier2'),
      },
      'tier3': {
        'name': 'Tier 3',
        'price': 0.0,
        'billingCycle': 'varies by business',
        'features': _getFeaturesForTier('tier3'),
      },
      'unlimited': {
        'name': 'Unlimited',
        'price': 0.0,
        'billingCycle': 'varies by business',
        'features': _getFeaturesForTier('unlimited'),
      },
    };
  }

  // Private methods

  void _onSubscriptionStatusChanged(String businessId, bool isValid) {
    debugPrint(
        '[EnhancedSubscriptionProvider] Status changed for $businessId: isValid=$isValid');
    notifyListeners();
  }

  void _onFeatureAccessDenied(String businessId, String message) {
    debugPrint(
        '[EnhancedSubscriptionProvider] Access denied for $businessId: $message');
  }

  void _onSubscriptionExpiringSoon(String businessId, int daysLeft) {
    debugPrint(
        '[EnhancedSubscriptionProvider] Subscription expiring in $daysLeft days for $businessId');
    notifyListeners();
  }

  void _onSubscriptionRenewalReminder(String businessId, int daysLeft, String milestone) {
    debugPrint(
        '[EnhancedSubscriptionProvider] Renewal reminder: $milestone ($daysLeft days left) for $businessId');
    notifyListeners();
  }

  List<String> _getFeaturesForTier(String tier) {
    final tierLower = tier.toLowerCase();
    switch (tierLower) {
      case 'free':
        return [
          'Basic sales tracking',
          'Basic reports',
          'Per-business subscription visibility',
        ];
      case 'tier1':
        return [
          'All free features',
          'Email receipts',
          'SMS notifications',
          'Payment processing',
          'Advanced analytics',
        ];
      case 'tier2':
        return [
          'All Tier 1 features',
          'Multi-location support',
          'Higher operational limits',
        ];
      case 'tier3':
        return [
          'All Tier 2 features',
          'Priority support',
          'Custom reports',
          'Premium business features',
        ];
      case 'unlimited':
        return [
          'All Tier 3 features',
          'Unlimited access',
          'API access',
          'White-label and dedicated support',
        ];
      default:
        return [];
    }
  }

  List<String> _getAccessibleFeatures(String tier) {
    const allFeatures = [
      'basic_sales',
      'product_management',
      'basic_reports',
      'unlimited_workers',
      'advanced_analytics',
      'email_receipts',
      'sms_notifications',
      'multi_location',
      'api_access',
      'payment_processing',
      'custom_reports',
      'priority_support',
      'white_label',
      'sso_login',
      'dedicated_support',
      'custom_development',
      'api_advanced',
    ];

    final accessible = <String>[];

    for (final feature in allFeatures) {
      final required = _featureGuard.getFeatureTierRequirement(feature);
      if (required == null) {
        accessible.add(feature);
        continue;
      }

      final userLevel = SubscriptionService.getTierRank(tier);
      final requiredLevel = SubscriptionService.getTierRank(required);

      if (userLevel >= requiredLevel) {
        accessible.add(feature);
      }
    }

    return accessible;
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _subscriptionChecker.dispose();
    }
    super.dispose();
  }
}

/// Detailed subscription information
class SubscriptionDetails {
  final String businessId;
  final String businessName;
  final String tier;
  final bool isActive;
  final bool isValid;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? daysUntilExpiration;
  final bool isExpiringWithinDays;
  final String statusMessage;
  final bool needsAction;
  final List<String> accessibleFeatures;

  SubscriptionDetails({
    required this.businessId,
    required this.businessName,
    required this.tier,
    required this.isActive,
    required this.isValid,
    required this.startDate,
    required this.endDate,
    required this.daysUntilExpiration,
    required this.isExpiringWithinDays,
    required this.statusMessage,
    required this.needsAction,
    required this.accessibleFeatures,
  });

  /// Get remaining time as human-readable string
  String get expirationReadable {
    if (daysUntilExpiration == null) return 'No expiration';
    if (daysUntilExpiration! <= 0) return 'Expired';
    if (daysUntilExpiration! == 1) return '1 day left';
    return '${daysUntilExpiration!} days left';
  }

  /// Check if action needed
  bool get actionNeeded => !isValid || isExpiringWithinDays;

  /// Get action type
  String get actionType {
    if (!isValid) return 'RENEW_IMMEDIATELY';
    if (daysUntilExpiration != null && daysUntilExpiration! <= 3)
      return 'RENEW_SOON';
    if (isExpiringWithinDays) return 'RENEW_UPCOMING';
    return 'NONE';
  }
}

