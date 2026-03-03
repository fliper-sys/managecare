import 'package:flutter/material.dart';
import '../data/models/business_model.dart';
import 'background_subscription_checker.dart';

/// Feature guard with subscription enforcement
/// Prevents unauthorized access to features based on subscription tier
class SubscriptionFeatureGuard {
  final BackgroundSubscriptionChecker _subscriptionChecker;

  // Feature access logs for debugging
  final List<FeatureAccessLog> _accessLogs = [];

  static const int _maxLogs = 1000;
  final _log = _FeatureGuardLogger();

  SubscriptionFeatureGuard({
    required BackgroundSubscriptionChecker subscriptionChecker,
  }) : _subscriptionChecker = subscriptionChecker;

  /// Check if feature is available and log access attempt
  Future<bool> canAccessFeature({
    required BusinessModel business,
    required String feature,
    required String context, // e.g., 'email_receipt_screen', 'api_call'
    String? userRole,
  }) async {
    try {
      // Workers are exempt from subscription checks
      if (userRole != null && userRole.toLowerCase() == 'worker') {
        _logAccess(
          businessId: business.id,
          feature: feature,
          context: context,
          granted: true,
          reason: 'Worker accounts exempt from subscription checks',
        );
        return true;
      }

      final result = await _subscriptionChecker.validateFeatureAccess(business, feature);
      final canAccess = result['ok'] as bool? ?? false;
      final reason = result['message'] as String?;

      // Log access attempt
      _logAccess(
        businessId: business.id,
        feature: feature,
        context: context,
        granted: canAccess,
        reason: reason,
      );

      return canAccess;
    } catch (e) {
      _log.error('Error checking feature access', error: e);
      _logAccess(
        businessId: business.id,
        feature: feature,
        context: context,
        granted: false,
        reason: 'Error checking access: $e',
      );
      return false;
    }
  }

  /// Assert feature access and throw if denied
  /// Use this for critical feature access points
  Future<void> assertFeatureAccess({
    required BusinessModel business,
    required String feature,
    required String context,
    String? userRole,
  }) async {
    final canAccess = await canAccessFeature(
      business: business,
      feature: feature,
      context: context,
      userRole: userRole,
    );

    if (!canAccess) {
      final status = _subscriptionChecker.getSubscriptionStatus(business);
      throw FeatureAccessDeniedException(
        feature: feature,
        tier: status.tier,
        message: 'Feature "$feature" not available in ${status.tier} tier',
        statusMessage: status.statusMessage,
      );
    }
  }

  /// Get feature availability for all tiers
  Map<String, Map<String, bool>> getFeatureMatrix() {
    const tiers = ['free', 'basic', 'pro', 'professional', 'enterprise', 'tier3'];
    const features = [
      // Basic
      'basic_sales',
      'product_management',
      'basic_reports',
      // Basic+
      'unlimited_workers',
      'advanced_analytics',
      'email_receipts',
      'sms_notifications',
      // Pro
      'multi_location',
      'api_access',
      'payment_processing',
      'custom_reports',
      'priority_support',
      'receipt_customization',
      // Enterprise
      'white_label',
      'sso_login',
      'dedicated_support',
      'custom_development',
      'api_advanced',
    ];

    final matrix = <String, Map<String, bool>>{};

    for (final tier in tiers) {
      matrix[tier] = {};
      for (final feature in features) {
        // Check if this tier meets the feature requirement
        final requirement = getFeatureTierRequirement(feature);
        final tierHierarchy = {
          'free': 0,
          'basic': 1,
          'starter': 1,
          'pro': 2,
          'professional': 2,
          'enterprise': 3,
          'tier1': 1,
          'tier2': 2,
          'tier3': 3,
        };

        final tierLevel = tierHierarchy[tier.toLowerCase()] ?? 0;
        final requirementLevel = tierHierarchy[requirement?.toLowerCase()] ?? 0;
        final hasAccess = tierLevel >= requirementLevel;

        matrix[tier]![feature] = hasAccess;
      }
    }

    return matrix;
  }

  /// Get feature tier requirement
  String? getFeatureTierRequirement(String feature) {
    const requirements = {
      // Free
      'basic_sales': 'free',
      'product_management': 'free',
      'basic_reports': 'free',
      // Basic
      'unlimited_workers': 'basic',
      'advanced_analytics': 'basic',
      'email_receipts': 'basic',
      'sms_notifications': 'basic',
      // Pro
      'multi_location': 'pro',
      'api_access': 'pro',
      'payment_processing': 'pro',
      'custom_reports': 'pro',
      'priority_support': 'pro',
      'receipt_customization': 'pro',
      // Enterprise
      'white_label': 'tier3',
      'sso_login': 'tier3',
      'dedicated_support': 'tier3',
      'custom_development': 'tier3',
      'api_advanced': 'tier3',
    };
    return requirements[feature];
  }

