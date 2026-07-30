import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/worker_permissions.dart';
import '../data/models/user_model.dart';

/// Result of resolving whether a signed-in user is allowed access.
///
/// Ports the Firestore-based DeletionRecoveryService's soft-delete/recovery
/// gate to the relational model. The big simplification: business_members
/// rows are never touched by a business soft-delete (membership stays real,
/// the business is just hidden until restored), so none of the old
/// per-user `businessIds`/`deletedBusinessIds` array bookkeeping is needed
/// - "is this business usable" is just `businesses.is_deleted`, checked
/// fresh on every login.
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

  static bool _isPast(dynamic isoString) {
    final dt = DateTime.tryParse(isoString?.toString() ?? '');
    return dt == null || DateTime.now().isAfter(dt);
  }

  Future<ResolvedUserAccess> resolveUserAccess(
    String userId, {
    bool allowSelfRecovery = false,
  }) async {
    try {
      var profile = await _db
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        return const ResolvedUserAccess(
          isAllowed: false,
          message: 'User profile not found.',
        );
      }

      var recoveredAccount = false;
      if (profile['is_deleted'] == true) {
        if (_isPast(profile['recovery_deadline_at'])) {
          return const ResolvedUserAccess(
            isAllowed: false,
            message:
                'This account was deleted and the 30-day recovery window has passed.',
          );
        }
        if (!allowSelfRecovery) {
          return const ResolvedUserAccess(
            isAllowed: false,
            message:
                'This account was deleted. Sign in again to restore it, or contact support.',
          );
        }
        await _db.from('profiles').update({
          'is_deleted': false,
          'is_active': true,
          'deleted_at': null,
          'recovery_deadline_at': null,
          'deleted_by_id': null,
          'deletion_reason': null,
        }).eq('id', userId);
        profile = await _db.from('profiles').select().eq('id', userId).single();
        recoveredAccount = true;
      }

      final memberships = await _db
          .from('business_members')
          .select('business_id, role, is_owner, permissions, store_id, is_active')
          .eq('user_id', userId);

      final businessIds = memberships
          .map((m) => m['business_id'] as String)
          .toList(growable: false);

      final businessesById = <String, Map<String, dynamic>>{};
      if (businessIds.isNotEmpty) {
        final rows = await _db.from('businesses').select().inFilter('id', businessIds);
        for (final row in rows) {
          businessesById[row['id'] as String] = row;
        }
      }

      var usableMemberships = memberships
          .where((m) => businessesById[m['business_id']]?['is_deleted'] != true)
          .toList();

      var recoveredBusiness = false;

      if (usableMemberships.isEmpty && memberships.isNotEmpty) {
        // Every membership points at a deleted business. Only an owner can
        // recover one (a worker has to wait for the owner to do it).
        final deletedOwned = memberships.where((m) => m['is_owner'] == true).toList()
          ..sort((a, b) {
            final aDate = businessesById[a['business_id']]?['deleted_at']?.toString() ?? '';
            final bDate = businessesById[b['business_id']]?['deleted_at']?.toString() ?? '';
            return bDate.compareTo(aDate);
          });

        if (deletedOwned.isEmpty) {
          return ResolvedUserAccess(
            isAllowed: false,
            recoveredAccount: recoveredAccount,
            message:
                'The business you work for was deleted. Contact the owner for access.',
          );
        }

        final businessId = deletedOwned.first['business_id'] as String;
        final business = businessesById[businessId]!;

        if (_isPast(business['recovery_deadline_at'])) {
          return ResolvedUserAccess(
            isAllowed: false,
            recoveredAccount: recoveredAccount,
            message:
                'Your business was deleted and the 30-day recovery window has passed.',
          );
        }
        if (!allowSelfRecovery) {
          return ResolvedUserAccess(
            isAllowed: false,
            recoveredAccount: recoveredAccount,
            message:
                'Your business was deleted and can still be recovered by signing in again.',
          );
        }

        await _db.from('businesses').update({
          'is_deleted': false,
          'is_active': true,
          'deleted_at': null,
          'recovery_deadline_at': null,
          'deleted_by_id': null,
          'deleted_by_type': null,
          'deletion_reason': null,
        }).eq('id', businessId);
        business['is_deleted'] = false;
        recoveredBusiness = true;
        usableMemberships = [deletedOwned.first];
      }

      final userModel = _composeUserModel(
        profile: profile,
        memberships: usableMemberships,
        businessesById: businessesById,
      );

      return ResolvedUserAccess(
        isAllowed: true,
        user: userModel,
        recoveredAccount: recoveredAccount,
        recoveredBusiness: recoveredBusiness,
      );
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

  /// Builds a UserModel from already-fetched profile/membership/business
  /// rows, picking the current (or first available) membership and joining
  /// its business's subscription fields.
  UserModel _composeUserModel({
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> memberships,
    required Map<String, Map<String, dynamic>> businessesById,
  }) {
    final businessIds = memberships
        .map((m) => m['business_id'] as String)
        .toList(growable: false);
    final hasMembership = memberships.isNotEmpty;

    String? currentBusinessId = profile['current_business_id'] as String?;
    Map<String, dynamic>? currentMembership;
    if (currentBusinessId != null) {
      currentMembership = memberships.cast<Map<String, dynamic>?>().firstWhere(
            (m) => m?['business_id'] == currentBusinessId,
            orElse: () => null,
          );
    }
    // Fall back to the first (usable) membership if there's no current
    // business selection, or it points at one that got filtered out.
    currentMembership ??= memberships.isNotEmpty ? memberships.first : null;
    currentBusinessId = currentMembership?['business_id'] as String?;

    final business =
        currentBusinessId != null ? businessesById[currentBusinessId] : null;

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
      role: (currentMembership?['role'] as String?) ?? 'owner',
      permissions: permissions,
      businessId: currentBusinessId ?? '',
      businessIds: businessIds,
      currentBusinessId: currentBusinessId,
      preferredBusinessId: currentBusinessId,
      businessType: business?['business_type'] as String?,
      storeId: currentMembership?['store_id'] as String?,
      isActive: (currentMembership?['is_active'] as bool?) ?? true,
      isOwner: (currentMembership?['is_owner'] as bool?) ?? !hasMembership,
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
    var accessToken = _auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw Exception('You must be signed in to create a worker.');
    }
    try {
      final refreshed = await _auth.refreshSession();
      accessToken = refreshed.session?.accessToken ?? accessToken;
    } catch (_) {
      // Keep the current token; the server will reject it if it is truly stale.
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
