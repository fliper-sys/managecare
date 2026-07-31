import 'dart:async';

import '../data/models/user_model.dart';
import 'email_service.dart';
import 'managecare_api_client.dart';

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

  final EmailService _emailService;
  final ManagecareApiClient _api;

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
    _plan(
        family: familyFuel,
        tier: 'tier1',
        durationCode: '3m',
        price: 33900.0,
        days: 90,
        features: [
          '1 location',
          '2 pumps',
          '3 workers',
          '50 minimart products'
        ],
        limits: {
          'locations': 1,
          'branches': 0,
          'pumps': 2,
          'pumps_per_location': 2,
          'workers': 3,
          'workers_per_location': 3,
          'products': 50,
          'products_per_location': 50
        }),
    _plan(
        family: familyFuel,
        tier: 'tier1',
        durationCode: '6m',
        price: 56500.0,
        days: 180,
        features: [
          '1 location',
          '2 pumps',
          '3 workers',
          '50 minimart products'
        ],
        limits: {
          'locations': 1,
          'branches': 0,
          'pumps': 2,
          'pumps_per_location': 2,
          'workers': 3,
          'workers_per_location': 3,
          'products': 50,
          'products_per_location': 50
        }),
    _plan(
        family: familyFuel,
        tier: 'tier1',
        durationCode: '12m',
        price: 111800.0,
        days: 365,
        features: [
          '1 location',
          '2 pumps',
          '3 workers',
          '50 minimart products'
        ],
        limits: {
          'locations': 1,
          'branches': 0,
          'pumps': 2,
          'pumps_per_location': 2,
          'workers': 3,
          'workers_per_location': 3,
          'products': 50,
          'products_per_location': 50
        }),
    _plan(
        family: familyFuel,
        tier: 'tier2',
        durationCode: '3m',
        price: 47615.0,
        days: 90,
        features: [
          '2 locations',
          '5 pumps per location',
          '7 workers per location',
          '150 products per location'
        ],
        limits: {
          'locations': 2,
          'branches': 1,
          'pumps': 10,
          'pumps_per_location': 5,
          'workers': 14,
          'workers_per_location': 7,
          'products': 300,
          'products_per_location': 150
        }),
    _plan(
        family: familyFuel,
        tier: 'tier2',
        durationCode: '6m',
        price: 85600.0,
        days: 180,
        features: [
          '2 locations',
          '5 pumps per location',
          '7 workers per location',
          '150 products per location'
        ],
        limits: {
          'locations': 2,
          'branches': 1,
          'pumps': 10,
          'pumps_per_location': 5,
          'workers': 14,
          'workers_per_location': 7,
          'products': 300,
          'products_per_location': 150
        }),
    _plan(
        family: familyFuel,
        tier: 'tier2',
        durationCode: '12m',
        price: 152045.0,
        days: 365,
        features: [
          '2 locations',
          '5 pumps per location',
          '7 workers per location',
          '150 products per location'
        ],
        limits: {
          'locations': 2,
          'branches': 1,
          'pumps': 10,
          'pumps_per_location': 5,
          'workers': 14,
          'workers_per_location': 7,
          'products': 300,
          'products_per_location': 150
        }),
    _plan(
        family: familyFuel,
        tier: 'tier3',
        durationCode: '3m',
        price: 80775.0,
        days: 90,
        features: [
          '4 locations',
          '10 pumps per location',
          '12 workers per location',
          '250 products per location'
        ],
        limits: {
          'locations': 4,
          'branches': 3,
          'pumps': 40,
          'pumps_per_location': 10,
          'workers': 48,
          'workers_per_location': 12,
          'products': 1000,
          'products_per_location': 250
        }),
    _plan(
        family: familyFuel,
        tier: 'tier3',
        durationCode: '6m',
        price: 145395.0,
        days: 180,
        features: [
          '4 locations',
          '10 pumps per location',
          '12 workers per location',
          '250 products per location'
        ],
        limits: {
          'locations': 4,
          'branches': 3,
          'pumps': 40,
          'pumps_per_location': 10,
          'workers': 48,
          'workers_per_location': 12,
          'products': 1000,
          'products_per_location': 250
        }),
    _plan(
        family: familyFuel,
        tier: 'tier3',
        durationCode: '12m',
        price: 258480.0,
        days: 365,
        features: [
          '4 locations',
          '10 pumps per location',
          '12 workers per location',
          '250 products per location'
        ],
        limits: {
          'locations': 4,
          'branches': 3,
          'pumps': 40,
          'pumps_per_location': 10,
          'workers': 48,
          'workers_per_location': 12,
          'products': 1000,
          'products_per_location': 250
        }),
    _plan(
        family: familyFuel,
        tier: 'tier4',
        durationCode: '3m',
        price: 137318.0,
        days: 90,
        features: [
          '10 locations',
          '20 pumps per location',
          '25 workers per location',
          '500 products per location'
        ],
        limits: {
          'locations': 10,
          'branches': 9,
          'pumps': 200,
          'pumps_per_location': 20,
          'workers': 250,
          'workers_per_location': 25,
          'products': 5000,
          'products_per_location': 500
        }),
    _plan(
        family: familyFuel,
        tier: 'tier4',
        durationCode: '6m',
        price: 247173.0,
        days: 180,
        features: [
          '10 locations',
          '20 pumps per location',
          '25 workers per location',
          '500 products per location'
        ],
        limits: {
          'locations': 10,
          'branches': 9,
          'pumps': 200,
          'pumps_per_location': 20,
          'workers': 250,
          'workers_per_location': 25,
          'products': 5000,
          'products_per_location': 500
        }),
    _plan(
        family: familyFuel,
        tier: 'tier4',
        durationCode: '12m',
        price: 439418.0,
        days: 365,
        features: [
          '10 locations',
          '20 pumps per location',
          '25 workers per location',
          '500 products per location'
        ],
        limits: {
          'locations': 10,
          'branches': 9,
          'pumps': 200,
          'pumps_per_location': 20,
          'workers': 250,
          'workers_per_location': 25,
          'products': 5000,
          'products_per_location': 500
        }),
    _plan(
        family: familyFuel,
        tier: 'premium',
        durationCode: 'monthly',
        price: 0.0,
        days: 30,
        features: [
          'Add-on access',
          'Attendance and clock-in system',
          'Unlimited pumps per location',
          'Up to 50 locations',
          'No inventory limit',
          'Custom pricing'
        ],
        limits: {
          'locations': 50,
          'branches': 49,
          'pumps': null,
          'pumps_per_location': null,
          'workers': null,
          'workers_per_location': null,
          'products': null,
          'products_per_location': null
        }),
  ];

  SubscriptionService({
    EmailService? emailService,
    ManagecareApiClient? api,
  })  : _emailService = emailService ?? EmailService(),
        _api = api ?? ManagecareApiClient.instance;

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
      case 'bakery_shop':
      case 'bakeshop':
        return 'bakery';
      case 'petrol_station':
      case 'petroleum_station':
      case 'petroleum station':
      case 'filling_station':
      case 'filling station':
      case 'gas_station':
      case 'gas station':
      case 'fuel_station':
      case 'fuel station':
        return 'petroleum';
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
      case 'gas':
      case 'petrol':
      case 'petroleum':
      case 'filling station':
      case 'fuel':
        return familyFuel;
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
      case familyFuel:
        if (products <= 50 && staff <= 3) return 'tier1';
        if (products <= 150 && staff <= 7) return 'tier2';
        if (products <= 250 && staff <= 12) return 'tier3';
        if (products <= 500 && staff <= 25) return 'tier4';
        return 'premium';
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
      case 'fuel_addons':
      case 'attendance':
      case 'clock_in':
      case 'worker_attendance':
        return family == familyFuel && rank >= getTierRank('premium');
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
      case 'fuel_addons':
      case 'attendance':
      case 'clock_in':
      case 'worker_attendance':
        return family == familyFuel ? 'premium' : 'unlimited';
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
      case 't4':
      case 'tier4':
        return 'tier4';
      case 'premium':
      case 'fuel_premium':
        return 'premium';
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
        return family == familyFuel
            ? ['products_per_location', 'products', 'inventory_products']
            : family == familyKitchen || family == familyLounge
            ? ['inventory_products', 'menu_items', 'products']
            : ['products', 'inventory_products'];
      case 'pumps':
        return ['pumps_per_location', 'pumps'];
      case 'workers':
        return family == familyFuel
            ? ['workers_per_location', 'workers']
            : ['workers'];
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
      final response = await _api.get('/api/subscriptions/user/$userId');
      final data = Map<String, dynamic>.from(response as Map);
      return {
        'hasActiveSubscription': data['has_active_subscription'] ?? false,
        'subscriptionPlan': data['subscription_plan'],
        'subscriptionTier': data['subscription_tier'],
        'subscriptionStartDate': data['subscription_start_date'],
        'subscriptionEndDate': data['subscription_end_date'],
        'subscriptionPaymentRequired':
            data['subscription_payment_required'] ?? true,
        'subscriptionAmount': data['subscription_amount'],
        'subscriptionStatus': data['subscription_status'],
        'currentBusinessId': data['current_business_id'],
      };
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBusinessSubscription(
      String businessId) async {
    try {
      final response = await _api.get('/api/subscriptions/business/$businessId');
      final data = Map<String, dynamic>.from(response as Map);
      return {
        'id': data['id'],
        'name': data['name'],
        'businessType': data['business_type'],
        'subscriptionPlan': data['subscription_plan'],
        'subscriptionTier': data['subscription_tier'],
        'businessClass': data['business_class'],
        'subscriptionFamily': data['subscription_family'],
        'subscriptionStatus': data['subscription_status'],
        'subscriptionReviewStatus': data['subscription_review_status'],
        'subscriptionStartDate': data['subscription_start_date'],
        'subscriptionEndDate': data['subscription_end_date'],
        'isSubscriptionActive': data['is_subscription_active'] ?? false,
        'pendingSubscriptionPlan': null,
      };
    } catch (e) {
      print('Error getting business subscription: $e');
      return null;
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
      final plan = await _resolvePlanForNotification(userId, businessId) ??
          _fallbackNotificationPlan();

      await _api.post('/api/subscriptions/expire', body: {
        'userId': userId,
        if (businessId != null && businessId.isNotEmpty) 'businessId': businessId,
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
      final plan = await _resolvePlanForNotification(userId, businessId) ??
          _fallbackNotificationPlan();

      await _api.post('/api/subscriptions/cancel', body: {
        'userId': userId,
        if (businessId != null && businessId.isNotEmpty) 'businessId': businessId,
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
      final response = await _api.post('/api/subscriptions/validate', body: {
        'userId': userId,
        if (businessId != null && businessId.isNotEmpty) 'businessId': businessId,
      });
      return Map<String, dynamic>.from(response as Map)['valid'] == true;
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
      final response = await _api.post('/api/subscriptions/validate', body: {
        'businessId': businessId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      });
      return Map<String, dynamic>.from(response as Map)['valid'] == true;
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

      final response = await _api.post('/api/subscriptions/activate', body: {
        'userId': userId,
        if (businessId != null && businessId.isNotEmpty) 'businessId': businessId,
        'planId': plan.id,
        'planTier': plan.tierId,
        'planFamily': plan.businessFamily,
        'durationDays': plan.durationInDays,
        'amount': amount,
        'receiptUrl': receiptUrl,
        'mode': 'immediate',
      });
      final data = Map<String, dynamic>.from(response as Map);
      final targetBusinessId = data['businessId']?.toString();
      final now = DateTime.parse(data['startDate'].toString());
      final endDate = DateTime.parse(data['endDate'].toString());

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

      final response = await _api.post('/api/subscriptions/activate', body: {
        'userId': userId,
        if (businessId != null && businessId.isNotEmpty) 'businessId': businessId,
        'planId': plan.id,
        'planTier': plan.tierId,
        'planFamily': plan.businessFamily,
        'durationDays': plan.durationInDays,
        'amount': amount,
        'receiptUrl': receiptUrl,
        'mode': 'renew',
      });
      final data = Map<String, dynamic>.from(response as Map);
      final targetBusinessId = data['businessId']?.toString();
      final startDate = DateTime.parse(data['startDate'].toString());
      final newEndDate = DateTime.parse(data['endDate'].toString());
      final action = data['action']?.toString() ?? 'subscription_activated';

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

  /// Admin-driven: manually applies a plan directly to a business (no
  /// per-user profile write), used when an admin approves a subscription.
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

      await _api.post('/api/subscriptions/business/$businessId/sync', body: {
        'planId': plan.id,
        'planTier': plan.tierId,
        'planFamily': plan.businessFamily,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'amount': amount,
        'receiptUrl': receiptUrl,
      });

      return true;
    } catch (e) {
      print('[SubscriptionService] Error syncing subscription to business: $e');
      return false;
    }
  }

  Future<String?> _resolveBusinessIdForUser(String userId) async {
    try {
      final response = await _api.get('/api/subscriptions/user/$userId');
      final data = Map<String, dynamic>.from(response as Map);
      final currentBusinessId = data['current_business_id']?.toString();
      if (currentBusinessId != null && currentBusinessId.trim().isNotEmpty) {
        return currentBusinessId.trim();
      }
      final subscriptionBusinessId = data['subscription_business_id']?.toString();
      if (subscriptionBusinessId != null && subscriptionBusinessId.trim().isNotEmpty) {
        return subscriptionBusinessId.trim();
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
      Map<String, dynamic> userData = <String, dynamic>{};
      try {
        final response = await _api.get('/api/subscriptions/user/$userId');
        userData = Map<String, dynamic>.from(response as Map);
      } catch (_) {}
      final recipientEmail =
          (userEmail ?? userData['email']?.toString() ?? '').trim();
      if (recipientEmail.isEmpty) return;

      final recipientName =
          (userName ?? userData['full_name']?.toString() ?? 'Business Owner')
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
      final response =
          await _api.get('/api/subscriptions/business/$resolvedBusinessId');
      final data = Map<String, dynamic>.from(response as Map);
      return {
        'businessName':
            data['name']?.toString().trim().isNotEmpty == true
                ? data['name'].toString().trim()
                : 'Manage Care',
        'businessType': data['business_type']?.toString(),
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
