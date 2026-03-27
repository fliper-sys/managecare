import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/utils/datetime_utils.dart';
import '../data/models/business_model.dart';
import 'local_business_storage.dart';

/// Background subscription status checker
/// Monitors subscription expiry, status changes, and enforces feature access
class BackgroundSubscriptionChecker {
  final FirebaseFirestore _firestore;
  final LocalBusinessStorage _localBusinessStorage;

  Timer? _checkTimer;
  final Duration _checkInterval;

  // Callbacks for subscription status changes
  Function(String businessId, bool isValid)? onSubscriptionStatusChanged;
  Function(String businessId, String message)? onFeatureAccessDenied;
  Function(String businessId, int daysLeft)? onSubscriptionExpiringSoon;
  Function(String businessId, int daysLeft, String milestone)? onSubscriptionRenewalReminder;

  // Keep latest reminder milestone per business to avoid repeated triggers
  final Map<String, int> _lastReminderMilestoneSent = {};

  // Logging
  final _log = _SubscriptionCheckerLogger();

  // Defensive: track active user's role to avoid making subscription requests for workers
  String? _activeUserRole;

  BackgroundSubscriptionChecker({
    required FirebaseFirestore firestore,
    required LocalBusinessStorage localBusinessStorage,
    this.onSubscriptionStatusChanged,
    this.onFeatureAccessDenied,
    this.onSubscriptionExpiringSoon,
    this.onSubscriptionRenewalReminder,
    Duration checkInterval = const Duration(minutes: 30),
  })  : _firestore = firestore,
        _localBusinessStorage = localBusinessStorage,
        _checkInterval = checkInterval;

  /// Start background subscription checking
  void startBackgroundChecking(String userId, {String? userRole}) {
    _log.info('Starting background subscription checking for user: $userId');

    // If user is a worker, do not start background checks
    if (userRole != null && userRole.toLowerCase() == 'worker') {
      _log.info('Skipping background subscription checks for worker user: $userId');
      return;
    }

    // Cancel existing timer
    stopBackgroundChecking();

    // Store active role for periodic checks (defensive guard)
    _activeUserRole = userRole;

    // Check immediately
    _checkUserSubscriptions(userId);

    // Then check periodically
    _checkTimer = Timer.periodic(_checkInterval, (_) {
      _checkUserSubscriptions(userId);
    });
  }

  /// Stop background subscription checking
  void stopBackgroundChecking() {
    _log.info('Stopping background subscription checking');
    _checkTimer?.cancel();
    _checkTimer = null;
    _activeUserRole = null;
  }

  /// Check all user's businesses for subscription status
  Future<void> _checkUserSubscriptions(String userId) async {
    try {
      _log.info('Checking subscription status for user: $userId');

      // Defensive: skip if this background checker was invoked for a worker user
      if (_activeUserRole != null && _activeUserRole!.toLowerCase() == 'worker') {
        _log.info('Skipping subscription checks because user role is worker: $userId');
        return;
      }

      // Get all cached businesses
      final cachedBusinesses = _localBusinessStorage.getCachedBusinesses();

      if (cachedBusinesses.isEmpty) {
        _log.debug('No cached businesses found for user: $userId');
        return;
      }

      // Check each business subscription
      for (final business in cachedBusinesses) {
        await _checkBusinessSubscription(userId, business);
      }
    } catch (e) {
      _log.error('Error checking user subscriptions', error: e);
    }
  }