  /// Check if user needs upgrade
  bool needsUpgrade({
    required BusinessModel business,
    required String feature,
    String? userRole,
  }) {
    // Workers never need to upgrade
    if (userRole != null && userRole.toLowerCase() == 'worker') return false;

    final status = _subscriptionChecker.getSubscriptionStatus(business);

    if (!status.isValid) return true; // Subscription expired/inactive

    final requirement = getFeatureTierRequirement(feature);
    if (requirement == null) return false;

    final tierHierarchy = {
      'free': 0,
      'basic': 1,
      'starter': 1,
      'pro': 2,
      'professional': 2,
      'enterprise': 3,
      'tier1': 1,
      'tier2': 2,
      'tier3': 3,
    };

    final userTierLevel = tierHierarchy[status.tier.toLowerCase()] ?? 0;
    final requiredTierLevel = tierHierarchy[requirement] ?? 0;

    return userTierLevel < requiredTierLevel;
  }

  /// Get upgrade path for a feature
  UpgradePath getUpgradePath({
    required BusinessModel business,
    required String feature,
    String? userRole,
  }) {
    // Workers do not need upgrade paths
    if (userRole != null && userRole.toLowerCase() == 'worker') {
      return UpgradePath(
        feature: feature,
        currentTier: 'free',
        requiredTier: 'none',
        message: 'Workers are exempt from subscription upgrades',
        needsAction: false,
        daysUntilExpiration: null,
      );
    }

    final status = _subscriptionChecker.getSubscriptionStatus(business);
    final requirement = getFeatureTierRequirement(feature);

    return UpgradePath(
      feature: feature,
      currentTier: status.tier,
      requiredTier: requirement ?? 'unknown',
      message: _buildUpgradeMessage(status.tier, requirement),
      needsAction: status.needsAction,
      daysUntilExpiration: status.daysUntilExpiration,
    );
  }

  /// Get access logs for debugging
  List<FeatureAccessLog> getAccessLogs({
    String? businessId,
    String? feature,
    int limit = 100,
  }) {
    var logs = _accessLogs;

    if (businessId != null) {
      logs = logs.where((l) => l.businessId == businessId).toList();
    }

    if (feature != null) {
      logs = logs.where((l) => l.feature == feature).toList();
    }

    return logs.reversed.take(limit).toList();
  }

  /// Clear access logs
  void clearAccessLogs() {
    _log.info('Clearing ${_accessLogs.length} access logs');
    _accessLogs.clear();
  }

  /// Export access logs for analysis
  List<Map<String, dynamic>> exportAccessLogs() {
    return _accessLogs.map((log) => log.toJson()).toList();
  }

  // Private helpers

  void _logAccess({
    required String businessId,
    required String feature,
    required String context,
    required bool granted,
    required String? reason,
  }) {
    final log = FeatureAccessLog(
      timestamp: DateTime.now(),
      businessId: businessId,
      feature: feature,
      context: context,
      granted: granted,
      reason: reason,
    );

    _accessLogs.add(log);

    // Keep log size manageable
    if (_accessLogs.length > _maxLogs) {
      _accessLogs.removeRange(0, _accessLogs.length - _maxLogs);
    }

    _log.debug(
      'Feature access: $feature (${granted ? 'GRANTED' : 'DENIED'}) '
      'in $context${reason != null ? ' - $reason' : ''}',
    );
  }

  String _buildUpgradeMessage(String currentTier, String? requiredTier) {
    if (requiredTier == null) return 'Feature not available';
    if (currentTier.toLowerCase() == requiredTier.toLowerCase()) {
      return 'Your subscription has expired. Please renew to access this feature.';
    }
    return 'This feature is available in $requiredTier tier. Upgrade now to access it.';
  }
}

/// Feature access log entry
class FeatureAccessLog {
  final DateTime timestamp;
  final String businessId;
  final String feature;
  final String context;
  final bool granted;
  final String? reason;

  FeatureAccessLog({
    required this.timestamp,
    required this.businessId,
    required this.feature,
    required this.context,
    required this.granted,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'businessId': businessId,
      'feature': feature,
      'context': context,
      'granted': granted,
      'reason': reason,
    };
  }

  @override
  String toString() => '[${timestamp.toIso8601String()}] $feature ($context): '
      '${granted ? 'GRANTED' : 'DENIED'}${reason != null ? ' ($reason)' : ''}';
}

/// Upgrade path information
class UpgradePath {
  final String feature;
  final String currentTier;
  final String requiredTier;
  final String message;
  final bool needsAction;
  final int? daysUntilExpiration;

  UpgradePath({
    required this.feature,
    required this.currentTier,
    required this.requiredTier,
    required this.message,
    required this.needsAction,
    required this.daysUntilExpiration,
  });

  bool get needsImmediateRenewal =>
      daysUntilExpiration != null && daysUntilExpiration! <= 0;

  bool get needsUrgentAction =>
      (daysUntilExpiration != null && daysUntilExpiration! <= 3) ||
      needsImmediateRenewal;
}

/// Exception thrown when feature access is denied
class FeatureAccessDeniedException implements Exception {
  final String feature;
  final String tier;
  final String message;
  final String statusMessage;

  FeatureAccessDeniedException({
    required this.feature,
    required this.tier,
    required this.message,
    required this.statusMessage,
  });

  @override
  String toString() =>
      'FeatureAccessDenied: $message (tier: $tier, feature: $feature)';
}

/// Logger for feature guard
class _FeatureGuardLogger {
  static const String _prefix = '[SubscriptionFeatureGuard]';

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

