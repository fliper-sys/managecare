import 'dart:async';

import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/user_model.dart';
import 'email_service.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final int durationInDays;
  final List<String> features;
  final String tierId;
  final String businessFamily;
  final String billingLabel;
  final Map<String, int?> limits;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationInDays,
    required this.features,
    required this.tierId,
    required this.businessFamily,
    required this.billingLabel,
    this.limits = const {},
  });
}

class SubscriptionService {
  static const int subscriptionGracePeriodDays = 7;
  static const List<int> subscriptionReminderMilestones = [30, 15, 7, 3];

  final FirebaseFirestore _firestore;
  final EmailService _emailService;

  static const String familyStandard = 'standard';
  static const String familyKitchen = 'kitchen';
  static const String familyLounge = 'lounge';
  static const String familyHospitality = 'hospitality';

  static const Map<String, int> _tierRanks = {
    'free': 0,
    'tier1': 1,
    'tier2': 2,
    'tier3': 3,
    'unlimited': 4,
  };

  static SubscriptionPlan _plan({
    required String family,
    required String tier,
    required String durationCode,
    required double price,
    required int days,
    required List<String> features,
    required Map<String, int?> limits,
  }) {
    return SubscriptionPlan(
      id: '${family}_${tier}_$durationCode',
      name:
          '${_familyLabel(family)} ${_tierLabel(tier)} (${_billingLabel(durationCode)})',
      price: price,
      durationInDays: days,
      features: features,
      tierId: tier,
      businessFamily: family,
      billingLabel: _billingLabel(durationCode),
      limits: limits,
    );
  }

  static String _familyLabel(String family) {
    switch (family) {
      case familyKitchen:
        return 'Kitchen';
      case familyLounge:
        return 'Lounge';
      case familyHospitality:
        return 'Hospitality';
      default:
        return 'Standard';
    }
  }

  static String _tierLabel(String tier) {
    switch (tier) {
      case 'tier1':
        return 'Tier 1';
      case 'tier2':
        return 'Tier 2';
      case 'tier3':
        return 'Tier 3';
      default:
        return 'Unlimited';
    }
  }

  static String _billingLabel(String durationCode) {
    switch (durationCode) {
      case '3m':
        return '3 months';
      case '6m':
        return '6 months';
      case '12m':
        return '12 months';
      default:
        return 'monthly';
    }
  }

