import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_model.dart';

class BusinessRepository {
  final SupabaseClient _supabase;

  BusinessRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Map<String, dynamic> _toPostgres(BusinessModel business) {
    return {
      'id': business.id,
      'name': business.name,
      'business_type': business.businessType,
      'owner_id': business.ownerId,
      'address': business.address,
      'phone': business.phone,
      'email': business.email,
      'currency': business.currency ?? 'NGN',
      'logo_url': business.logoUrl ?? business.photoUrl,
      'subscription_tier': business.subscriptionTier,
      'subscription_plan': business.subscriptionPlan,
      'subscription_start_date':
          business.subscriptionStartDate?.toIso8601String(),
      'subscription_end_date': business.subscriptionEndDate?.toIso8601String(),
      'is_subscription_active': business.isSubscriptionActive,
      'is_active': business.isActive,
      'created_at': business.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'settings': business.settings,
    }..removeWhere((_, value) => value == null);
  }

  BusinessModel _fromPostgres(Map<String, dynamic> data) {
    String? s(String snake, [String? camel]) =>
        (data[snake] ?? (camel == null ? null : data[camel]))?.toString();

    DateTime? dt(String snake, [String? camel]) {
      final value = data[snake] ?? (camel == null ? null : data[camel]);
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    bool b(String snake, String camel, bool fallback) {
      final value = data[snake] ?? data[camel];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return fallback;
    }

    int? i(String snake, String camel) {
      final value = data[snake] ?? data[camel];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    return BusinessModel(
      id: s('id') ?? '',
      name: s('name') ?? '',
      businessType: s('business_type', 'businessType') ?? '',
      description: s('description'),
      ownerId: s('owner_id', 'ownerId') ?? '',
      logoUrl: s('logo_url', 'logoUrl'),
      photoUrl: s('photo_url', 'photoUrl'),
      currency: s('currency') ?? 'NGN',
      taxId: s('tax_id', 'taxId'),
      email: s('email'),
      phone: s('phone'),
      website: s('website'),
      address: s('address'),
      city: s('city'),
      state: s('state'),
      country: s('country'),
      postalCode: s('postal_code', 'postalCode'),
      referralEmail: s('referral_email', 'referralEmail'),
      subscriptionTier: s('subscription_tier', 'subscriptionTier') ?? 'tier1',
      businessClass: s('business_class', 'businessClass') ?? 'tier1',
      subscriptionPlan: s('subscription_plan', 'subscriptionPlan'),
      subscriptionStartDate:
          dt('subscription_start_date', 'subscriptionStartDate'),
      subscriptionEndDate: dt('subscription_end_date', 'subscriptionEndDate'),
      isSubscriptionActive:
          b('is_subscription_active', 'isSubscriptionActive', true),
      isActive: b('is_active', 'isActive', true),
      createdAt: dt('created_at', 'createdAt') ?? DateTime.now(),
      updatedAt: dt('updated_at', 'updatedAt'),
      totalWorkers: i('total_workers', 'totalWorkers'),
      totalProducts: i('total_products', 'totalProducts'),
      totalCustomers: i('total_customers', 'totalCustomers'),
      settings: data['settings'] is Map
          ? Map<String, dynamic>.from(data['settings'] as Map)
          : null,
    );
  }

  Future<BusinessModel?> getBusinessById(String id) async {
    try {
      final data = await _supabase
          .from('businesses')
          .select()
          .eq('id', id)
          .eq('is_active', true)
          .maybeSingle();
      if (data == null) return null;
      return _fromPostgres(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('[BusinessRepository] getBusinessById failed: $e');
      throw Exception('Failed to get business: $e');
    }
  }

  Future<List<BusinessModel>> getUserBusinesses(String userId) async {
    try {
      final owned = await _supabase
          .from('businesses')
          .select()
          .eq('owner_id', userId)
          .eq('is_active', true);

      final byId = <String, BusinessModel>{};
      for (final row in owned) {
        final business = _fromPostgres(Map<String, dynamic>.from(row));
        if (business.id.isNotEmpty) byId[business.id] = business;
      }

      final memberships = await _supabase
          .from('business_members')
          .select('businesses(*)')
          .eq('user_id', userId)
          .eq('is_active', true);

      for (final row in memberships) {
        final businessData = row['businesses'];
        if (businessData is Map) {
          final business =
              _fromPostgres(Map<String, dynamic>.from(businessData));
          if (business.id.isNotEmpty && business.isActive) {
            byId[business.id] = business;
          }
        }
      }

      debugPrint(
          '[BusinessRepository] Loaded ${byId.length} businesses from Postgres');
      return byId.values.toList();
    } catch (e) {
      debugPrint('[BusinessRepository] getUserBusinesses failed: $e');
      throw Exception('Failed to get businesses: $e');
    }
  }

  Future<void> createBusiness(BusinessModel business) async {
    try {
      await _supabase.rpc('create_business_with_owner', params: {
        'p_business_id': business.id,
        'p_name': business.name,
        'p_business_type': business.businessType,
        'p_owner_id': business.ownerId,
        'p_address': business.address,
        'p_phone': business.phone,
        'p_email': business.email,
        'p_currency': business.currency ?? 'NGN',
        'p_logo_url': business.logoUrl ?? business.photoUrl,
        'p_subscription_tier': business.subscriptionTier,
        'p_subscription_plan': business.subscriptionPlan,
        'p_subscription_start_date':
            business.subscriptionStartDate?.toIso8601String(),
        'p_subscription_end_date':
            business.subscriptionEndDate?.toIso8601String(),
        'p_is_subscription_active': business.isSubscriptionActive,
      });
    } catch (e) {
      debugPrint('[BusinessRepository] createBusiness failed: $e');
      throw Exception('Failed to create business: $e');
    }
  }

  Future<void> updateBusiness(BusinessModel business) async {
    try {
      await _supabase
          .from('businesses')
          .update(_toPostgres(business)..remove('created_at'))
          .eq('id', business.id);
    } catch (e) {
      debugPrint('[BusinessRepository] updateBusiness failed: $e');
      throw Exception('Failed to update business: $e');
    }
  }

  Future<void> deleteBusiness(String id) async {
    try {
      await _supabase.from('businesses').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete business: $e');
    }
  }

  Stream<BusinessModel?> businessStream(String id) async* {
    yield await getBusinessById(id);
  }

  Future<void> updateBusinessStats({
    required String businessId,
    int? totalWorkers,
    int? totalProducts,
    int? totalCustomers,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      await _supabase.from('businesses').update(updates).eq('id', businessId);
    } catch (e) {
      debugPrint('[BusinessRepository] updateBusinessStats failed: $e');
    }
  }

  Future<void> updateSubscription({
    required String businessId,
    required String tier,
    required DateTime startDate,
    required DateTime endDate,
    bool isActive = true,
  }) async {
    await _supabase.from('businesses').update({
      'subscription_tier': tier,
      'subscription_start_date': startDate.toIso8601String(),
      'subscription_end_date': endDate.toIso8601String(),
      'is_subscription_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', businessId);
  }

  Future<List<BusinessModel>> getBusinessesByType(String businessType) async {
    final rows = await _supabase
        .from('businesses')
        .select()
        .eq('business_type', businessType)
        .eq('is_active', true)
        .limit(50);
    return rows
        .map((row) => _fromPostgres(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> getBusinessCount() async {
    final rows = await _supabase.from('businesses').select('id');
    return rows.length;
  }

  Future<void> createDefaultFuelProducts(
    String businessId, {
    String fuelUnit = 'L',
  }) async {
    final now = DateTime.now().toIso8601String();
    final defaults = [
      {
        'business_id': businessId,
        'name': 'Petrol',
        'unit_price': 200.0,
        'cost_price': 0.0,
        'quantity': 0,
        'category': 'Fuel',
        'unit': fuelUnit,
        'created_at': now,
        'updated_at': now,
      },
      {
        'business_id': businessId,
        'name': 'Diesel',
        'unit_price': 180.0,
        'cost_price': 0.0,
        'quantity': 0,
        'category': 'Fuel',
        'unit': fuelUnit,
        'created_at': now,
        'updated_at': now,
      },
      {
        'business_id': businessId,
        'name': 'Kerosene',
        'unit_price': 150.0,
        'cost_price': 0.0,
        'quantity': 0,
        'category': 'Fuel',
        'unit': fuelUnit,
        'created_at': now,
        'updated_at': now,
      },
      {
        'business_id': businessId,
        'name': 'Cooking Gas (LPG)',
        'unit_price': 12000.0,
        'cost_price': 0.0,
        'quantity': 0,
        'category': 'Fuel',
        'unit': 'cyl',
        'created_at': now,
        'updated_at': now,
      },
    ];

    try {
      await _supabase.from('inventory').upsert(defaults);
    } catch (e) {
      debugPrint('[BusinessRepository] createDefaultFuelProducts failed: $e');
    }
  }

  Future<void> createDefaultBakeryProducts(String businessId) async {
    final now = DateTime.now().toIso8601String();
    final defaults = [
      ['bread_loaf', 'Bread Loaf', 'Bread', 'pcs', 1000.0],
      ['meat_pie', 'Meat Pie', 'Pastry', 'pcs', 800.0],
      ['cupcake', 'Cupcake', 'Cake', 'pcs', 500.0],
      ['small_chops_pack', 'Small Chops Pack', 'Snacks', 'pack', 1500.0],
      ['flour_bag', 'Flour Bag', 'Ingredient', 'bag', 0.0],
      ['birthday_cake', 'Birthday Cake', 'Cake', 'pcs', 15000.0],
    ]
        .map((p) => {
              'business_id': businessId,
              'name': p[1],
              'category': p[2],
              'unit': p[3],
              'unit_price': p[4],
              'cost_price': 0.0,
              'quantity': 0,
              'created_at': now,
              'updated_at': now,
            })
        .toList();

    try {
      await _supabase.from('inventory').upsert(defaults);
    } catch (e) {
      debugPrint('[BusinessRepository] createDefaultBakeryProducts failed: $e');
    }
  }
}
