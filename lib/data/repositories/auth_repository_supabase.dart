import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../services/authentication_service.dart';
import '../../data/models/user_model.dart';

/// Supabase/Postgres-backed implementation of AuthRepository.
///
/// Replaces AuthRepositoryImpl (Firebase Firestore + Auth).
/// Delegates to the already-migrated AuthenticationService.
class AuthRepositorySupabase implements AuthRepository {
  final AuthenticationService _authService;
  final SupabaseClient _supabase;

  AuthRepositorySupabase({
    AuthenticationService? authService,
    SupabaseClient? supabase,
  })  : _authService = authService ?? AuthenticationService(),
        _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<dynamic> login(String email, String password) async {
    try {
      final user = await _authService.authenticateUser(
        email: email,
        password: password,
      );
      return {
        'id': user.id,
        'email': user.email,
        'fullName': user.fullName,
        'role': user.role,
        'isOwner': user.isOwner,
        'businessId': user.businessId,
        'businessIds': user.businessIds,
        'currentBusinessId': user.currentBusinessId,
        'businessType': user.businessType,
        'phoneNumber': user.phoneNumber,
        'hasActiveSubscription': user.hasActiveSubscription,
        'subscriptionPlan': user.subscriptionPlan,
        'permissions': user.permissions,
      };
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<dynamic> register({
    required String email,
    required String password,
    required String name,
    required String businessName,
    required String businessType,
  }) async {
    try {
      // 1. Sign up with GoTrue
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Registration failed: No user returned');
      }

      // 2. Create profile
      await _supabase.from('profiles').upsert({
        'id': response.user!.id,
        'email': email,
        'full_name': name,
      });

      // 3. Create business + membership (via RPC)
      await _supabase.rpc('create_business_with_owner', params: {
        'p_name': businessName,
        'p_business_type': businessType,
        'p_owner_id': response.user!.id,
      });

      return {
        'id': response.user!.id,
        'email': email,
        'fullName': name,
      };
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _authService.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  @override
  Future<void> resetPassword(String email,
      {String accountType = 'owner'}) async {
    try {
      await _authService.requestPasswordReset(
        email: email,
        accountType: accountType,
      );
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  @override
  Future<dynamic> getCurrentUser() async {
    if (_supabase.auth.currentSession == null) return null;
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    Map<String, dynamic>? profile;
    try {
      final merged = await _supabase.rpc('current_user_profile');
      if (merged is Map) profile = Map<String, dynamic>.from(merged);
    } catch (error) {
      debugPrint('[AuthRepositorySupabase] Merged profile read failed: $error');
    }

    if (profile == null) {
      try {
        profile = await _supabase
            .from('profiles')
            .select(
                'id, email, full_name, phone_number, address, job_title, photo_url, pin, current_business_id, created_at')
            .eq('id', user.id)
            .maybeSingle();
      } catch (error) {
        debugPrint('[AuthRepositorySupabase] Profile row read failed: $error');
      }
    }

    final data = profile ?? <String, dynamic>{};
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final metadataName = [
      metadata['full_name'],
      metadata['name'],
      metadata['display_name'],
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final email = (data['email']?.toString().trim().isNotEmpty == true)
        ? data['email'].toString().trim()
        : user.email?.trim() ?? '';
    final fullName = (data['full_name']?.toString().trim().isNotEmpty == true)
        ? data['full_name'].toString().trim()
        : metadataName.isNotEmpty
            ? metadataName
            : email.split('@').first;

    List<Map<String, dynamic>> memberships = [];
    try {
      final rows = await _supabase
          .from('business_members')
          .select('business_id, role, is_owner, permissions, store_id')
          .eq('user_id', user.id)
          .eq('is_active', true);
      memberships = rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (error) {
      debugPrint('[AuthRepositorySupabase] Membership read failed: $error');
    }

    return {
      'id': data['id'] ?? user.id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': data['phone_number'] ?? metadata['phone_number'],
      'address': data['address'],
      'jobTitle': data['job_title'],
      'photoUrl': data['photo_url'] ?? metadata['avatar_url'],
      'pin': data['pin'],
      'currentBusinessId': data['current_business_id'],
      'createdAt': data['created_at'],
      'memberships': memberships,
      'businessIds': memberships
          .map((membership) => membership['business_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
    };
  }

  /// Create a user profile in the profiles table.
  Future<void> createUser(UserModel user) async {
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': user.fullName,
        'phone_number': user.phoneNumber,
        'address': user.address,
        'job_title': user.jobTitle,
        'photo_url': user.photoUrl,
        'pin': user.pin,
        'current_business_id': user.currentBusinessId,
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Update a user profile in the profiles table.
  Future<void> updateUser(UserModel user) async {
    try {
      await _supabase.from('profiles').update({
        if (user.email.isNotEmpty) 'email': user.email,
        if (user.fullName.isNotEmpty) 'full_name': user.fullName,
        'phone_number': user.phoneNumber,
        'address': user.address,
        'job_title': user.jobTitle,
        'photo_url': user.photoUrl,
        'pin': user.pin,
        'current_business_id': user.currentBusinessId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> setCurrentBusiness(String businessId) async {
    try {
      await _supabase.rpc(
        'set_current_business',
        params: {'p_business_id': businessId},
      );
    } catch (e) {
      throw Exception('Failed to switch business: $e');
    }
  }
}
