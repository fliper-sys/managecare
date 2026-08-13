import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/utils/datetime_utils.dart';
import '../data/models/business_model.dart';
import 'local_business_storage.dart';
import 'managecare_api_client.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

/// Background subscription status checker
/// Monitors subscription expiry, status changes, and enforces feature access
class BackgroundSubscriptionChecker {
  final LocalBusinessStorage _localBusinessStorage;

  Timer? _checkTimer;
  final Duration _checkInterval;
  String? _activeUserId;

  // Callbacks for subscription status changes
  Function(String businessId, bool isValid)? onSubscriptionStatusChanged;
  Function(String businessId, String message)? onFeatureAccessDenied;
  Function(String businessId, int daysLeft)? onSubscriptionExpiringSoon;
  Function(String businessId, int daysLeft, String milestone)? onSubscriptionRenewalReminder;

  // Keep latest reminder milestone per business to avoid repeated triggers
  final Map<String, int> _lastReminderMilestoneSent = {};
  final Map<String, String> _lastReminderDateKeyByBusiness = {};

  // Logging
  final _log = _SubscriptionCheckerLogger();

  // Defensive: track active user's role to avoid making subscription requests for workers
  String? _activeUserRole;

  BackgroundSubscriptionChecker({
    required LocalBusinessStorage localBusinessStorage,
    this.onSubscriptionStatusChanged,
    this.onFeatureAccessDenied,
    this.onSubscriptionExpiringSoon,
    this.onSubscriptionRenewalReminder,
    Duration checkInterval = const Duration(minutes: 30),
  })  : _localBusinessStorage = localBusinessStorage,
        _checkInterval = checkInterval;

  /// Start background subscription checking
  void startBackgroundChecking(String userId, {String? userRole}) {
    // This is called from app.dart's AuthProvider listener, which fires on
    // *every* notifyListeners() call - not just login/logout - so this could
    // otherwise run every few seconds instead of respecting _checkInterval.
    // Each restart also does an immediate full re-check of every business,
    // which was flooding the user with duplicate "subscription renewal
    // reminder" notifications and hammering the backend with redundant
    // requests. If checking is already active for this same user, this is
    // a no-op - only a genuine user change (or an explicit stop) restarts it.
    if (_checkTimer != null && _activeUserId == userId) {
      return;
    }

    _log.info('Starting background subscription checking for user: $userId');

    // If user is a worker, do not start background checks
    if (userRole != null && userRole.toLowerCase() == 'worker') {
      _log.info('Skipping background subscription checks for worker user: $userId');
      return;
    }

    // Cancel existing timer
    stopBackgroundChecking();

    // Store active user/role for periodic checks (defensive guard)
    _activeUserId = userId;
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
    _activeUserId = null;
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

      // Get latest from the backend
      Map<String, dynamic>? data;
      try {
        final response = await ManagecareApiClient.instance
            .get('/api/subscriptions/business/${business.id}');
        data = Map<String, dynamic>.from(response as Map);
      } catch (_) {
        _log.warn('Business record not found: ${business.id}');
        return;
      }

      // Extract subscription info
      final subscriptionTier = SubscriptionService.normalizeStoredPlanLevel(
        subscriptionTier: data['subscription_tier'] as String?,
        subscriptionPlan: data['subscription_plan'] as String?,
        businessClass: data['business_class'] as String?,
      );
      final isSubscriptionActive =
          data['is_subscription_active'] as bool? ?? false;
      final subscriptionEndDateRaw = data['subscription_end_date'];

      // Check subscription validity
      final wasValid = _isSubscriptionValid(business);
      final isNowValid = _checkSubscriptionValidity(
        tier: subscriptionTier,
        isActive: isSubscriptionActive,
        endDate: subscriptionEndDateRaw,
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
      if (isSubscriptionActive && subscriptionEndDateRaw != null) {
        await _checkExpirationWarning(
          userId: userId,
          businessId: business.id,
          businessName: business.name,
          endDateRaw: subscriptionEndDateRaw,
        );
      }

      // Update local cache with latest subscription info
      if (wasValid != isNowValid) {
        _log.info('Updating cache for business: ${business.id}');
        await _updateBusinessSubscriptionCache(
          userId,
          business.id,
          subscriptionTier,
          isSubscriptionActive,
          subscriptionEndDateRaw,
        );
      }
    } catch (e) {
      _log.error('Error checking business subscription: ${business.id}',
          error: e);
    }
  }

