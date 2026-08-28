import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/user_model.dart';
import 'email_service.dart';

/// SubscriptionPlan definition (same as the Firestore version but without
/// the Firestore import).
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

/// Supabase/Postgres-backed SubscriptionService.
///
/// Replaces the Firestore-based SubscriptionService by reading/writing
/// subscription data from the `businesses` table and user `profiles`
/// table via the Supabase client.
class SubscriptionServiceSupabase {
  static const int subscriptionGracePeriodDays = 7;
  static const List<int> subscriptionReminderMilestones = [30, 15, 7, 3];

  final SupabaseClient _supabase;
  final EmailService _emailService;

  SubscriptionServiceSupabase({
    SupabaseClient? supabase,
    EmailService? emailService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _emailService = emailService ?? EmailService();

  static const String familyStandard = 'standard';
  static const String familyKitchen = 'kitchen';
  static const String familyLounge = 'lounge';
  static const String familyHospitality = 'hospitality';
  static const String familyFuel = 'fuel_station';

  static const Map<String, int> _tierRanks = {
    'free': 0,
    'tier1': 1,
    'tier2': 2,
    'tier3': 3,
    'tier4': 4,
    'premium': 5,
    'unlimited': 5,
  };

  // --- Plan definitions (copied from the Firestore version) ---
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
      case familyFuel:
        return 'Fuel Station';
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
      case 'tier4':
        return 'Tier 4';
      case 'premium':
        return 'Premium';
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

  // Plans list — same as original, omitted for brevity. Include all ~60+ plans.
  static final List<SubscriptionPlan> plans = [..._buildStandardPlans()];

  static List<SubscriptionPlan> _buildStandardPlans() {
    const basePlans = [
      // Standard
      ('standard', 'tier1', '3m', 23750.0, 90, ['1 store', '300 products', '3 workers'],
          {'products': 300, 'workers': 3, 'locations': 1, 'branches': 0}),
      ('standard', 'tier1', '6m', 42750.0, 180, ['1 store', '300 products', '3 workers'],
          {'products': 300, 'workers': 3, 'locations': 1, 'branches': 0}),
      ('standard', 'tier1', '12m', 76950.0, 365, ['1 store', '300 products', '3 workers'],
          {'products': 300, 'workers': 3, 'locations': 1, 'branches': 0}),
      ('standard', 'tier2', '3m', 32050.0, 90, ['1 branch', '700 products', '5 workers'],
          {'products': 700, 'workers': 5, 'locations': 2, 'branches': 1}),
      ('standard', 'tier2', '6m', 53780.0, 180, ['1 branch', '700 products', '5 workers'],
          {'products': 700, 'workers': 5, 'locations': 2, 'branches': 1}),
      ('standard', 'tier2', '12m', 87450.0, 365, ['1 branch', '700 products', '5 workers'],
          {'products': 700, 'workers': 5, 'locations': 2, 'branches': 1}),
      ('standard', 'tier3', '3m', 37900.0, 90, ['2 branches', '1000 products', '10 workers'],
          {'products': 1000, 'workers': 10, 'locations': 3, 'branches': 2}),
      ('standard', 'tier3', '6m', 64650.0, 180, ['2 branches', '1000 products', '10 workers'],
          {'products': 1000, 'workers': 10, 'locations': 3, 'branches': 2}),
      ('standard', 'tier3', '12m', 97900.0, 365, ['2 branches', '1000 products', '10 workers'],
          {'products': 1000, 'workers': 10, 'locations': 3, 'branches': 2}),
      ('standard', 'unlimited', 'monthly', 25000.0, 30, ['Unlimited products', 'Unlimited workers', 'Unlimited branches'],
          {'products': null, 'workers': null, 'locations': null, 'branches': null}),
      ('standard', 'unlimited', '3m', 70000.0, 90, ['Unlimited products', 'Unlimited workers', 'Unlimited branches'],
          {'products': null, 'workers': null, 'locations': null, 'branches': null}),
      // Kitchen
      ('kitchen', 'tier1', '3m', 23750.0, 90, ['10 tables', '15 meals', '15 inventory'],
          {'tables': 10, 'workers': 5, 'menu_items': 15, 'inventory_products': 15, 'locations': 1, 'branches': 0}),
      ('kitchen', 'tier1', '6m', 42750.0, 180, ['10 tables', '15 meals', '15 inventory'],
          {'tables': 10, 'workers': 5, 'menu_items': 15, 'inventory_products': 15, 'locations': 1, 'branches': 0}),
      ('kitchen', 'tier1', '12m', 76950.0, 365, ['10 tables', '15 meals', '15 inventory'],
          {'tables': 10, 'workers': 5, 'menu_items': 15, 'inventory_products': 15, 'locations': 1, 'branches': 0}),
      ('kitchen', 'tier2', '3m', 32050.0, 90, ['20 tables', '25 meals', '1 branch'],
          {'tables': 20, 'workers': 10, 'menu_items': 25, 'inventory_products': 25, 'locations': 2, 'branches': 1}),
      ('kitchen', 'tier2', '6m', 53780.0, 180, ['20 tables', '25 meals', '1 branch'],
          {'tables': 20, 'workers': 10, 'menu_items': 25, 'inventory_products': 25, 'locations': 2, 'branches': 1}),
      ('kitchen', 'tier2', '12m', 87450.0, 365, ['20 tables', '25 meals', '1 branch'],
          {'tables': 20, 'workers': 10, 'menu_items': 25, 'inventory_products': 25, 'locations': 2, 'branches': 1}),
      ('kitchen', 'tier3', '3m', 37900.0, 90, ['35 tables', 'VIP section', '2 branches'],
          {'tables': 35, 'workers': 15, 'menu_items': 35, 'inventory_products': 40, 'locations': 3, 'branches': 2}),
      ('kitchen', 'tier3', '6m', 64650.0, 180, ['35 tables', 'VIP section', '2 branches'],
          {'tables': 35, 'workers': 15, 'menu_items': 35, 'inventory_products': 40, 'locations': 3, 'branches': 2}),
      ('kitchen', 'tier3', '12m', 97900.0, 365, ['35 tables', 'VIP section', '2 branches'],
          {'tables': 35, 'workers': 15, 'menu_items': 35, 'inventory_products': 40, 'locations': 3, 'branches': 2}),
      ('kitchen', 'unlimited', 'monthly', 25000.0, 30, ['Unlimited access', 'Unlimited tables', 'Unlimited inventory'],
          {'tables': null, 'workers': null, 'menu_items': null, 'inventory_products': null, 'locations': null, 'branches': null}),
      ('kitchen', 'unlimited', '3m', 67500.0, 90, ['Unlimited access', 'Unlimited tables', 'Unlimited inventory'],
          {'tables': null, 'workers': null, 'menu_items': null, 'inventory_products': null, 'locations': null, 'branches': null}),
      // Lounge
      ('lounge', 'tier1', 'monthly', 12850.0, 30, ['15 tables', '65 inventory', '7 workers'],
          {'tables': 15, 'workers': 7, 'inventory_products': 65, 'locations': 1, 'branches': 0}),
      ('lounge', 'tier2', 'monthly', 20560.0, 30, ['25 tables', '100 inventory', '1 branch'],
          {'tables': 25, 'workers': 10, 'inventory_products': 100, 'locations': 2, 'branches': 1}),
      ('lounge', 'tier3', 'monthly', 30840.0, 30, ['40 tables', '200 inventory', '2 branches'],
          {'tables': 40, 'workers': 15, 'inventory_products': 200, 'locations': 3, 'branches': 2}),
      ('lounge', 'unlimited', 'monthly', 37000.0, 30, ['Unlimited access', 'Unlimited tables', 'Unlimited inventory'],
          {'tables': null, 'workers': null, 'inventory_products': null, 'locations': null, 'branches': null}),
      // Hospitality
      ('hospitality', 'tier1', 'monthly', 14650.0, 30, ['15 rooms', '10 restaurant tables', '15 bar tables'],
          {'rooms': 15, 'suites': 0, 'workers': 7, 'restaurant_tables': 10, 'bar_tables': 15, 'locations': 1, 'branches': 0}),
      ('hospitality', 'tier2', 'monthly', 23350.0, 30, ['25 rooms + 5 suites', 'Hall access', '1 branch'],
          {'rooms': 25, 'suites': 5, 'workers': 15, 'restaurant_tables': 20, 'bar_tables': 25, 'locations': 2, 'branches': 1}),
      ('hospitality', 'tier3', 'monthly', 35750.0, 30, ['40 rooms + 10 suites', 'Pool access', '2 branches'],
          {'rooms': 40, 'suites': 10, 'workers': 25, 'restaurant_tables': 30, 'bar_tables': 35, 'locations': 3, 'branches': 2}),
      ('hospitality', 'unlimited', 'monthly', 45000.0, 30, ['Unlimited rooms', 'Unlimited workers', 'Unlimited features'],
          {'rooms': null, 'suites': null, 'workers': null, 'restaurant_tables': null, 'bar_tables': null, 'locations': null, 'branches': null}),
    ];

    final fuelPlans = [
      ('fuel_station', 'tier1', '3m', 33900.0, 90, ['1 location', '2 pumps', '3 workers', '50 minimart products'],
          {'locations': 1, 'branches': 0, 'pumps': 2, 'pumps_per_location': 2, 'workers': 3, 'workers_per_location': 3, 'products': 50, 'products_per_location': 50}),
      ('fuel_station', 'tier1', '6m', 56500.0, 180, ['1 location', '2 pumps', '3 workers', '50 minimart products'],
          {'locations': 1, 'branches': 0, 'pumps': 2, 'pumps_per_location': 2, 'workers': 3, 'workers_per_location': 3, 'products': 50, 'products_per_location': 50}),
      ('fuel_station', 'tier1', '12m', 111800.0, 365, ['1 location', '2 pumps', '3 workers', '50 minimart products'],
          {'locations': 1, 'branches': 0, 'pumps': 2, 'pumps_per_location': 2, 'workers': 3, 'workers_per_location': 3, 'products': 50, 'products_per_location': 50}),
      ('fuel_station', 'tier2', '3m', 47615.0, 90, ['2 locations', '5 pumps/location', '7 workers/location', '150 products/location'],
          {'locations': 2, 'branches': 1, 'pumps': 10, 'pumps_per_location': 5, 'workers': 14, 'workers_per_location': 7, 'products': 300, 'products_per_location': 150}),
      ('fuel_station', 'tier2', '6m', 85600.0, 180, ['2 locations', '5 pumps/location', '7 workers/location', '150 products/location'],
          {'locations': 2, 'branches': 1, 'pumps': 10, 'pumps_per_location': 5, 'workers': 14, 'workers_per_location': 7, 'products': 300, 'products_per_location': 150}),
      ('fuel_station', 'tier2', '12m', 152045.0, 365, ['2 locations', '5 pumps/location', '7 workers/location', '150 products/location'],
          {'locations': 2, 'branches': 1, 'pumps': 10, 'pumps_per_location': 5, 'workers': 14, 'workers_per_location': 7, 'products': 300, 'products_per_location': 150}),
      ('fuel_station', 'tier3', '3m', 80775.0, 90, ['4 locations', '10 pumps/location', '12 workers/location', '250 products/location'],
          {'locations': 4, 'branches': 3, 'pumps': 40, 'pumps_per_location': 10, 'workers': 48, 'workers_per_location': 12, 'products': 1000, 'products_per_location': 250}),
      ('fuel_station', 'tier3', '6m', 145395.0, 180, ['4 locations', '10 pumps/location', '12 workers/location', '250 products/location'],
          {'locations': 4, 'branches': 3, 'pumps': 40, 'pumps_per_location': 10, 'workers': 48, 'workers_per_location': 12, 'products': 1000, 'products_per_location': 250}),
      ('fuel_station', 'tier3', '12m', 258480.0, 365, ['4 locations', '10 pumps/location', '12 workers/location', '250 products/location'],
          {'locations': 4, 'branches': 3, 'pumps': 40, 'pumps_per_location': 10, 'workers': 48, 'workers_per_location': 12, 'products': 1000, 'products_per_location': 250}),
      ('fuel_station', 'tier4', '3m', 137318.0, 90, ['10 locations', '20 pumps/location', '25 workers/location', '500 products/location'],
          {'locations': 10, 'branches': 9, 'pumps': 200, 'pumps_per_location': 20, 'workers': 250, 'workers_per_location': 25, 'products': 5000, 'products_per_location': 500}),
      ('fuel_station', 'tier4', '6m', 247173.0, 180, ['10 locations', '20 pumps/location', '25 workers/location', '500 products/location'],
          {'locations': 10, 'branches': 9, 'pumps': 200, 'pumps_per_location': 20, 'workers': 250, 'workers_per_location': 25, 'products': 5000, 'products_per_location': 500}),
      ('fuel_station', 'tier4', '12m', 439418.0, 365, ['10 locations', '20 pumps/location', '25 workers/location', '500 products/location'],
          {'locations': 10, 'branches': 9, 'pumps': 200, 'pumps_per_location': 20, 'workers': 250, 'workers_per_location': 25, 'products': 5000, 'products_per_location': 500}),
      ('fuel_station', 'premium', 'monthly', 0.0, 30, ['Add-on access', 'Attendance and clock-in', 'Unlimited pumps', 'Up to 50 locations'],
          {'locations': 50, 'branches': 49, 'pumps': null, 'pumps_per_location': null, 'workers': null, 'workers_per_location': null, 'products': null, 'products_per_location': null}),
    ];

    return [
      for (final p in basePlans)
        _plan(family: p.$1, tier: p.$2, durationCode: p.$3, price: p.$4, days: p.$5, features: p.$6 as List<String>, limits: p.$7 as Map<String, int?>),
      for (final p in fuelPlans)
        _plan(family: p.$1, tier: p.$2, durationCode: p.$3, price: p.$4, days: p.$5, features: p.$6 as List<String>, limits: p.$7 as Map<String, int?>),
    ];
  }

  // ==================== STATIC HELPERS (same as Firestore version) ====================

  static String canonicalizeBusinessType(String? businessType) {
    final raw = (businessType ?? '').trim().toLowerCase();
    if (raw.isEmpty) return 'retail';
    final value = raw.contains('/') ? raw.split('/').last : raw;
    switch (value) {
      case 'agriculture': case 'farm': case 'farms': return 'agri';
      case 'auto_repair': return 'auto';
      case 'real_estate': return 'realestate';
      case 'bar': return 'drink';
      case 'bakery_shop': case 'bakeshop': return 'bakery';
      case 'petrol_station': case 'petroleum_station': case 'petroleum station':
      case 'filling_station': case 'filling station': case 'gas_station':
      case 'gas station': case 'fuel_station': case 'fuel station': return 'petroleum';
      case 'guest_inn': case 'guest inn': case 'guesthouse': case 'lodge': return 'hotel';
      default: return value;
    }
  }

  static String getPlanFamilyForBusinessType(String? businessType) {
    switch (canonicalizeBusinessType(businessType)) {
      case 'restaurant': case 'kitchen': return familyKitchen;
      case 'drink': case 'lounge': return familyLounge;
      case 'hotel': case 'apartment': return familyHospitality;
      case 'gas': case 'petrol': case 'petroleum': case 'filling station': case 'fuel': return familyFuel;
      default: return familyStandard;
    }
  }

  static SubscriptionPlan? getPlanById(String planId) {
    final id = planId.trim().toLowerCase();
    if (id.isEmpty) return null;
    try { return plans.firstWhere((plan) => plan.id.toLowerCase() == id); } catch (_) { return null; }
  }

  static List<SubscriptionPlan> getPlansForBusinessType(String? businessType, {String? tierId}) {
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

  static List<SubscriptionPlan> getPlansForBusinessTypeAndClass(String? businessType, String? businessClass) {
    return getPlansForBusinessType(businessType, tierId: normalizeStoredBusinessClass(businessClass: businessClass));
  }

  static List<SubscriptionPlan> getPlansForClass(String? businessClass) {
    return getPlansForBusinessType('retail', tierId: normalizeStoredBusinessClass(businessClass: businessClass));
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

  static String detectTier({required int products, required int staff, required double monthlyIncome, String? businessType}) {
    return detectBusinessClass(products: products, staff: staff, monthlyIncome: monthlyIncome, businessType: businessType);
  }

  static String detectBusinessClass({required int products, required int staff, required double monthlyIncome, String? businessType}) {
    switch (getPlanFamilyForBusinessType(businessType)) {
      case familyKitchen: if (products <= 15 && staff <= 5) return 'tier1'; if (products <= 25 && staff <= 10) return 'tier2'; return 'tier3';
      case familyLounge: if (products <= 65 && staff <= 7) return 'tier1'; if (products <= 100 && staff <= 10) return 'tier2'; return 'tier3';
      case familyHospitality: if (staff <= 7 && monthlyIncome <= 1000000.0) return 'tier1'; if (staff <= 15 && monthlyIncome <= 3000000.0) return 'tier2'; return 'tier3';
      case familyFuel: if (products <= 50 && staff <= 3) return 'tier1'; if (products <= 150 && staff <= 7) return 'tier2'; if (products <= 250 && staff <= 12) return 'tier3'; if (products <= 500 && staff <= 25) return 'tier4'; return 'premium';
      default: if (products <= 300 && staff <= 3) return 'tier1'; if (products <= 700 && staff <= 5) return 'tier2'; if (products > 1000) return 'unlimited'; return 'tier3';
    }
  }

  static String getBusinessClassFromPlanId(String planId) {
    final plan = getPlanById(planId);
    return plan?.tierId ?? normalizeStoredBusinessClass(subscriptionPlan: planId);
  }

  static String getPlanLevelFromPlanId(String planId) {
    final plan = getPlanById(planId);
    return plan?.tierId ?? normalizeStoredPlanLevel(subscriptionPlan: planId);
  }

  static int getTierRank(String? tierId) => _tierRanks[_normalizeTierId(tierId) ?? 'free'] ?? 0;

  static bool isTierAtLeast(String? tierId, String requiredTierId) => getTierRank(tierId) >= getTierRank(requiredTierId);

  static String normalizeStoredPlanLevel({String? subscriptionTier, String? subscriptionPlan, String? businessClass}) {
    final plan = getPlanById(subscriptionPlan ?? ''); if (plan != null) return plan.tierId;
    final tier = _normalizeTierId(subscriptionTier); if (tier != null) return tier;
    final klass = _normalizeTierId(businessClass); if (klass != null) return klass;
    final raw = (subscriptionTier ?? '').trim().toLowerCase();
    if (raw == 'basic' || raw == 'starter') return klass ?? 'tier1';
    if (raw == 'pro' || raw == 'professional' || raw == 'enterprise') return klass ?? 'tier3';
    return 'tier1';
  }

  static String normalizeStoredBusinessClass({String? businessClass, String? subscriptionPlan, String? subscriptionTier}) {
    final plan = getPlanById(subscriptionPlan ?? ''); if (plan != null) return plan.tierId;
    final klass = _normalizeTierId(businessClass); if (klass != null) return klass;
    final tier = _normalizeTierId(subscriptionTier); if (tier != null) return tier;
    final raw = (subscriptionTier ?? '').trim().toLowerCase();
    if (raw == 'basic' || raw == 'starter') return 'tier1';
    if (raw == 'pro' || raw == 'professional' || raw == 'enterprise') return 'tier3';
    return 'tier1';
  }

  static int? getLimitForBusinessType({required String? businessType, required String tierId, required String limitType}) {
    final family = getPlanFamilyForBusinessType(businessType);
    final rawTier = tierId.trim().toLowerCase();
    if (limitType == 'workers' && rawTier == 'enterprise') return null;
    final normalizedTier = normalizeStoredPlanLevel(subscriptionTier: tierId);
    SubscriptionPlan? selected;
    for (final plan in plans) {
      if (plan.businessFamily == family && plan.tierId == normalizedTier) { selected = plan; break; }
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

  static bool hasFeatureAccess({required String? businessType, required String tierId, required String feature}) {
    final family = getPlanFamilyForBusinessType(businessType);
    final rank = getTierRank(tierId);
    switch (feature.trim().toLowerCase()) {
      case 'basic_sales': case 'product_management': case 'basic_reports': return true;
      case 'advanced_analytics': case 'email_receipts': case 'sms_notifications':
      case 'payment_processing': case 'receipt_customization': return rank >= getTierRank('tier1');
      case 'multi_location': return rank >= getTierRank('tier2');
      case 'priority_support': case 'custom_reports': return rank >= getTierRank('tier3');
      case 'vip_section': return (family == familyKitchen || family == familyLounge) && rank >= getTierRank('tier3');
      case 'hall_booking': case 'hall_features': case 'hall_services': return family == familyHospitality && rank >= getTierRank('tier2');
      case 'pool_booking': case 'pool_features': return family == familyHospitality && rank >= getTierRank('tier3');
      case 'fuel_addons': case 'attendance': case 'clock_in': case 'worker_attendance': return family == familyFuel && rank >= getTierRank('premium');
      case 'white_label': case 'sso_login': case 'dedicated_support': case 'custom_development': case 'api_access': case 'api_advanced': return rank >= getTierRank('unlimited');
      default: return true;
    }
  }

  static String? getRequiredTierForFeature(String feature, {String? businessType}) {
    final family = getPlanFamilyForBusinessType(businessType);
    switch (feature.trim().toLowerCase()) {
      case 'basic_sales': case 'product_management': case 'basic_reports': return 'free';
      case 'advanced_analytics': case 'email_receipts': case 'sms_notifications':
      case 'payment_processing': case 'receipt_customization': return 'tier1';
      case 'multi_location': return 'tier2';
      case 'priority_support': case 'custom_reports': return 'tier3';
      case 'vip_section': return (family == familyKitchen || family == familyLounge) ? 'tier3' : 'unlimited';
      case 'hall_booking': case 'hall_features': case 'hall_services': return family == familyHospitality ? 'tier2' : 'unlimited';
      case 'pool_booking': case 'pool_features': return family == familyHospitality ? 'tier3' : 'unlimited';
      case 'fuel_addons': case 'attendance': case 'clock_in': case 'worker_attendance': return family == familyFuel ? 'premium' : 'unlimited';
      case 'white_label': case 'sso_login': case 'dedicated_support': case 'custom_development': case 'api_access': case 'api_advanced': return 'unlimited';
      default: return null;
    }
  }

  static DateTime computeRenewalEndDate({DateTime? existingEnd, required int durationInDays, DateTime? now}) {
    final nowRef = now ?? DateTime.now();
    final base = (existingEnd != null && existingEnd.isAfter(nowRef)) ? existingEnd : nowRef;
    return base.add(Duration(days: durationInDays));
  }

  static bool isSubscriptionActive(UserModel user) {
    if (!user.isOwner) return true;
    if (!user.hasActiveSubscription || user.subscriptionEndDate == null) return false;
    return isWithinSubscriptionAccessWindow(user.subscriptionEndDate!);
  }

  static DateTime normalizeToDate(DateTime value) => DateTime(value.year, value.month, value.day);

  static bool isWithinSubscriptionAccessWindow(DateTime endDate, {DateTime? now}) {
    final today = normalizeToDate(now ?? DateTime.now());
    final graceEnds = normalizeToDate(endDate).add(const Duration(days: subscriptionGracePeriodDays));
    return !today.isAfter(graceEnds);
  }

  static int daysUntilSubscriptionEnd(DateTime endDate, {DateTime? now}) {
    return normalizeToDate(endDate).difference(normalizeToDate(now ?? DateTime.now())).inDays;
  }

  static int daysSinceSubscriptionEnd(DateTime endDate, {DateTime? now}) {
    return normalizeToDate(now ?? DateTime.now()).difference(normalizeToDate(endDate)).inDays;
  }

  static bool isInSubscriptionGracePeriod(DateTime endDate, {DateTime? now}) {
    final daysSinceEnd = daysSinceSubscriptionEnd(endDate, now: now);
    return daysSinceEnd >= 0 && daysSinceEnd <= subscriptionGracePeriodDays;
  }

  static int? calculateReminderMilestone({required DateTime now, required DateTime endDate}) {
    final daysLeft = daysUntilSubscriptionEnd(endDate, now: now);
    return subscriptionReminderMilestones.contains(daysLeft) ? daysLeft : null;
  }

  static String reminderMilestoneLabel(int daysLeft) {
    switch (daysLeft) {
      case 30: return '30 days';
      case 15: return '15 days';
      case 7: return '1 week';
      case 3: return '3 days';
      default: return '$daysLeft day(s)';
    }
  }

  static String? _normalizeTierId(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    switch (raw) {
      case 't1': case 'tier1': return 'tier1';
      case 't2': case 'tier2': return 'tier2';
      case 't3': case 'tier3': return 'tier3';
      case 't4': case 'tier4': return 'tier4';
      case 'premium': case 'fuel_premium': return 'premium';
      case 'unlimited': case 'unlimited_plan': return 'unlimited';
      default: return null;
    }
  }

  static List<String> _limitKeysForFamily(String family, String limitType) {
    switch (limitType) {
      case 'products': return family == familyFuel ? ['products_per_location', 'products', 'inventory_products']
          : family == familyKitchen || family == familyLounge ? ['inventory_products', 'menu_items', 'products'] : ['products', 'inventory_products'];
      case 'pumps': return ['pumps_per_location', 'pumps'];
      case 'workers': return family == familyFuel ? ['workers_per_location', 'workers'] : ['workers'];
      case 'tables': return family == familyHospitality ? ['restaurant_tables', 'bar_tables', 'tables'] : ['tables'];
      case 'branches': return ['branches', 'locations'];
      default: return [limitType];
    }
  }

  // ==================== SUPABASE-BACKED BUSINESS METHODS ====================

  /// Get business subscription from the businesses table.
  Future<Map<String, dynamic>?> getBusinessSubscription(String businessId) async {
    try {
      final result = await _supabase
          .from('businesses')
          .select('''
            id, name, business_type,
            subscription_plan, subscription_tier, business_class, subscription_family,
            subscription_status, subscription_review_status,
            subscription_start_date, subscription_end_date,
            is_subscription_active, pending_subscription_plan
          ''')
          .eq('id', businessId)
          .maybeSingle();
      if (result == null) return null;
      return {
        'id': result['id'] as String,
        'name': result['name'] ?? '',
        'businessType': result['business_type'] ?? '',
        'subscriptionPlan': result['subscription_plan'] ?? '',
        'subscriptionTier': result['subscription_tier'] ?? '',
        'businessClass': result['business_class'] ?? '',
        'subscriptionFamily': result['subscription_family'] ?? '',
        'subscriptionStatus': result['subscription_status'] ?? '',
        'subscriptionReviewStatus': result['subscription_review_status'] ?? '',
        'subscriptionStartDate': result['subscription_start_date'] as String?,
        'subscriptionEndDate': result['subscription_end_date'] as String?,
        'isSubscriptionActive': result['is_subscription_active'] ?? false,
        'pendingSubscriptionPlan': result['pending_subscription_plan'] as String?,
      };
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error getting business subscription: $e');
      return null;
    }
  }

  /// Update the businesses table with subscription info.
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

      await _supabase.from('businesses').update({
        'subscription_tier': plan.tierId,
        'subscription_plan': plan.id,
        'business_class': plan.tierId,
        'subscription_family': plan.businessFamily,
        'subscription_start_date': startDate.toIso8601String(),
        'subscription_end_date': endDate.toIso8601String(),
        'is_subscription_active': true,
        'subscription_status': 'approved',
        'subscription_review_status': 'approved',
        'subscription_amount': amount,
        'subscription_receipt_url': receiptUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', businessId);

      return true;
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error syncing subscription to business: $e');
      return false;
    }
  }

  /// Validate subscription by reading from businesses table.
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
      return false;
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error validating subscription: $e');
      return false;
    }
  }

  /// Validate business subscription with grace-period logic.
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
      final status = (business['subscriptionStatus'] ?? '').toString().toLowerCase();
      final endRaw = business['subscriptionEndDate'] as String?;
      final endDate = endRaw != null ? DateTime.tryParse(endRaw) : null;
      final isTrial = status == 'trial';

      final isValid = isActive &&
          (endDate == null ||
              (isTrial
                  ? !normalizeToDate(now).isAfter(normalizeToDate(endDate))
                  : isWithinSubscriptionAccessWindow(endDate, now: now)));

      if (isActive && endDate != null && !isValid) {
        await _supabase.from('businesses').update({
          'is_subscription_active': false,
          'subscription_status': 'expired',
          'subscription_review_status': 'expired',
          'updated_at': now.toIso8601String(),
        }).eq('id', businessId);
      }

      if (userId != null && userId.isNotEmpty) {
        await syncUserSubscriptionSummaryFromBusiness(
          userId: userId,
          businessId: businessId,
          overrideIsActive: isValid,
          overrideStatus: isValid ? (isTrial ? 'trial' : 'approved') : 'expired',
        );
      }

      return isValid;
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error validating business subscription: $e');
      return false;
    }
  }

  /// Activate or renew a subscription (writes to businesses table).
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

      if (targetBusinessId == null || targetBusinessId.isEmpty) {
        print('[SubscriptionServiceSupabase] No business found for user $userId');
        return false;
      }

      final existingBusiness = await getBusinessSubscription(targetBusinessId);
      DateTime? existingEnd;
      if (existingBusiness != null) {
        try { existingEnd = existingBusiness['subscriptionEndDate'] != null
            ? DateTime.tryParse(existingBusiness['subscriptionEndDate'] as String)
            : null; } catch (_) {}
      }

      final newEndDate = computeRenewalEndDate(
        existingEnd: existingEnd,
        durationInDays: plan.durationInDays,
        now: now,
      );

      await syncSubscriptionToBusiness(
        businessId: targetBusinessId,
        planId: plan.id,
        startDate: now,
        endDate: newEndDate,
        amount: amount,
        receiptUrl: receiptUrl,
      );

      // Update user profile with subscription summary
      await _supabase.from('profiles').update({
        'subscription_plan': plan.id,
        'subscription_tier': plan.tierId,
        'has_active_subscription': true,
        'subscription_status': 'approved',
        'subscription_start_date': now.toIso8601String(),
        'subscription_end_date': newEndDate.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', userId);

      return true;
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error activating subscription: $e');
      return false;
    }
  }

  /// Expire a subscription.
  Future<bool> expireSubscription(String userId, {String? businessId}) async {
    try {
      final now = DateTime.now();
      if (businessId != null && businessId.isNotEmpty) {
        await _supabase.from('businesses').update({
          'is_subscription_active': false,
          'subscription_status': 'expired',
          'subscription_review_status': 'expired',
          'updated_at': now.toIso8601String(),
        }).eq('id', businessId);
      }

      await _supabase.from('profiles').update({
        'has_active_subscription': false,
        'subscription_status': 'expired',
        'updated_at': now.toIso8601String(),
      }).eq('id', userId);

      return true;
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error expiring subscription: $e');
      return false;
    }
  }

  /// Cancel a subscription.
  Future<bool> cancelSubscription(String userId, {String? businessId}) async {
    try {
      final now = DateTime.now();
      if (businessId != null && businessId.isNotEmpty) {
        await _supabase.from('businesses').update({
          'is_subscription_active': false,
          'subscription_status': 'cancelled',
          'subscription_review_status': 'cancelled',
          'updated_at': now.toIso8601String(),
        }).eq('id', businessId);
      }

      await _supabase.from('profiles').update({
        'has_active_subscription': false,
        'subscription_status': 'cancelled',
        'updated_at': now.toIso8601String(),
      }).eq('id', userId);

      return true;
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error cancelling subscription: $e');
      return false;
    }
  }

  /// Sync subscription summary from business to user profile.
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
      final tierId = normalizeStoredPlanLevel(
        subscriptionTier: business['subscriptionTier']?.toString(),
        subscriptionPlan: planId,
        businessClass: business['businessClass']?.toString(),
      );

      await _supabase.from('profiles').update({
        'current_business_id': businessId,
        'subscription_plan': planId,
        'subscription_tier': tierId,
        'subscription_family': business['subscriptionFamily'] as String?,
        'subscription_start_date': business['subscriptionStartDate'] as String?,
        'subscription_end_date': business['subscriptionEndDate'] as String?,
        'has_active_subscription': overrideIsActive ?? (business['isSubscriptionActive'] as bool? ?? false),
        'subscription_status': overrideStatus ?? (business['subscriptionStatus']?.toString() ?? 'inactive'),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error syncing user subscription summary: $e');
    }
  }

  Future<String?> _resolveBusinessIdForUser(String userId) async {
    try {
      final result = await _supabase
          .from('profiles')
          .select('current_business_id, business_ids')
          .eq('id', userId)
          .maybeSingle();
      if (result == null) return null;

      final current = result['current_business_id'] as String?;
      if (current != null && current.isNotEmpty) return current.trim();

      final businessIds = result['business_ids'] as List<dynamic>?;
      if (businessIds != null && businessIds.isNotEmpty) {
        final first = businessIds.first?.toString();
        if (first != null && first.isNotEmpty) return first.trim();
      }

      return null;
    } catch (e) {
      print('[SubscriptionServiceSupabase] Error resolving business id: $e');
      return null;
    }
  }
}

