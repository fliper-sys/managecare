import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/business_repository.dart';
import '../../core/config/supabase_config.dart';

/// Supabase/Postgres-backed implementation of BusinessRepository.
///
/// Replaces BusinessRepositoryImpl (Firebase Firestore).
/// Reads from businesses + business_members tables via REST API.
class BusinessRepositorySupabase implements BusinessRepository {
  final Dio _http;
  final SupabaseClient _supabase;

  BusinessRepositorySupabase({
    Dio? http,
    SupabaseClient? supabase,
  })  : _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )),
        _supabase = supabase ?? Supabase.instance.client;

  String? get _accessToken => _supabase.auth.currentSession?.accessToken;
  Map<String, dynamic> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (data is String) return data;
    } catch (_) {}
    return e.message ?? 'Unknown error';
  }

  @override
  Future<dynamic> getBusiness(String businessId) async {
    try {
      final response = await _supabase
          .from('businesses')
          .select('''
            id, name, business_type, owner_id, address, phone, email,
            currency, logo_url, store_ids, is_active,
            subscription_tier, subscription_start_date, subscription_end_date,
            is_subscription_active, subscription_plan,
            created_at, updated_at
          ''')
          .eq('id', businessId)
          .maybeSingle();
      return response;
    } catch (e) {
      // Fallback to API route
      try {
        final response = await _http.get(
          '/businesses/$businessId',
          options: Options(headers: _headers),
        );
        return response.data;
      } on DioException catch (e2) {
        throw Exception('Failed to get business: ${_extractError(e2)}');
      }
    }
  }

  @override
  Future<void> createBusiness(Map<String, dynamic> businessData) async {
    try {
      // Use Supabase RPC to create business with owner membership
      await _supabase.rpc('create_business_with_owner', params: {
        'p_name': businessData['name'] ?? 'My Business',
        'p_business_type': businessData['businessType'] ?? 'retail',
        'p_owner_id': businessData['ownerId'] ?? _supabase.auth.currentUser?.id,
      });
    } catch (e) {
      // Fallback: direct insert
      try {
        final businessId = businessData['id'];
        await _supabase.from('businesses').insert({
          if (businessId != null) 'id': businessId,
          'name': businessData['name'] ?? 'My Business',
          'business_type': businessData['businessType'] ?? 'retail',
          'owner_id':
              businessData['ownerId'] ?? _supabase.auth.currentUser?.id,
          'address': businessData['address'],
          'phone': businessData['phone'],
          'email': businessData['email'],
          'currency': businessData['currency'] ?? 'NGN',
          'is_active': true,
        });
      } catch (e2) {
        throw Exception('Failed to create business: $e2');
      }
    }
  }

  @override
  Future<void> updateBusiness(
      String businessId, Map<String, dynamic> businessData) async {
    try {
      await _supabase.from('businesses').update({
        if (businessData.containsKey('name')) 'name': businessData['name'],
        if (businessData.containsKey('businessType'))
          'business_type': businessData['businessType'],
        if (businessData.containsKey('address'))
          'address': businessData['address'],
        if (businessData.containsKey('phone'))
          'phone': businessData['phone'],
        if (businessData.containsKey('email'))
          'email': businessData['email'],
        if (businessData.containsKey('currency'))
          'currency': businessData['currency'],
        if (businessData.containsKey('logoUrl') ||
            businessData.containsKey('logo_url'))
          'logo_url': businessData['logoUrl'] ?? businessData['logo_url'],
        if (businessData.containsKey('isActive') ||
            businessData.containsKey('is_active'))
          'is_active':
              businessData['isActive'] ?? businessData['is_active'],
        if (businessData.containsKey('businessType'))
          'business_type': businessData['businessType'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', businessId);
    } catch (e) {
      throw Exception('Failed to update business: $e');
    }
  }

  @override
  Future<void> deleteBusiness(String businessId) async {
    try {
      // Soft delete
      await _supabase
          .from('businesses')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', businessId);
    } catch (e) {
      throw Exception('Failed to delete business: $e');
    }
  }

  /// Alias for getBusiness to match the Firestore-backed interface pattern.
  Future<dynamic> getBusinessById(String businessId) async {
    return getBusiness(businessId);
  }

  @override
  Future<List<dynamic>> getAllBusinesses(String userId) async {
    try {
      final response = await _http.get(
        '/businesses',
        options: Options(headers: _headers),
      );
      return (response.data as List?) ?? [];
    } on DioException catch (e) {
      // Fallback to direct Supabase query
      try {
        final businesses = await _supabase
            .from('business_members')
            .select('business_id, role, is_owner, businesses(*)')
            .eq('user_id', userId)
            .eq('is_active', true);
        return businesses
            .map((m) => {
                  ...Map<String, dynamic>.from(m['businesses'] as Map),
                  'member_role': m['role'],
                  'is_owner': m['is_owner'],
                })
            .toList();
      } catch (e2) {
        throw Exception('Failed to get businesses: $e2');
      }
    }
  }
}