  /// Check individual business subscription status
  Future<void> _checkBusinessSubscription(
    String userId,
    BusinessModel business,
  ) async {
    try {
      _log.debug(
          'Checking subscription for business: ${business.id} (${business.name})');

      // Get latest from Firebase
      final docSnapshot =
          await _firestore.collection('businesses').doc(business.id).get();

      if (!docSnapshot.exists) {
        _log.warn('Business document not found: ${business.id}');
        return;
      }

      final data = docSnapshot.data() ?? {};

      // Extract subscription info
      final subscriptionTier = data['subscriptionTier'] as String? ?? 'free';
      final isSubscriptionActive =
          data['isSubscriptionActive'] as bool? ?? false;
      final subscriptionEndDateStr = data['subscriptionEndDate'] as String?;

      // Check subscription validity
      final wasValid = _isSubscriptionValid(business);
      final isNowValid = _checkSubscriptionValidity(
        tier: subscriptionTier,
        isActive: isSubscriptionActive,
        endDate: subscriptionEndDateStr,
      );

      _log.info(
        'Business ${business.name}: '
        'tier=$subscriptionTier, '
        'active=$isSubscriptionActive, '
        'valid=$isNowValid',
      );

      // Handle subscription status change
      if (wasValid != isNowValid) {
        _log.warn(
            'Subscription status changed for ${business.name}: $wasValid → $isNowValid');
        onSubscriptionStatusChanged?.call(business.id, isNowValid);
      }

      // Check expiration warning (7 days before expiry)
      if (isSubscriptionActive && subscriptionEndDateStr != null) {
        _checkExpirationWarning(business.id, subscriptionEndDateStr);
      }

      // Update local cache with latest subscription info
      if (wasValid != isNowValid) {
        _log.info('Updating cache for business: ${business.id}');
        await _updateBusinessSubscriptionCache(
          userId,
          business.id,
          subscriptionTier,
          isSubscriptionActive,
          subscriptionEndDateStr,
        );
      }
    } catch (e) {
      _log.error('Error checking business subscription: ${business.id}',
          error: e);
    }
  }

