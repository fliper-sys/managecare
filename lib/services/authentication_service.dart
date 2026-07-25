import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/worker_permissions.dart';
import '../data/models/user_model.dart';

/// Result of resolving whether a signed-in user is allowed access.
///
/// NOTE: this is currently a pass-through stub - the soft-delete/recovery
/// gate that existed against Firestore (deletion_recovery_service.dart) has
/// not been ported to the new backend yet. That is deliberately deferred
/// (matches Phase 6 of the migration plan: purge cron jobs + recovery
/// windows) since no real users are on the new backend yet. Before this goes
/// live for real users, this needs the same gating logic reimplemented
/// against `profiles`/`business_members`.
class ResolvedUserAccess {
  final bool isAllowed;
  final UserModel? user;
  final String? message;
  final bool recoveredAccount;
  final bool recoveredBusiness;

  const ResolvedUserAccess({
    required this.isAllowed,
    this.user,
    this.message,
    this.recoveredAccount = false,
    this.recoveredBusiness = false,
  });
}

/// Comprehensive authentication service handling owner and worker login,
/// backed by the self-hosted Supabase stack (GoTrue + Postgres) instead of
/// Firebase Auth + Firestore.
class AuthenticationService {
  final GoTrueClient _auth = Supabase.instance.client.auth;
  final SupabaseClient _db = Supabase.instance.client;

