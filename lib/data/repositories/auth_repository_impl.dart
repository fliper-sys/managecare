import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// Auth repository implementation, backed by the self-hosted Supabase stack.
class AuthRepositoryImpl implements AuthRepository {
  final GoTrueClient _auth;
  final SupabaseClient _db;

  AuthRepositoryImpl({GoTrueClient? auth})
      : _auth = auth ?? Supabase.instance.client.auth,
        _db = Supabase.instance.client;

  @override
  Future<String> login(
      {required String email, required String password}) async {
    try {
      final result = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      return result.user?.id ?? '';
    } catch (e) {
      rethrow;
    }
  }

  /// Business self-registration: creates the auth user, then the business +
  /// owner membership atomically via the create_business_with_owner RPC.
  @override
  Future<void> registerBusiness(
      {required Map<String, dynamic> businessData}) async {
    try {
      final email = businessData['email'] as String;
      final password = businessData['password'] as String;
      final businessName = businessData['businessName'] as String?;
      final businessType = businessData['businessType'] as String?;

      final result = await _auth.signUp(email: email, password: password);
      if (result.user == null) {
        throw Exception('Failed to create authentication account');
      }

      if (businessName != null && businessType != null) {
        await _db.rpc('create_business_with_owner', params: {
          'p_name': businessName,
          'p_business_type': businessType,
        });
      }

      final fullName = businessData['fullName'] as String?;
      if (fullName != null) {
        await _db
            .from('profiles')
            .update({'full_name': fullName}).eq('id', result.user!.id);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// No-op: profiles are created automatically via a Postgres trigger on
  /// auth.users insert (see handle_new_user in the tenancy backbone schema).
  @override
  Future<void> createUser(UserModel user) async {
    try {
      await updateUser(user);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCurrentUser(String uid) async {
    try {
      final profile = await _db
          .from('profiles')
          .select('id, email, full_name, phone_number, photo_url, created_at, updated_at')
          .eq('id', uid)
          .maybeSingle();

      if (profile != null) {
        return UserModel(
          id: profile['id'] as String,
          email: (profile['email'] as String?) ?? '',
          fullName: (profile['full_name'] as String?) ?? '',
          phoneNumber: profile['phone_number'] as String?,
          photoUrl: profile['photo_url'] as String?,
          role: 'owner',
          businessId: '',
          createdAt:
              DateTime.tryParse(profile['created_at'] as String? ?? '') ?? DateTime.now(),
          updatedAt:
              DateTime.tryParse(profile['updated_at'] as String? ?? '') ?? DateTime.now(),
          isActive: true,
        );
      }

      final authUser = _auth.currentUser;
      if (authUser != null && authUser.id == uid) {
        return UserModel(
          id: authUser.id,
          email: authUser.email ?? '',
          fullName: (authUser.userMetadata?['full_name'] as String?) ?? '',
          role: 'owner',
          businessId: '',
          createdAt: DateTime.tryParse(authUser.createdAt) ?? DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createOrUpdateUser(UserModel user) => updateUser(user);

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      await _db.from('profiles').update({
        'email': user.email,
        'full_name': user.fullName,
        'phone_number': user.phoneNumber,
        'photo_url': user.photoUrl,
        'pin': user.pin,
      }).eq('id', user.id);
    } catch (e) {
      rethrow;
    }
  }
}