  /// Check if subscription expires in next 7 days (and issue milestones)
  void _checkExpirationWarning(String businessId, String endDateStr) {
    try {
      final endDate = parseTimestamp(endDateStr);
      final now = DateTime.now();

      final daysLeft = DateTime(endDate.year, endDate.month, endDate.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

      if (daysLeft < 0) {
        // Already expired; nothing to do here (handled elsewhere)
        return;
      }

      final reminderMilestones = [7, 3, 2, 1];

      if (reminderMilestones.contains(daysLeft)) {
        _log.warn(
            'Subscription expiring in $daysLeft days for business: $businessId');

        // Avoid repeating same milestone notifications repeatedly
        final lastSent = _lastReminderMilestoneSent[businessId];
        if (lastSent != daysLeft) {
          _lastReminderMilestoneSent[businessId] = daysLeft;
          onSubscriptionExpiringSoon?.call(businessId, daysLeft);

          final milestoneLabel = _milestoneLabel(daysLeft);
          onSubscriptionRenewalReminder?.call(businessId, daysLeft, milestoneLabel);
        }
      }
    } catch (e) {
      _log.error('Error parsing expiration date: $endDateStr', error: e);
    }
  }

  String _milestoneLabel(int daysLeft) {
    switch (daysLeft) {
      case 7:
        return '1 week';
      case 3:
        return '3 days';
      case 2:
        return '2 days';
      case 1:
        return '1 day';
      default:
        return '$daysLeft day(s)';
    }
  }

  /// Update cached subscription info
  Future<void> _updateBusinessSubscriptionCache(
    String userId,
    String businessId,
    String subscriptionTier,
    bool isSubscriptionActive,
    String? subscriptionEndDate,
  ) async {
    try {
      // Get current cached business
      final cachedBusiness =
          _localBusinessStorage.getCachedBusiness(businessId);

      if (cachedBusiness == null) {
        _log.debug('Business not in cache: $businessId');
        return;
      }

      // Create updated business model
      final updatedBusiness = BusinessModel(
        id: cachedBusiness.id,
        name: cachedBusiness.name,
        businessType: cachedBusiness.businessType,
        description: cachedBusiness.description,
        ownerId: cachedBusiness.ownerId,
        logoUrl: cachedBusiness.logoUrl,
        photoUrl: cachedBusiness.photoUrl,
        currency: cachedBusiness.currency,
        taxId: cachedBusiness.taxId,
        taxRate: cachedBusiness.taxRate,
        email: cachedBusiness.email,
        phone: cachedBusiness.phone,
        website: cachedBusiness.website,
        address: cachedBusiness.address,
        city: cachedBusiness.city,
        state: cachedBusiness.state,
        country: cachedBusiness.country,
        postalCode: cachedBusiness.postalCode,
        location: cachedBusiness.location,
        subscriptionTier: subscriptionTier,        businessClass: cachedBusiness.businessClass,        isSubscriptionActive: isSubscriptionActive,
        subscriptionStartDate: cachedBusiness.subscriptionStartDate,
        subscriptionEndDate: subscriptionEndDate != null
            ? parseTimestamp(subscriptionEndDate)
            : null,
        settings: cachedBusiness.settings,
        industrySpecificSettings: cachedBusiness.industrySpecificSettings,
        isActive: cachedBusiness.isActive,
        createdAt: cachedBusiness.createdAt,
        updatedAt: DateTime.now(),
        totalWorkers: cachedBusiness.totalWorkers,
        totalProducts: cachedBusiness.totalProducts,
        totalCustomers: cachedBusiness.totalCustomers,
      );

      // Update cache
      final updates = {
        'subscriptionTier': updatedBusiness.subscriptionTier,
        'isSubscriptionActive': updatedBusiness.isSubscriptionActive,
        'subscriptionEndDate': updatedBusiness.subscriptionEndDate,
      };
      await _localBusinessStorage.updateCachedBusiness(businessId, updates);
      _log.info('Updated cached subscription for business: $businessId');
    } catch (e) {
      _log.error('Error updating business cache: $businessId', error: e);
    }
  }

  /// Validate feature access
  /// Returns a map {ok: bool, message: String?}
  Future<Map<String, dynamic>> validateFeatureAccess(
    BusinessModel business,
    String feature,
  ) async {
    try {
      // Check if subscription is valid
      if (!_isSubscriptionValid(business)) {
        final message = 'Subscription expired or inactive for ${business.name}';
        _log.warn('Feature access denied: $message (feature: $feature)');
        onFeatureAccessDenied?.call(business.id, message);
        return {'ok': false, 'message': message};
      }

      // Check feature availability for tier
      final tier = business.subscriptionTier.toLowerCase();
      final tierResult = _checkFeatureForTier(tier, feature);
      final hasAccess = tierResult['ok'] as bool;
      final reason = tierResult['message'] as String?;

      if (!hasAccess) {
        final message = reason ?? 'Feature not available in your subscription tier';
        _log.warn(
            'Feature access denied: $message (feature: $feature, tier: $tier)');
        onFeatureAccessDenied?.call(business.id, message);
        return {'ok': false, 'message': message};
      }

      _log.debug('Feature access granted: $feature for tier: $tier');
      return {'ok': true, 'message': null};
    } catch (e) {
      _log.error('Error validating feature access', error: e);
      return {'ok': false, 'message': 'Error checking feature access'};
    }
  }

  /// Get subscription status details
  SubscriptionStatus getSubscriptionStatus(BusinessModel business) {
    final isValid = _isSubscriptionValid(business);
    final daysLeft = _getDaysUntilExpiration(business);

    return SubscriptionStatus(
      businessId: business.id,
      businessName: business.name,
      tier: business.subscriptionTier,
      isActive: business.isSubscriptionActive,
      isValid: isValid,
      startDate: business.subscriptionStartDate,
      endDate: business.subscriptionEndDate,
      daysUntilExpiration: daysLeft,
      isExpiringWithinDays: daysLeft != null && daysLeft >= 0 && daysLeft <= 7,
    );
  }

  /// Get all subscription statuses for a user
  Future<List<SubscriptionStatus>> getAllSubscriptionStatuses(
      String userId) async {
    try {
      final businesses = _localBusinessStorage.getCachedBusinesses();
      return businesses.map((b) => getSubscriptionStatus(b)).toList();
    } catch (e) {
      _log.error('Error getting subscription statuses', error: e);
      return [];
    }
  }

  // Private helper methods

  bool _isSubscriptionValid(BusinessModel business) {
    if (!business.isSubscriptionActive) return false;
    if (business.subscriptionEndDate == null) return true;
    return DateTime.now().isBefore(business.subscriptionEndDate!);
  }

  bool _checkSubscriptionValidity({
    required String tier,
    required bool isActive,
    required String? endDate,
  }) {
    if (!isActive) return false;
    if (endDate == null) return true;
    try {
      return DateTime.now().isBefore(parseTimestamp(endDate));
    } catch (e) {
      _log.error('Error parsing end date: $endDate', error: e);
      return false;
    }
  }

  /// Returns reminder milestone (number of days) when the given end date is
  /// exactly 7, 3, 2 or 1 day ahead of the reference date.
  static int? calculateReminderMilestone({required DateTime now, required DateTime endDate}) {
    final daysLeft = DateTime(endDate.year, endDate.month, endDate.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    const reminderMilestones = [7, 3, 2, 1];
    return reminderMilestones.contains(daysLeft) ? daysLeft : null;
  }

  int? _getDaysUntilExpiration(BusinessModel business) {
    if (business.subscriptionEndDate == null) return null;
    return business.subscriptionEndDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> _checkFeatureForTier(String tier, String feature) {
    final normalizedTier = tier.toLowerCase();

    switch (feature) {
      // Free tier features
      case 'basic_sales':
      case 'product_management':
      case 'basic_reports':
        return {'ok': true, 'message': null};

      // Basic/Pro features
      case 'unlimited_workers':
      case 'advanced_analytics':
      case 'email_receipts':
      case 'sms_notifications':
        if (normalizedTier == 'basic' ||
            normalizedTier == 'pro' ||
            normalizedTier == 'professional' ||
            normalizedTier == 'enterprise' ||
            normalizedTier == 'tier3') {
          return {'ok': true, 'message': null};
        }
        return {'ok': false, 'message': 'Available in Basic tier and above'};

      // Pro features
      case 'multi_location':
      case 'api_access':
      case 'payment_processing':
      case 'custom_reports':
      case 'priority_support':
        if (normalizedTier == 'pro' ||
            normalizedTier == 'professional' ||
            normalizedTier == 'enterprise' ||
            normalizedTier == 'tier3') {
          return {'ok': true, 'message': null};
        }
        return {
          'ok': false,
          'message': 'Available in Professional tier and above'
        };

      // Enterprise only
      case 'white_label':
      case 'sso_login':
      case 'dedicated_support':
      case 'custom_development':
      case 'api_advanced':
        if (normalizedTier == 'enterprise' || normalizedTier == 'tier3') {
          return {'ok': true, 'message': null};
        }
        return {'ok': false, 'message': 'Available in Enterprise (Tier3) only'};

      default:
        return {'ok': true, 'message': null}; // Unknown features default to available
    }
  }

  /// Dispose resources
  void dispose() {
    stopBackgroundChecking();
  }
}

/// Subscription status data class
class SubscriptionStatus {
  final String businessId;
  final String businessName;
  final String tier;
  final bool isActive;
  final bool isValid;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? daysUntilExpiration;
  final bool isExpiringWithinDays;

  SubscriptionStatus({
    required this.businessId,
    required this.businessName,
    required this.tier,
    required this.isActive,
    required this.isValid,
    required this.startDate,
    required this.endDate,
    required this.daysUntilExpiration,
    required this.isExpiringWithinDays,
  });

  /// Get human-readable status message
  String get statusMessage {
    if (!isActive) return 'Subscription inactive';
    if (!isValid) return 'Subscription expired';
    if (isExpiringWithinDays && daysUntilExpiration != null) {
      return 'Expiring in $daysUntilExpiration days';
    }
    return 'Active';
  }

  /// Check if action needed
  bool get needsAction => !isValid || isExpiringWithinDays;
}

/// Logger for subscription checker
class _SubscriptionCheckerLogger {
  static const String _prefix = '[BackgroundSubscriptionChecker]';

  void info(String message) {
    debugPrint('$_prefix ℹ️ $message');
  }

  void debug(String message) {
    debugPrint('$_prefix 🔍 $message');
  }

  void warn(String message) {
    debugPrint('$_prefix ⚠️ $message');
  }

  void error(String message, {dynamic error}) {
    debugPrint('$_prefix ❌ $message${error != null ? ': $error' : ''}');
  }
}