  /// Authenticate user with email and password.
  /// Returns UserModel on success, throws exception on failure.
  Future<UserModel> authenticateUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        throw Exception('Authentication failed: No user returned');
      }

      final userModel = await _getAccessibleUser(
        response.user!.id,
        allowSelfRecovery: true,
      );

      if (userModel == null) {
        throw Exception('User profile not found in database');
      }

      return userModel;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Authentication error: ${e.toString()}');
    }
  }

  /// Stubbed pass-through - see ResolvedUserAccess doc comment.
  Future<ResolvedUserAccess> resolveUserAccess(
    String userId, {
    bool allowSelfRecovery = false,
  }) async {
    try {
      final userModel = await _buildUserModel(userId);
      if (userModel == null) {
        return const ResolvedUserAccess(
          isAllowed: false,
          message: 'User profile not found.',
        );
      }
      return ResolvedUserAccess(isAllowed: true, user: userModel);
    } catch (e) {
      return ResolvedUserAccess(
        isAllowed: false,
        message: 'Failed to load user profile: $e',
      );
    }
  }

  Future<UserModel?> _getAccessibleUser(
    String userId, {
    bool allowSelfRecovery = false,
  }) async {
    final access = await resolveUserAccess(
      userId,
      allowSelfRecovery: allowSelfRecovery,
    );

    if (!access.isAllowed || access.user == null) {
      try {
        await signOut();
      } catch (_) {}
      throw Exception(
        access.message ?? 'This account is not available right now.',
      );
    }

    return access.user;
  }

  /// Assembles a UserModel by joining profiles + business_members +
  /// businesses. Unlike the Firestore model (which mirrored subscription
  /// fields directly onto the user document), subscription data correctly
  /// lives on `businesses` in the new schema and is joined in here.
  Future<UserModel?> _buildUserModel(String userId) async {
    final profile = await _db
        .from('profiles')
        .select('id, email, full_name, phone_number, photo_url, pin, current_business_id, created_at, updated_at')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) return null;

    final memberships = await _db
        .from('business_members')
        .select('business_id, role, is_owner, permissions, store_id, is_active')
        .eq('user_id', userId);

    final businessIds = memberships
        .map((m) => m['business_id'] as String)
        .toList(growable: false);

    String? currentBusinessId = profile['current_business_id'] as String?;
    Map<String, dynamic>? currentMembership;
    if (currentBusinessId != null) {
      currentMembership = memberships.cast<Map<String, dynamic>?>().firstWhere(
            (m) => m?['business_id'] == currentBusinessId,
            orElse: () => null,
          );
    }
    // Fall back to the first membership if there's no (or a stale) current
    // business selection.
    currentMembership ??= memberships.isNotEmpty ? memberships.first : null;
    currentBusinessId = currentMembership?['business_id'] as String?;

    Map<String, dynamic>? business;
    if (currentBusinessId != null) {
      business = await _db
          .from('businesses')
          .select(
              'business_type, subscription_plan, subscription_start_date, subscription_end_date, is_subscription_active')
          .eq('id', currentBusinessId)
          .maybeSingle();
    }

    final permissions = (currentMembership?['permissions'] as Map<String, dynamic>?)
            ?.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList() ??
        const <String>[];

    return UserModel(
      id: profile['id'] as String,
      email: (profile['email'] as String?) ?? '',
      fullName: (profile['full_name'] as String?) ?? '',
      photoUrl: profile['photo_url'] as String?,
      phoneNumber: profile['phone_number'] as String?,
      role: (currentMembership?['role'] as String?) ?? 'staff',
      permissions: permissions,
      businessId: currentBusinessId ?? '',
      businessIds: businessIds,
      currentBusinessId: currentBusinessId,
      preferredBusinessId: currentBusinessId,
      businessType: business?['business_type'] as String?,
      storeId: currentMembership?['store_id'] as String?,
      isActive: (currentMembership?['is_active'] as bool?) ?? true,
      isOwner: (currentMembership?['is_owner'] as bool?) ?? false,
      pin: profile['pin'] as String?,
      hasActiveSubscription: (business?['is_subscription_active'] as bool?) ?? false,
      subscriptionPlan: business?['subscription_plan'] as String?,
      subscriptionStartDate: business?['subscription_start_date'] != null
          ? DateTime.tryParse(business!['subscription_start_date'] as String)
          : null,
      subscriptionEndDate: business?['subscription_end_date'] != null
          ? DateTime.tryParse(business!['subscription_end_date'] as String)
          : null,
      createdAt: DateTime.tryParse(profile['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(profile['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Create a new worker: goes through managecare-admin-api (server-side,
  /// service-role key) instead of the temporary secondary Firebase app
  /// instance trick the old code used to avoid hijacking the owner's
  /// session - the admin API never touches the caller's session at all.
  Future<UserModel> createWorkerUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required String businessId,
    String? businessType,
    String? phoneNumber,
    String? pin,
  }) async {
    final accessToken = _auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw Exception('You must be signed in to create a worker.');
    }

    final permissions = <String, bool>{
      for (final p in WorkerPermissions.getPermissionsForRole(role)) p: true,
    };

    http.Response response;
    try {
      response = await http.post(
        Uri.parse('${SupabaseConfig.adminApiUrl}/workers'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'business_id': businessId,
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'role': role,
          'permissions': permissions,
        }),
      );
    } catch (e) {
      throw Exception('Failed to reach worker management service: $e');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Failed to create worker');
    }

    final randomPin =
        pin ?? (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

    return UserModel(
      id: body['id'] as String,
      email: email.trim(),
      fullName: fullName.trim(),
      phoneNumber: phoneNumber,
      role: role,
      permissions: WorkerPermissions.getPermissionsForRole(role),
      businessId: businessId,
      businessIds: [businessId],
      currentBusinessId: businessId,
      preferredBusinessId: businessId,
      businessType: businessType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
      isOwner: false,
      pin: randomPin,
    );
  }

  /// Verify worker credentials for manual verification.
  /// NOTE: like the previous Firebase implementation, this replaces the
  /// current session as a side effect of calling signInWithPassword.
  Future<bool> verifyWorkerCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response.user != null;
    } catch (e) {
      return false;
    }
  }

  static Exception _handleAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return Exception('Incorrect email or password. Please try again');
    }
    if (msg.contains('email not confirmed')) {
      return Exception('Please confirm your email address before signing in');
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return Exception('An account already exists with this email');
    }
    if (msg.contains('password') && msg.contains('least')) {
      return Exception('Password is too weak - please choose a stronger one');
    }
    if (msg.contains('user not found')) {
      return Exception('No user found with this email address');
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return Exception('Too many attempts. Please try again later');
    }
    return Exception('Authentication failed: ${e.message}');
  }

  /// Authenticate a worker by email and password.
  ///
  /// The previous Firestore-backed version also supported signing in with a
  /// short numeric "worker ID" (looked up in a separate `workers`
  /// collection, falling back to email). GoTrue only supports email-based
  /// sign-in natively, so that lookup has been dropped for now - workers
  /// sign in with email, same as owners. A short-code lookup can be
  /// reintroduced later (e.g. a `worker_code` column on business_members)
  /// if the cashier/POS workflow needs it.
  Future<UserModel> authenticateWorkerByWorkerId({
    required String workerId,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: workerId.trim(),
        password: password,
      );

      if (response.user == null) {
        throw Exception('Authentication failed');
      }

      final resolvedUser = await _getAccessibleUser(
        response.user!.id,
        allowSelfRecovery: true,
      );
      if (resolvedUser == null) {
        throw Exception('Worker profile not found in database');
      }
      return resolvedUser;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Worker authentication failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  bool get isUserAuthenticated => _auth.currentUser != null;

  /// Kept for API compatibility with the previous Firebase-backed service;
  /// not referenced elsewhere in the codebase as of this migration.
  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user);
}