  /// Check if subscription expires in next 7 days (and issue milestones)
  Future<void> _checkExpirationWarning({
    required String userId,
    required String businessId,
    required String businessName,
    required dynamic endDateRaw,
  }) async {
    try {
      final endDate = parseTimestamp(endDateRaw);
      final now = DateTime.now();
      final daysLeft =
          SubscriptionService.daysUntilSubscriptionEnd(endDate, now: now);

      if (daysLeft < 0) {
        // Already expired; nothing to do here (handled elsewhere)
        return;
      }

      final milestone = SubscriptionService.calculateReminderMilestone(
        now: now,
        endDate: endDate,
      );

      if (milestone != null) {
        _log.warn(
            'Subscription expiring in $daysLeft days for business: $businessId');

        // Avoid repeating same milestone notifications repeatedly
        final lastSent = _lastReminderMilestoneSent[businessId];
        final dateKey =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final reminderKey = '$milestone:$dateKey';
        if (lastSent != milestone ||
            _lastReminderDateKeyByBusiness[businessId] != reminderKey) {
          _lastReminderMilestoneSent[businessId] = milestone;
          _lastReminderDateKeyByBusiness[businessId] = reminderKey;
          onSubscriptionExpiringSoon?.call(businessId, milestone);

          final milestoneLabel =
              SubscriptionService.reminderMilestoneLabel(milestone);
          onSubscriptionRenewalReminder?.call(
            businessId,
            milestone,
            milestoneLabel,
          );
          await _deliverRenewalReminder(
            userId: userId,
            businessId: businessId,
            businessName: businessName,
            daysLeft: milestone,
            milestoneLabel: milestoneLabel,
          );
        }
      }
    } catch (e) {
      _log.error('Error parsing expiration date: $endDateRaw', error: e);
    }
  }

  Future<void> _deliverRenewalReminder({
    required String userId,
    required String businessId,
    required String businessName,
    required int daysLeft,
    required String milestoneLabel,
  }) async {
    final title = 'Subscription renewal reminder';
    final body =
        '$businessName has $milestoneLabel left before renewal is required.';
    final notificationId =
        (businessId.hashCode ^ daysLeft.hashCode) & 0x7fffffff;

    try {
      await NotificationService.instance.sendNotification(
        title,
        body,
        id: notificationId,
      );
    } catch (e) {
      _log.error('Failed to send local renewal reminder', error: e);
    }

    try {
      await ManagecareApiClient.instance.post('/api/push/send', body: {
        'user_id': userId,
        'title': title,
        'body': body,
        'type': 'subscription_renewal_reminder',
        'data': {
          'businessId': businessId,
          'businessName': businessName,
          'daysLeft': daysLeft,
          'milestoneLabel': milestoneLabel,
        },
      });
    } catch (e) {
      _log.error('Failed to save renewal reminder notification', error: e);
    }
  }

  /// Update cached subscription info
  Future<void> _updateBusinessSubscriptionCache(
    String userId,
    String businessId,
    String subscriptionTier,
    bool isSubscriptionActive,
    dynamic subscriptionEndDate,
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
        subscriptionTier: subscriptionTier,
        businessClass: cachedBusiness.businessClass,
        isSubscriptionActive: isSubscriptionActive,
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
      final tier = SubscriptionService.normalizeStoredPlanLevel(
        subscriptionTier: business.subscriptionTier,
        subscriptionPlan: business.subscriptionPlan,
        businessClass: business.businessClass,
      );
      final hasAccess = SubscriptionService.hasFeatureAccess(
        businessType: business.businessType,
        tierId: tier,
        feature: feature,
      );
      final requiredTier = SubscriptionService.getRequiredTierForFeature(
        feature,
        businessType: business.businessType,
      );
      final reason = hasAccess || requiredTier == null
          ? null
          : 'Requires ${requiredTier.toUpperCase()} or higher';

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
    final normalizedTier = SubscriptionService.normalizeStoredPlanLevel(
      subscriptionTier: business.subscriptionTier,
      subscriptionPlan: business.subscriptionPlan,
      businessClass: business.businessClass,
    );

    return SubscriptionStatus(
      businessId: business.id,
      businessName: business.name,
      tier: normalizedTier,
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
    return SubscriptionService.isWithinSubscriptionAccessWindow(
      business.subscriptionEndDate!,
    );
  }

  bool _checkSubscriptionValidity({
    required String tier,
    required bool isActive,
    required dynamic endDate,
  }) {
    if (!isActive) return false;
    if (endDate == null) return true;
    try {
      return SubscriptionService.isWithinSubscriptionAccessWindow(
        parseTimestamp(endDate),
      );
    } catch (e) {
      _log.error('Error parsing end date: $endDate', error: e);
      return false;
    }
  }

  int? _getDaysUntilExpiration(BusinessModel business) {
    if (business.subscriptionEndDate == null) return null;
    return SubscriptionService.daysUntilSubscriptionEnd(
      business.subscriptionEndDate!,
    );
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

