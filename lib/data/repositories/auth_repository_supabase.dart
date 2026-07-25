import 'dart:convert';
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
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Registration failed: No user returned');
      }

      // 2. Create profile
      await Supabase.instance.client.from('profiles').upsert({
        'id': response.user!.id,
        'email': email,
        'full_name': name,
      });

      // 3. Create business + membership (via RPC)
      await Supabase.instance.client.rpc('create_business_with_owner', params: {
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
  Future<void> resetPassword(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  @override
  Future<dynamic> getCurrentUser() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return null;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      // Fetch profile and memberships
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, email, full_name, phone_number, photo_url, pin, current_business_id, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) return null;

      final memberships = await Supabase.instance.client
          .from('business_members')
          .select('business_id, role, is_owner, permissions, store_id')
          .eq('user_id', user.id)
          .eq('is_active', true);

      return {
        'id': profile['id'],
        'email': profile['email'],
        'fullName': profile['full_name'],
        'phoneNumber': profile['phone_number'],
        'photoUrl': profile['photo_url'],
        'pin': profile['pin'],
        'currentBusinessId': profile['current_business_id'],
        'createdAt': profile['created_at'],
        'memberships': memberships,
        'businessIds': memberships.map((m) => m['business_id'] as String).toList(),
      };
    } catch (e) {
      return null;
    }
  }

  /// Create a user profile in the profiles table.
  Future<void> createUser(UserModel user) async {
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': user.fullName,
        'phone_number': user.phoneNumber,
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
        if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
          'phone_number': user.phoneNumber,
        'photo_url': user.photoUrl,
        'pin': user.pin,
        'current_business_id': user.currentBusinessId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }
}