  static final List<SubscriptionPlan> plans = [
    _plan(
        family: familyStandard,
        tier: 'tier1',
        durationCode: '3m',
        price: 23750.0,
        days: 90,
        features: ['1 store', '300 products', '3 workers'],
        limits: {'products': 300, 'workers': 3, 'locations': 1, 'branches': 0}),
    _plan(
        family: familyStandard,
        tier: 'tier1',
        durationCode: '6m',
        price: 42750.0,
        days: 180,
        features: ['1 store', '300 products', '3 workers'],
        limits: {'products': 300, 'workers': 3, 'locations': 1, 'branches': 0}),
    _plan(
        family: familyStandard,
        tier: 'tier1',
        durationCode: '12m',
        price: 76950.0,
        days: 365,
        features: ['1 store', '300 products', '3 workers'],
        limits: {'products': 300, 'workers': 3, 'locations': 1, 'branches': 0}),
    _plan(
        family: familyStandard,
        tier: 'tier2',
        durationCode: '3m',
        price: 32050.0,
        days: 90,
        features: ['1 branch', '700 products', '5 workers'],
        limits: {'products': 700, 'workers': 5, 'locations': 2, 'branches': 1}),
    _plan(
        family: familyStandard,
        tier: 'tier2',
        durationCode: '6m',
        price: 53780.0,
        days: 180,
        features: ['1 branch', '700 products', '5 workers'],
        limits: {'products': 700, 'workers': 5, 'locations': 2, 'branches': 1}),
    _plan(
        family: familyStandard,
        tier: 'tier2',
        durationCode: '12m',
        price: 87450.0,
        days: 365,
        features: ['1 branch', '700 products', '5 workers'],
        limits: {'products': 700, 'workers': 5, 'locations': 2, 'branches': 1}),
    _plan(
        family: familyStandard,
        tier: 'tier3',
        durationCode: '3m',
        price: 37900.0,
        days: 90,
        features: [
          '2 branches',
          '1000 products',
          '10 workers'
        ],
        limits: {
          'products': 1000,
          'workers': 10,
          'locations': 3,
          'branches': 2
        }),
    _plan(
        family: familyStandard,
        tier: 'tier3',
        durationCode: '6m',
        price: 64650.0,
        days: 180,
        features: [
          '2 branches',
          '1000 products',
          '10 workers'
        ],
        limits: {
          'products': 1000,
          'workers': 10,
          'locations': 3,
          'branches': 2
        }),
    _plan(
        family: familyStandard,
        tier: 'tier3',
        durationCode: '12m',
        price: 97900.0,
        days: 365,
        features: [
          '2 branches',
          '1000 products',
          '10 workers'
        ],
        limits: {
          'products': 1000,
          'workers': 10,
          'locations': 3,
          'branches': 2
        }),
    _plan(
        family: familyStandard,
        tier: 'unlimited',
        durationCode: 'monthly',
        price: 25000.0,
        days: 30,
        features: [
          'Unlimited products',
          'Unlimited workers',
          'Unlimited branches'
        ],
        limits: {
          'products': null,
          'workers': null,
          'locations': null,
          'branches': null
        }),
    _plan(
        family: familyStandard,
        tier: 'unlimited',
        durationCode: '3m',
        price: 70000.0,
        days: 90,
        features: [
          'Unlimited products',
          'Unlimited workers',
          'Unlimited branches'
        ],
        limits: {
          'products': null,
          'workers': null,
          'locations': null,
          'branches': null
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier1',
        durationCode: '3m',
        price: 23750.0,
        days: 90,
        features: [
          '10 tables',
          '15 meals',
          '15 inventory'
        ],
        limits: {
          'tables': 10,
          'workers': 5,
          'menu_items': 15,
          'inventory_products': 15,
          'locations': 1,
          'branches': 0
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier1',
        durationCode: '6m',
        price: 42750.0,
        days: 180,
        features: [
          '10 tables',
          '15 meals',
          '15 inventory'
        ],
        limits: {
          'tables': 10,
          'workers': 5,
          'menu_items': 15,
          'inventory_products': 15,
          'locations': 1,
          'branches': 0
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier1',
        durationCode: '12m',
        price: 76950.0,
        days: 365,
        features: [
          '10 tables',
          '15 meals',
          '15 inventory'
        ],
        limits: {
          'tables': 10,
          'workers': 5,
          'menu_items': 15,
          'inventory_products': 15,
          'locations': 1,
          'branches': 0
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier2',
        durationCode: '3m',
        price: 32050.0,
        days: 90,
        features: [
          '20 tables',
          '25 meals',
          '1 branch'
        ],
        limits: {
          'tables': 20,
          'workers': 10,
          'menu_items': 25,
          'inventory_products': 25,
          'locations': 2,
          'branches': 1
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier2',
        durationCode: '6m',
        price: 53780.0,
        days: 180,
        features: [
          '20 tables',
          '25 meals',
          '1 branch'
        ],
        limits: {
          'tables': 20,
          'workers': 10,
          'menu_items': 25,
          'inventory_products': 25,
          'locations': 2,
          'branches': 1
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier2',
        durationCode: '12m',
        price: 87450.0,
        days: 365,
        features: [
          '20 tables',
          '25 meals',
          '1 branch'
        ],
        limits: {
          'tables': 20,
          'workers': 10,
          'menu_items': 25,
          'inventory_products': 25,
          'locations': 2,
          'branches': 1
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier3',
        durationCode: '3m',
        price: 37900.0,
        days: 90,
        features: [
          '35 tables',
          'VIP section',
          '2 branches'
        ],
        limits: {
          'tables': 35,
          'workers': 15,
          'menu_items': 35,
          'inventory_products': 40,
          'locations': 3,
          'branches': 2
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier3',
        durationCode: '6m',
        price: 64650.0,
        days: 180,
        features: [
          '35 tables',
          'VIP section',
          '2 branches'
        ],
        limits: {
          'tables': 35,
          'workers': 15,
          'menu_items': 35,
          'inventory_products': 40,
          'locations': 3,
          'branches': 2
        }),
    _plan(
        family: familyKitchen,
        tier: 'tier3',
        durationCode: '12m',
        price: 97900.0,
        days: 365,
        features: [
          '35 tables',
          'VIP section',
          '2 branches'
        ],
        limits: {
          'tables': 35,
          'workers': 15,
          'menu_items': 35,
          'inventory_products': 40,
          'locations': 3,
          'branches': 2
        }),
    _plan(
        family: familyKitchen,
        tier: 'unlimited',
        durationCode: 'monthly',
        price: 25000.0,
        days: 30,
        features: [
          'Unlimited access',
          'Unlimited tables',
          'Unlimited inventory'
        ],
        limits: {
          'tables': null,
          'workers': null,
          'menu_items': null,
          'inventory_products': null,
          'locations': null,
          'branches': null
        }),
    _plan(
        family: familyKitchen,
        tier: 'unlimited',
        durationCode: '3m',
        price: 67500.0,
        days: 90,
        features: [
          'Unlimited access',
          'Unlimited tables',
          'Unlimited inventory'
        ],
        limits: {
          'tables': null,
          'workers': null,
          'menu_items': null,
          'inventory_products': null,
          'locations': null,
          'branches': null
        }),
    _plan(
        family: familyLounge,
        tier: 'tier1',
        durationCode: 'monthly',
        price: 12850.0,
        days: 30,
        features: [
          '15 tables',
          '65 inventory',
          '7 workers'
        ],
        limits: {
          'tables': 15,
          'workers': 7,
          'inventory_products': 65,
          'locations': 1,
          'branches': 0
        }),
    _plan(
        family: familyLounge,
        tier: 'tier2',
        durationCode: 'monthly',
        price: 20560.0,
        days: 30,
        features: [
          '25 tables',
          '100 inventory',
          '1 branch'
        ],
        limits: {
          'tables': 25,
          'workers': 10,
          'inventory_products': 100,
          'locations': 2,
          'branches': 1
        }),
    _plan(
        family: familyLounge,
        tier: 'tier3',
        durationCode: 'monthly',
        price: 30840.0,
        days: 30,
        features: [
          '40 tables',
          '200 inventory',
          '2 branches'
        ],
        limits: {
          'tables': 40,
          'workers': 15,
          'inventory_products': 200,
          'locations': 3,
          'branches': 2
        }),
    _plan(
        family: familyLounge,
        tier: 'unlimited',
        durationCode: 'monthly',
        price: 37000.0,
        days: 30,
        features: [
          'Unlimited access',
          'Unlimited tables',
          'Unlimited inventory'
        ],
        limits: {
          'tables': null,
          'workers': null,
          'inventory_products': null,
          'locations': null,
          'branches': null
        }),
    _plan(
        family: familyHospitality,
        tier: 'tier1',
        durationCode: 'monthly',
        price: 14650.0,
        days: 30,
        features: [
          '15 rooms',
          '10 restaurant tables',
          '15 bar tables'
        ],
        limits: {
          'rooms': 15,
          'suites': 0,
          'workers': 7,
          'restaurant_tables': 10,
          'bar_tables': 15,
          'locations': 1,
          'branches': 0
        }),
    _plan(
        family: familyHospitality,
        tier: 'tier2',
        durationCode: 'monthly',
        price: 23350.0,
        days: 30,
        features: [
          '25 rooms + 5 suites',
          'Hall access',
          '1 branch'
        ],
        limits: {
          'rooms': 25,
          'suites': 5,
          'workers': 15,
          'restaurant_tables': 20,
          'bar_tables': 25,
          'locations': 2,
          'branches': 1
        }),
    _plan(
        family: familyHospitality,
        tier: 'tier3',
        durationCode: 'monthly',
        price: 35750.0,
        days: 30,
        features: [
          '40 rooms + 10 suites',
          'Pool access',
          '2 branches'
        ],
        limits: {
          'rooms': 40,
          'suites': 10,
          'workers': 25,
          'restaurant_tables': 30,
          'bar_tables': 35,
          'locations': 3,
          'branches': 2
        }),
    _plan(
        family: familyHospitality,
        tier: 'unlimited',
        durationCode: 'monthly',
        price: 45000.0,
        days: 30,
        features: [
          'Unlimited rooms',
          'Unlimited workers',
          'Unlimited features'
        ],
        limits: {
          'rooms': null,
          'suites': null,
          'workers': null,
          'restaurant_tables': null,
          'bar_tables': null,
          'locations': null,
          'branches': null
        }),
  ];

  SubscriptionService({
    required FirebaseFirestore firestore,
    EmailService? emailService,
  })  : _firestore = firestore,
        _emailService = emailService ?? EmailService();

  static String canonicalizeBusinessType(String? businessType) {
    final raw = (businessType ?? '').trim().toLowerCase();
    if (raw.isEmpty) return 'retail';
    final value = raw.contains('/') ? raw.split('/').last : raw;
    switch (value) {
      case 'agriculture':
      case 'farm':
      case 'farms':
        return 'agri';
      case 'auto_repair':
        return 'auto';
      case 'real_estate':
        return 'realestate';
      case 'bar':
        return 'drink';
      case 'guest_inn':
      case 'guest inn':
      case 'guesthouse':
      case 'lodge':
        return 'hotel';
      default:
        return value;
    }
  }

  static String getPlanFamilyForBusinessType(String? businessType) {
    switch (canonicalizeBusinessType(businessType)) {
      case 'restaurant':
      case 'kitchen':
        return familyKitchen;
      case 'drink':
      case 'lounge':
        return familyLounge;
      case 'hotel':
      case 'apartment':
        return familyHospitality;
      default:
        return familyStandard;
    }
  }

  static SubscriptionPlan? getPlanById(String planId) {
    final id = planId.trim().toLowerCase();
    if (id.isEmpty) return null;
    try {
      return plans.firstWhere((plan) => plan.id.toLowerCase() == id);
    } catch (_) {
      return null;
    }
  }

  static List<SubscriptionPlan> getPlansForBusinessType(String? businessType,
      {String? tierId}) {
    final family = getPlanFamilyForBusinessType(businessType);
    final normalizedTier = _normalizeTierId(tierId);
    final available = plans.where((plan) {
      if (plan.businessFamily != family) return false;
      if (normalizedTier != null && plan.tierId != normalizedTier) return false;
      return true;
    }).toList();
    available.sort((a, b) {
      final rankDiff = getTierRank(a.tierId) - getTierRank(b.tierId);
      if (rankDiff != 0) return rankDiff;
      return a.durationInDays - b.durationInDays;
    });
    return available;
  }

  static List<SubscriptionPlan> getPlansForBusinessTypeAndClass(
      String? businessType, String? businessClass) {
    return getPlansForBusinessType(
      businessType,
      tierId: normalizeStoredBusinessClass(businessClass: businessClass),
    );
  }

  static List<SubscriptionPlan> getPlansForClass(String? businessClass) {
    return getPlansForBusinessType(
      'retail',
      tierId: normalizeStoredBusinessClass(businessClass: businessClass),
    );
  }

  static List<String> getTierOptionsForBusinessType(String? businessType) {
    final family = getPlanFamilyForBusinessType(businessType);
    final tiers = <String>[];
    final seen = <String>{};
    for (final plan in plans.where((plan) => plan.businessFamily == family)) {
      if (seen.add(plan.tierId)) tiers.add(plan.tierId);
    }
    return tiers;
  }

  static String detectTier({
    required int products,
    required int staff,
    required double monthlyIncome,
    String? businessType,
  }) {
    return detectBusinessClass(
      products: products,
      staff: staff,
      monthlyIncome: monthlyIncome,
      businessType: businessType,
    );
  }

  static String detectBusinessClass({
    required int products,
    required int staff,
    required double monthlyIncome,
    String? businessType,
  }) {
    switch (getPlanFamilyForBusinessType(businessType)) {
      case familyKitchen:
        if (products <= 15 && staff <= 5) return 'tier1';
        if (products <= 25 && staff <= 10) return 'tier2';
        return 'tier3';
      case familyLounge:
        if (products <= 65 && staff <= 7) return 'tier1';
        if (products <= 100 && staff <= 10) return 'tier2';
        return 'tier3';
      case familyHospitality:
        if (staff <= 7 && monthlyIncome <= 1000000.0) return 'tier1';
        if (staff <= 15 && monthlyIncome <= 3000000.0) return 'tier2';
        return 'tier3';
      default:
        if (products <= 300 && staff <= 3) return 'tier1';
        if (products <= 700 && staff <= 5) return 'tier2';
        if (products > 1000) return 'unlimited';
        return 'tier3';
    }
  }

  static String getBusinessClassFromPlanId(String planId) {
    final plan = getPlanById(planId);
    return plan?.tierId ??
        normalizeStoredBusinessClass(subscriptionPlan: planId);
  }

  static String getPlanLevelFromPlanId(String planId) {
    final plan = getPlanById(planId);
    return plan?.tierId ?? normalizeStoredPlanLevel(subscriptionPlan: planId);
  }

  static int getTierRank(String? tierId) {
    return _tierRanks[_normalizeTierId(tierId) ?? 'free'] ?? 0;
  }

  static bool isTierAtLeast(String? tierId, String requiredTierId) {
    return getTierRank(tierId) >= getTierRank(requiredTierId);
  }

  static String normalizeStoredPlanLevel({
    String? subscriptionTier,
    String? subscriptionPlan,
    String? businessClass,
  }) {
    final plan = getPlanById(subscriptionPlan ?? '');
    if (plan != null) return plan.tierId;
    final tier = _normalizeTierId(subscriptionTier);
    if (tier != null) return tier;
    final klass = _normalizeTierId(businessClass);
    if (klass != null) return klass;
    final raw = (subscriptionTier ?? '').trim().toLowerCase();
    if (raw == 'basic' || raw == 'starter') return klass ?? 'tier1';
    if (raw == 'pro' || raw == 'professional' || raw == 'enterprise') {
      return klass ?? 'tier3';
    }
    return 'tier1';
  }

  static String normalizeStoredBusinessClass({
    String? businessClass,
    String? subscriptionPlan,
    String? subscriptionTier,
  }) {
    final plan = getPlanById(subscriptionPlan ?? '');
    if (plan != null) return plan.tierId;
    final klass = _normalizeTierId(businessClass);
    if (klass != null) return klass;
    final tier = _normalizeTierId(subscriptionTier);
    if (tier != null) return tier;
    final raw = (subscriptionTier ?? '').trim().toLowerCase();
    if (raw == 'basic' || raw == 'starter') return 'tier1';
    if (raw == 'pro' || raw == 'professional' || raw == 'enterprise')
      return 'tier3';
    return 'tier1';
  }

  static int? getLimitForBusinessType({
    required String? businessType,
    required String tierId,
    required String limitType,
  }) {
    final family = getPlanFamilyForBusinessType(businessType);
    final normalizedTier = normalizeStoredPlanLevel(subscriptionTier: tierId);
    SubscriptionPlan? selected;
    for (final plan in plans) {
      if (plan.businessFamily == family && plan.tierId == normalizedTier) {
        selected = plan;
        break;
      }
    }
    if (selected == null) return null;
    for (final key in _limitKeysForFamily(family, limitType)) {
      if (selected.limits.containsKey(key)) return selected.limits[key];
    }
    if (limitType == 'branches' && selected.limits.containsKey('locations')) {
      final locations = selected.limits['locations'];
      if (locations == null) return null;
      return locations <= 0 ? 0 : locations - 1;
    }
    return null;
  }

  static bool hasFeatureAccess({
    required String? businessType,
    required String tierId,
    required String feature,
  }) {
    final family = getPlanFamilyForBusinessType(businessType);
    final rank = getTierRank(tierId);
    switch (feature.trim().toLowerCase()) {
      case 'basic_sales':
      case 'product_management':
      case 'basic_reports':
        return true;
      case 'advanced_analytics':
      case 'email_receipts':
      case 'sms_notifications':
      case 'payment_processing':
      case 'receipt_customization':
        return rank >= getTierRank('tier1');
      case 'multi_location':
        return rank >= getTierRank('tier2');
      case 'priority_support':
      case 'custom_reports':
        return rank >= getTierRank('tier3');
      case 'vip_section':
        return (family == familyKitchen || family == familyLounge) &&
            rank >= getTierRank('tier3');
      case 'hall_booking':
      case 'hall_features':
      case 'hall_services':
        return family == familyHospitality && rank >= getTierRank('tier2');
      case 'pool_booking':
      case 'pool_features':
        return family == familyHospitality && rank >= getTierRank('tier3');
      case 'white_label':
      case 'sso_login':
      case 'dedicated_support':
      case 'custom_development':
      case 'api_access':
      case 'api_advanced':
        return rank >= getTierRank('unlimited');
      default:
        return true;
    }
  }

  static String? getRequiredTierForFeature(String feature,
      {String? businessType}) {
    final family = getPlanFamilyForBusinessType(businessType);
    switch (feature.trim().toLowerCase()) {
      case 'basic_sales':
      case 'product_management':
      case 'basic_reports':
        return 'free';
      case 'advanced_analytics':
      case 'email_receipts':
      case 'sms_notifications':
      case 'payment_processing':
      case 'receipt_customization':
        return 'tier1';
      case 'multi_location':
        return 'tier2';
      case 'priority_support':
      case 'custom_reports':
        return 'tier3';
      case 'vip_section':
        return (family == familyKitchen || family == familyLounge)
            ? 'tier3'
            : 'unlimited';
      case 'hall_booking':
      case 'hall_features':
      case 'hall_services':
        return family == familyHospitality ? 'tier2' : 'unlimited';
      case 'pool_booking':
      case 'pool_features':
        return family == familyHospitality ? 'tier3' : 'unlimited';
      case 'white_label':
      case 'sso_login':
      case 'dedicated_support':
      case 'custom_development':
      case 'api_access':
      case 'api_advanced':
        return 'unlimited';
      default:
        return null;
    }
  }

  static DateTime computeRenewalEndDate({
    DateTime? existingEnd,
    required int durationInDays,
    DateTime? now,
  }) {
    final nowRef = now ?? DateTime.now();
    final base = (existingEnd != null && existingEnd.isAfter(nowRef))
        ? existingEnd
        : nowRef;
    return base.add(Duration(days: durationInDays));
  }

  static bool isSubscriptionActive(UserModel user) {
    if (!user.isOwner) return true;
    if (!user.hasActiveSubscription || user.subscriptionEndDate == null) {
      return false;
    }
    return isWithinSubscriptionAccessWindow(user.subscriptionEndDate!);
  }

  static DateTime normalizeToDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool isWithinSubscriptionAccessWindow(
    DateTime endDate, {
    DateTime? now,
  }) {
    final today = normalizeToDate(now ?? DateTime.now());
    final graceEnds =
        normalizeToDate(endDate).add(const Duration(days: subscriptionGracePeriodDays));
    return !today.isAfter(graceEnds);
  }

  static int daysUntilSubscriptionEnd(DateTime endDate, {DateTime? now}) {
    final today = normalizeToDate(now ?? DateTime.now());
    return normalizeToDate(endDate).difference(today).inDays;
  }

  static int daysSinceSubscriptionEnd(DateTime endDate, {DateTime? now}) {
    final today = normalizeToDate(now ?? DateTime.now());
    return today.difference(normalizeToDate(endDate)).inDays;
  }

  static bool isInSubscriptionGracePeriod(DateTime endDate, {DateTime? now}) {
    final daysSinceEnd = daysSinceSubscriptionEnd(endDate, now: now);
    return daysSinceEnd >= 0 && daysSinceEnd <= subscriptionGracePeriodDays;
  }

  static int? calculateReminderMilestone({
    required DateTime now,
    required DateTime endDate,
  }) {
    final daysLeft = daysUntilSubscriptionEnd(endDate, now: now);
    return subscriptionReminderMilestones.contains(daysLeft) ? daysLeft : null;
  }

  static String reminderMilestoneLabel(int daysLeft) {
    switch (daysLeft) {
      case 30:
        return '30 days';
      case 15:
        return '15 days';
      case 7:
        return '1 week';
      case 3:
        return '3 days';
      default:
        return '$daysLeft day(s)';
    }
  }

  static String? _normalizeTierId(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    switch (raw) {
      case 't1':
      case 'tier1':
        return 'tier1';
      case 't2':
      case 'tier2':
        return 'tier2';
      case 't3':
      case 'tier3':
        return 'tier3';
      case 'unlimited':
      case 'unlimited_plan':
        return 'unlimited';
      default:
        return null;
    }
  }

  static List<String> _limitKeysForFamily(String family, String limitType) {
    switch (limitType) {
      case 'products':
        return family == familyKitchen || family == familyLounge
            ? ['inventory_products', 'menu_items', 'products']
            : ['products', 'inventory_products'];
      case 'tables':
        return family == familyHospitality
            ? ['restaurant_tables', 'bar_tables', 'tables']
            : ['tables'];
      case 'branches':
        return ['branches', 'locations'];
      default:
        return [limitType];
    }
  }

  Future<Map<String, dynamic>?> getUserSubscription(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      return {
        'hasActiveSubscription': data['hasActiveSubscription'] ?? false,
        'subscriptionPlan': data['subscriptionPlan'],
        'subscriptionTier': data['subscriptionTier'],
        'subscriptionStartDate': data['subscriptionStartDate'],
        'subscriptionEndDate': data['subscriptionEndDate'],
        'subscriptionPaymentRequired':
            data['subscriptionPaymentRequired'] ?? true,
        'subscriptionAmount': data['subscriptionAmount'],
        'subscriptionStatus': data['subscriptionStatus'],
        'currentBusinessId': data['currentBusinessId'],
      };
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBusinessSubscription(
      String businessId) async {
    try {
      final doc =
          await _firestore.collection('businesses').doc(businessId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'],
        'businessType': data['businessType'],
        'subscriptionPlan': data['subscriptionPlan'],
        'subscriptionTier': data['subscriptionTier'],
        'businessClass': data['businessClass'],
        'subscriptionFamily': data['subscriptionFamily'],
        'subscriptionStatus': data['subscriptionStatus'],
        'subscriptionReviewStatus': data['subscriptionReviewStatus'],
        'subscriptionStartDate': data['subscriptionStartDate'],
        'subscriptionEndDate': data['subscriptionEndDate'],
        'isSubscriptionActive': data['isSubscriptionActive'] ?? false,
        'pendingSubscriptionPlan': data['pendingSubscriptionPlan'],
      };
    } catch (e) {
      print('Error getting business subscription: $e');
      return null;
    }
  }

  Future<bool> submitManualSubscriptionForApproval({
    required String userId,
    required String planId,
    required String receiptUrl,
    required double amount,
    required String currency,
    required String userEmail,
    required String userName,
    String? businessId,
    String? existingRequestId,
    String paymentMethod = 'receipt',
    String? notes,
  }) async {
    try {
      final plan = getPlanById(planId);
      if (plan == null) return false;

      final now = DateTime.now();
      final requestId =
          existingRequestId ?? 'RCP_${userId}_${now.millisecondsSinceEpoch}';
      final businessData = businessId != null && businessId.isNotEmpty
          ? await getBusinessSubscription(businessId)
          : null;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final currentlyActive = businessId != null && businessId.isNotEmpty
          ? await validateAndUpdateBusinessSubscriptionStatus(
              businessId,
              userId: userId,
            )
          : (userData['hasActiveSubscription'] as bool? ?? false);

      await _firestore.collection('subscription_requests').doc(requestId).set({
        'uploadId': requestId,
        'userId': userId,
        'businessId': businessId ?? '',
        'businessType': businessData?['businessType'],
        'planId': plan.id,
        'planName': plan.name,
        'planTier': plan.tierId,
        'planFamily': plan.businessFamily,
        'amount': amount,
        'currency': currency,
        'userEmail': userEmail,
        'userName': userName,
        'receiptUrl': receiptUrl,
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'paymentProcessor': paymentMethod == 'receipt' ? null : paymentMethod,
        'processorTransactionId': null,
        'subscriptionStatus': 'pending_approval',
        'subscriptionAmount': amount,
        'subscriptionReceiptUrl': receiptUrl,
        'subscriptionPlan': plan.id,
        'notes': notes ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'requestDate': FieldValue.serverTimestamp(),
        'subscriptionRequestDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final userUpdate = <String, dynamic>{
        'subscriptionPlan': plan.id,
        'subscriptionTier': plan.tierId,
        'subscriptionAmount': amount,
        'subscriptionReceiptUrl': receiptUrl,
        'subscriptionPaymentRequired': true,
        'subscriptionRequestDate': now.toIso8601String(),
        'pendingSubscriptionPlan': plan.id,
        'pendingSubscriptionTier': plan.tierId,
        'pendingSubscriptionAmount': amount,
        'pendingSubscriptionReceiptUrl': receiptUrl,
        'pendingSubscriptionStatus': 'pending_approval',
        'pendingSubscriptionRequestedAt': now.toIso8601String(),
        'subscriptionBusinessId': businessId ?? userData['currentBusinessId'],
        'updatedAt': now.toIso8601String(),
      };

      if (businessId != null && businessId.isNotEmpty) {
        userUpdate['currentBusinessId'] = businessId;
      }
      if (!currentlyActive) {
        userUpdate['hasActiveSubscription'] = false;
        userUpdate['subscriptionStatus'] = 'pending_approval';
      }

      await _firestore.collection('users').doc(userId).set(
            userUpdate,
            SetOptions(merge: true),
          );

      if (businessId != null && businessId.isNotEmpty) {
        await _firestore.collection('businesses').doc(businessId).set({
          'pendingSubscriptionPlan': plan.id,
          'pendingSubscriptionTier': plan.tierId,
          'pendingBusinessClass': plan.tierId,
          'pendingSubscriptionAmount': amount,
          'pendingSubscriptionReceiptUrl': receiptUrl,
          'subscriptionRequestDate': now.toIso8601String(),
          'subscriptionStatus': currentlyActive ? 'active' : 'pending_approval',
          'subscriptionReviewStatus':
              currentlyActive ? 'active' : 'pending_approval',
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));
      }

      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'businessId': businessId,
        'action': 'subscription_submitted_for_approval',
        'planId': plan.id,
        'planTier': plan.tierId,
        'planFamily': plan.businessFamily,
        'amount': amount,
        'receiptUrl': receiptUrl,
        'paymentMethod': paymentMethod,
        'createdAt': now.toIso8601String(),
      });

      unawaited(
        _sendSubscriptionStatusEmailSafe(
          userId: userId,
          userEmail: userEmail,
          userName: userName,
          plan: plan,
          amount: amount,
          statusLabel: 'Pending Approval',
          statusMessage:
              'We received your payment proof and submitted your subscription request for approval.',
          requestId: requestId,
          businessId: businessId,
        ),
      );

      return true;
    } catch (e) {
      print('Error submitting subscription for approval: $e');
      return false;
    }
  }

  Future<bool> createSubscription({
    required String userId,
    required String planId,
    required String transactionId,
    required double amount,
    String? businessId,
  }) async {
    return activateOrRenewSubscription(
      userId: userId,
      planId: planId,
      receiptUrl: transactionId,
      amount: amount,
      businessId: businessId,
    );
  }

  Future<bool> renewSubscription({
    required String userId,
    required String planId,
    required String transactionId,
    required double amount,
    String? businessId,
  }) async {
    return activateOrRenewSubscription(
      userId: userId,
      planId: planId,
      receiptUrl: transactionId,
      amount: amount,
      businessId: businessId,
    );
  }

  Future<bool> expireSubscription(String userId, {String? businessId}) async {
    try {
      final now = DateTime.now();
      final plan = await _resolvePlanForNotification(userId, businessId) ??
          _fallbackNotificationPlan();
      await _firestore.collection('users').doc(userId).set({
        'hasActiveSubscription': false,
        'subscriptionPaymentRequired': true,
        'subscriptionStatus': 'expired',
        'updatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      if (businessId != null && businessId.isNotEmpty) {
        await _firestore.collection('businesses').doc(businessId).set({
          'isSubscriptionActive': false,
          'subscriptionStatus': 'expired',
          'subscriptionReviewStatus': 'expired',
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));
      }

      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'businessId': businessId,
        'action': 'subscription_expired',
        'createdAt': now.toIso8601String(),
      });

      unawaited(
        _sendSubscriptionStatusEmailSafe(
          userId: userId,
          plan: plan,
          amount: 0,
          statusLabel: 'Expired',
          statusMessage:
              'Your business subscription has expired. Renew it to continue using paid features without interruption.',
          businessId: businessId,
        ),
      );
      return true;
    } catch (e) {
      print('Error expiring subscription: $e');
      return false;
    }
  }

  Future<bool> cancelSubscription(String userId, {String? businessId}) async {
    try {
      final now = DateTime.now();
      final plan = await _resolvePlanForNotification(userId, businessId) ??
          _fallbackNotificationPlan();
      await _firestore.collection('users').doc(userId).set({
        'hasActiveSubscription': false,
        'subscriptionPaymentRequired': false,
        'subscriptionStatus': 'cancelled',
        'updatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      if (businessId != null && businessId.isNotEmpty) {
        await _firestore.collection('businesses').doc(businessId).set({
          'isSubscriptionActive': false,
          'subscriptionStatus': 'cancelled',
          'subscriptionReviewStatus': 'cancelled',
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));
      }

      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'businessId': businessId,
        'action': 'subscription_cancelled',
        'createdAt': now.toIso8601String(),
      });

      unawaited(
        _sendSubscriptionStatusEmailSafe(
          userId: userId,
          plan: plan,
          amount: 0,
          statusLabel: 'Cancelled',
          statusMessage:
              'Your subscription has been cancelled. You can reactivate a plan at any time from the subscription screen.',
          businessId: businessId,
        ),
      );
      return true;
    } catch (e) {
      print('Error cancelling subscription: $e');
      return false;
    }
  }

  Future<bool> validateAndUpdateSubscriptionStatus(
    String userId, {
    String? businessId,
  }) async {
    try {
      final resolvedBusinessId = businessId?.trim().isNotEmpty == true
          ? businessId!.trim()
          : await _resolveBusinessIdForUser(userId);

      if (resolvedBusinessId != null && resolvedBusinessId.isNotEmpty) {
        return validateAndUpdateBusinessSubscriptionStatus(
          resolvedBusinessId,
          userId: userId,
        );
      }

      final subscription = await getUserSubscription(userId);
      if (subscription == null) return false;
      if (subscription['hasActiveSubscription'] == true &&
          subscription['subscriptionEndDate'] != null) {
        final endDate = parseTimestamp(subscription['subscriptionEndDate']);
        if (!isWithinSubscriptionAccessWindow(endDate)) {
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

  Future<bool> validateAndUpdateBusinessSubscriptionStatus(
    String businessId, {
    String? userId,
  }) async {
    try {
      if (businessId.trim().isEmpty) return false;
      final business = await getBusinessSubscription(businessId);
      if (business == null) return false;

      final now = DateTime.now();
      final isActive = business['isSubscriptionActive'] as bool? ?? false;
      final endRaw = business['subscriptionEndDate'];
      final endDate = endRaw != null ? parseTimestamp(endRaw) : null;
      final isValid = isActive &&
          (endDate == null || isWithinSubscriptionAccessWindow(endDate, now: now));

      if (isActive && endDate != null && !isWithinSubscriptionAccessWindow(endDate, now: now)) {
        await _firestore.collection('businesses').doc(businessId).set({
          'isSubscriptionActive': false,
          'subscriptionStatus': 'expired',
          'subscriptionReviewStatus': 'expired',
          'updatedAt': now.toIso8601String(),
        }, SetOptions(merge: true));
      }

      if (userId != null && userId.isNotEmpty) {
        await syncUserSubscriptionSummaryFromBusiness(
          userId: userId,
          businessId: businessId,
          overrideIsActive: isValid,
          overrideStatus: isValid ? 'approved' : 'expired',
        );
      }

      return isValid;
    } catch (e) {
      print('Error validating business subscription status: $e');
      return false;
    }
  }

  Future<bool> activateSubscriptionImmediately({
    required String userId,
    required String planId,
    required String receiptUrl,
    required double amount,
    String? businessId,
  }) async {
    try {
      final plan = getPlanById(planId);
      if (plan == null) return false;

      final now = DateTime.now();
      final endDate = now.add(Duration(days: plan.durationInDays));
      final targetBusinessId = businessId?.trim().isNotEmpty == true
          ? businessId!.trim()
          : await _resolveBusinessIdForUser(userId);

      await _writeUserSubscriptionSummary(
        userId: userId,
        businessId: targetBusinessId,
        plan: plan,
        startDate: now,
        endDate: endDate,
        amount: amount,
        receiptUrl: receiptUrl,
        status: 'approved',
        isActive: true,
      );

      if (targetBusinessId != null && targetBusinessId.isNotEmpty) {
        await syncSubscriptionToBusiness(
          businessId: targetBusinessId,
          planId: plan.id,
          startDate: now,
          endDate: endDate,
          amount: amount,
          receiptUrl: receiptUrl,
        );
      }

      unawaited(
        _sendSubscriptionStatusEmailSafe(
          userId: userId,
          plan: plan,
          amount: amount,
          statusLabel: 'Active',
          statusMessage:
              'Your payment was confirmed and your subscription is now active.',
          businessId: targetBusinessId,
          startsOn: now,
          endsOn: endDate,
        ),
      );

      return true;
    } catch (e) {
      print('[SubscriptionService] Error activating subscription: $e');
      return false;
    }
  }

  Future<bool> activateOrRenewSubscription({
    required String userId,
    required String planId,
    required String receiptUrl,
    required double amount,
    String? businessId,
  }) async {
    try {
      final plan = getPlanById(planId);
      if (plan == null) return false;

      final now = DateTime.now();
      final targetBusinessId = businessId?.trim().isNotEmpty == true
          ? businessId!.trim()
          : await _resolveBusinessIdForUser(userId);

      DateTime? existingStart;
      DateTime? existingEnd;

      if (targetBusinessId != null && targetBusinessId.isNotEmpty) {
        final existingBusiness =
            await getBusinessSubscription(targetBusinessId);
        if (existingBusiness != null) {
          try {
            if (existingBusiness['subscriptionStartDate'] != null) {
              existingStart =
                  parseTimestamp(existingBusiness['subscriptionStartDate']);
            }
          } catch (_) {}
          try {
            if (existingBusiness['subscriptionEndDate'] != null) {
              existingEnd =
                  parseTimestamp(existingBusiness['subscriptionEndDate']);
            }
          } catch (_) {}
        }
      } else {
        final existingUser = await getUserSubscription(userId);
        if (existingUser != null) {
          try {
            if (existingUser['subscriptionStartDate'] != null) {
              existingStart =
                  parseTimestamp(existingUser['subscriptionStartDate']);
            }
          } catch (_) {}
          try {
            if (existingUser['subscriptionEndDate'] != null) {
              existingEnd = parseTimestamp(existingUser['subscriptionEndDate']);
            }
          } catch (_) {}
        }
      }

      final startDate = existingStart ?? now;
      final newEndDate = computeRenewalEndDate(
        existingEnd: existingEnd,
        durationInDays: plan.durationInDays,
        now: now,
      );

      await _writeUserSubscriptionSummary(
        userId: userId,
        businessId: targetBusinessId,
        plan: plan,
        startDate: startDate,
        endDate: newEndDate,
        amount: amount,
        receiptUrl: receiptUrl,
        status: 'approved',
        isActive: true,
      );

      if (targetBusinessId != null && targetBusinessId.isNotEmpty) {
        await syncSubscriptionToBusiness(
          businessId: targetBusinessId,
          planId: plan.id,
          startDate: startDate,
          endDate: newEndDate,
          amount: amount,
          receiptUrl: receiptUrl,
        );
      }

      final action = (existingEnd != null && existingEnd.isAfter(now))
          ? 'subscription_renewed'
          : 'subscription_activated';
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'businessId': targetBusinessId,
        'action': action,
        'planId': plan.id,
        'planTier': plan.tierId,
        'planFamily': plan.businessFamily,
        'amount': amount,
        'receiptUrl': receiptUrl,
        'startDate': startDate.toIso8601String(),
        'endDate': newEndDate.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });

      unawaited(
        _sendSubscriptionStatusEmailSafe(
          userId: userId,
          plan: plan,
          amount: amount,
          statusLabel:
              action == 'subscription_renewed' ? 'Renewed' : 'Active',
          statusMessage: action == 'subscription_renewed'
              ? 'Your subscription renewal has been applied successfully.'
              : 'Your subscription has been activated successfully.',
          businessId: targetBusinessId,
          startsOn: startDate,
          endsOn: newEndDate,
        ),
      );

      return true;
    } catch (e) {
      print('[SubscriptionService] Error in activateOrRenewSubscription: $e');
      return false;
    }
  }

  Future<bool> syncSubscriptionToBusiness({
    required String businessId,
    required String planId,
    required DateTime startDate,
    required DateTime endDate,
    double? amount,
    String? receiptUrl,
  }) async {
    try {
      final plan = getPlanById(planId);
      if (plan == null) return false;

      final businessDoc =
          await _firestore.collection('businesses').doc(businessId).get();
      final businessType = businessDoc.data()?['businessType'] as String?;

      await _firestore.collection('businesses').doc(businessId).set(
            _buildBusinessSubscriptionPayload(
              plan: plan,
              businessType: businessType,
              startDate: startDate,
              endDate: endDate,
              amount: amount,
              receiptUrl: receiptUrl,
              status: 'approved',
              isActive: true,
            ),
            SetOptions(merge: true),
          );

      return true;
    } catch (e) {
      print('[SubscriptionService] Error syncing subscription to business: $e');
      return false;
    }
  }

  Future<bool> syncSubscriptionForUserBusinesses({
    required String userId,
    required String planId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('ownerId', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        await syncSubscriptionToBusiness(
          businessId: doc.id,
          planId: planId,
          startDate: startDate,
          endDate: endDate,
        );
      }

      return true;
    } catch (e) {
      print(
          '[SubscriptionService] Error syncing subscription to user businesses: $e');
      return false;
    }
  }

  Future<bool> updateSubscriptionWithBusinesses({
    required String userId,
    required String businessIds,
    required String planId,
    required DateTime endDate,
  }) async {
    try {
      final plan = getPlanById(planId);
      if (plan == null) return false;

      final ids = businessIds
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final startDate = DateTime.now();

      await _writeUserSubscriptionSummary(
        userId: userId,
        businessId: ids.isNotEmpty ? ids.first : null,
        plan: plan,
        startDate: startDate,
        endDate: endDate,
        amount: null,
        receiptUrl: null,
        status: 'approved',
        isActive: true,
      );

      for (final businessId in ids) {
        await syncSubscriptionToBusiness(
          businessId: businessId,
          planId: plan.id,
          startDate: startDate,
          endDate: endDate,
        );
      }

      return true;
    } catch (e) {
      print('[SubscriptionService] Error updating subscription: $e');
      return false;
    }
  }

  Future<void> syncUserSubscriptionSummaryFromBusiness({
    required String userId,
    required String businessId,
    bool? overrideIsActive,
    String? overrideStatus,
  }) async {
    try {
      final business = await getBusinessSubscription(businessId);
      if (business == null) return;

      final planId = business['subscriptionPlan']?.toString();
      final businessType = business['businessType']?.toString();
      final plan = getPlanById(planId ?? '');
      final tierId = normalizeStoredPlanLevel(
        subscriptionTier: business['subscriptionTier']?.toString(),
        subscriptionPlan: planId,
        businessClass: business['businessClass']?.toString(),
      );

      await _firestore.collection('users').doc(userId).set({
        'currentBusinessId': businessId,
        'subscriptionBusinessId': businessId,
        'subscriptionBusinessType': businessType,
        'subscriptionPlan': planId,
        'subscriptionTier': tierId,
        'subscriptionFamily':
            plan?.businessFamily ?? getPlanFamilyForBusinessType(businessType),
        'subscriptionStartDate': business['subscriptionStartDate'],
        'subscriptionEndDate': business['subscriptionEndDate'],
        'hasActiveSubscription': overrideIsActive ??
            (business['isSubscriptionActive'] as bool? ?? false),
        'subscriptionStatus': overrideStatus ??
            (business['subscriptionStatus']?.toString() ?? 'inactive'),
        'subscriptionPaymentRequired': !(overrideIsActive ??
            (business['isSubscriptionActive'] as bool? ?? false)),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print(
          '[SubscriptionService] Error syncing user subscription summary: $e');
    }
  }

  Future<void> _writeUserSubscriptionSummary({
    required String userId,
    required SubscriptionPlan plan,
    required DateTime startDate,
    required DateTime endDate,
    required bool isActive,
    required String status,
    String? businessId,
    double? amount,
    String? receiptUrl,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'currentBusinessId': businessId,
      'subscriptionBusinessId': businessId,
      'subscriptionPlan': plan.id,
      'subscriptionTier': plan.tierId,
      'subscriptionFamily': plan.businessFamily,
      'hasActiveSubscription': isActive,
      'subscriptionStatus': status,
      'subscriptionStartDate': startDate.toIso8601String(),
      'subscriptionEndDate': endDate.toIso8601String(),
      'subscriptionPaymentRequired': !isActive,
      'subscriptionReceiptUrl': receiptUrl,
      'subscriptionAmount': amount,
      'subscriptionActivatedAt': DateTime.now().toIso8601String(),
      'pendingSubscriptionPlan': FieldValue.delete(),
      'pendingSubscriptionTier': FieldValue.delete(),
      'pendingSubscriptionAmount': FieldValue.delete(),
      'pendingSubscriptionReceiptUrl': FieldValue.delete(),
      'pendingSubscriptionStatus': FieldValue.delete(),
      'pendingSubscriptionRequestedAt': FieldValue.delete(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _buildBusinessSubscriptionPayload({
    required SubscriptionPlan plan,
    required String? businessType,
    required DateTime startDate,
    required DateTime endDate,
    required bool isActive,
    required String status,
    double? amount,
    String? receiptUrl,
  }) {
    return {
      'subscriptionTier': plan.tierId,
      'subscriptionPlan': plan.id,
      'businessClass': plan.tierId,
      'subscriptionFamily': plan.businessFamily,
      'subscriptionBusinessType': canonicalizeBusinessType(businessType),
      'subscriptionStartDate': startDate.toIso8601String(),
      'subscriptionEndDate': endDate.toIso8601String(),
      'subscriptionAmount': amount,
      'subscriptionReceiptUrl': receiptUrl,
      'isSubscriptionActive': isActive,
      'subscriptionStatus': status,
      'subscriptionReviewStatus': status,
      'pendingSubscriptionPlan': FieldValue.delete(),
      'pendingSubscriptionTier': FieldValue.delete(),
      'pendingBusinessClass': FieldValue.delete(),
      'pendingSubscriptionAmount': FieldValue.delete(),
      'pendingSubscriptionReceiptUrl': FieldValue.delete(),
      'subscriptionSyncedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<String?> _resolveBusinessIdForUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? <String, dynamic>{};

      final currentBusinessId = data['currentBusinessId']?.toString();
      if (currentBusinessId != null && currentBusinessId.trim().isNotEmpty) {
        return currentBusinessId.trim();
      }

      final businessIds = data['businessIds'];
      if (businessIds is List && businessIds.isNotEmpty) {
        final first = businessIds.first?.toString();
        if (first != null && first.trim().isNotEmpty) return first.trim();
      }

      final businessId = data['businessId']?.toString();
      if (businessId != null && businessId.trim().isNotEmpty) {
        return businessId.trim();
      }
    } catch (e) {
      print('[SubscriptionService] Error resolving business id for user: $e');
    }
    return null;
  }

  Future<void> _sendSubscriptionStatusEmailSafe({
    required String userId,
    required SubscriptionPlan plan,
    required double amount,
    required String statusLabel,
    required String statusMessage,
    String? userEmail,
    String? userName,
    String? requestId,
    String? businessId,
    DateTime? startsOn,
    DateTime? endsOn,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final recipientEmail =
          (userEmail ?? userData['email']?.toString() ?? '').trim();
      if (recipientEmail.isEmpty) return;

      final recipientName =
          (userName ?? userData['fullName']?.toString() ?? 'Business Owner')
              .trim();
      final businessContext =
          await _resolveSubscriptionEmailBusinessContext(userId, businessId);

      final emailData = <String, dynamic>{
        'businessName': businessContext['businessName'] ?? 'Manage Care',
        'recipientName':
            recipientName.isNotEmpty ? recipientName : 'Business Owner',
        'planName': plan.name,
        'amount': amount,
        'statusLabel': statusLabel,
        'statusMessage': statusMessage,
        'requestId': requestId,
        'businessType': businessContext['businessType'],
        'startsOn': startsOn,
        'endsOn': endsOn,
      };

      await _emailService.sendSubscriptionStatusEmail(
        recipientEmail,
        emailData,
      );

      final businessEmail =
          (businessContext['businessEmail']?.toString() ?? '').trim();
      if (businessEmail.isNotEmpty &&
          businessEmail.toLowerCase() != recipientEmail.toLowerCase()) {
        await _emailService.sendSubscriptionStatusEmail(
          businessEmail,
          emailData,
        );
      }
    } catch (e) {
      print('[SubscriptionService] Failed to send subscription email: $e');
    }
  }

  Future<Map<String, String?>> _resolveSubscriptionEmailBusinessContext(
    String userId,
    String? businessId,
  ) async {
    final resolvedBusinessId = businessId?.trim().isNotEmpty == true
        ? businessId!.trim()
        : await _resolveBusinessIdForUser(userId);

    if (resolvedBusinessId == null || resolvedBusinessId.isEmpty) {
      return {
        'businessName': 'Manage Care',
        'businessType': null,
        'businessEmail': null,
      };
    }

    try {
      final businessDoc =
          await _firestore.collection('businesses').doc(resolvedBusinessId).get();
      final data = businessDoc.data() ?? <String, dynamic>{};
      return {
        'businessName':
            data['name']?.toString().trim().isNotEmpty == true
                ? data['name'].toString().trim()
                : 'Manage Care',
        'businessType': data['businessType']?.toString(),
        'businessEmail': data['email']?.toString(),
      };
    } catch (e) {
      print(
          '[SubscriptionService] Failed to resolve business email context: $e');
      return {
        'businessName': 'Manage Care',
        'businessType': null,
        'businessEmail': null,
      };
    }
  }

  Future<SubscriptionPlan?> _resolvePlanForNotification(
    String userId,
    String? businessId,
  ) async {
    try {
      if (businessId?.trim().isNotEmpty == true) {
        final business = await getBusinessSubscription(businessId!.trim());
        final businessPlanId = business?['subscriptionPlan']?.toString() ?? '';
        final businessPlan = getPlanById(businessPlanId);
        if (businessPlan != null) return businessPlan;
      }

      final userSubscription = await getUserSubscription(userId);
      final userPlanId = userSubscription?['subscriptionPlan']?.toString() ?? '';
      return getPlanById(userPlanId);
    } catch (e) {
      print('[SubscriptionService] Failed to resolve plan for email: $e');
      return null;
    }
  }

  SubscriptionPlan _fallbackNotificationPlan() {
    return const SubscriptionPlan(
      id: 'standard_tier1_monthly',
      name: 'Standard Tier 1',
      price: 0,
      durationInDays: 30,
      features: [],
      tierId: 'tier1',
      businessFamily: familyStandard,
      billingLabel: 'Monthly',
    );
  }
}
