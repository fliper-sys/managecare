import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/worker_permissions.dart';
import '../data/models/user_model.dart';
import 'managecare_api_client.dart';

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

  Future<void> requestPasswordReset({
    required String email,
    required String accountType,
  }) async {
    final response = await http
        .post(
          Uri.parse('${SupabaseConfig.url}/api/auth/password-reset/request'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'account_type': accountType,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Password recovery is temporarily unavailable. Please try again.');
    }
  }

  Future<bool> _migrateLegacyAccount(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${SupabaseConfig.url}/api/auth/legacy-migrate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AuthResponse> _signInWithCompatibility({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithPassword(
          email: email.trim(), password: password);
    } on AuthException catch (error) {
      if (!error.message.toLowerCase().contains('invalid login credentials'))
        rethrow;
      if (await _migrateLegacyAccount(email, password)) {
        return await _auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      }
      throw error;
    }
  }

  /// Authenticate user with email and password.
  /// Returns UserModel on success, throws exception on failure.
  Future<UserModel> authenticateUser({
    required String email,
    required String password,
  }) async {
    try {
      final response =
          await _signInWithCompatibility(email: email, password: password);

      if (response.user == null) {
        throw Exception('Authentication failed: No user returned');
      }

      var userModel = await _getAccessibleUser(
        response.user!.id,
        allowSelfRecovery: true,
      );

      if (userModel == null && await _migrateLegacyAccount(email, password)) {
        userModel = await _getAccessibleUser(
          response.user!.id,
          allowSelfRecovery: true,
        );
      }

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
      Map<String, dynamic>? profile;
      try {
        final resolvedProfile = await _db.rpc('current_user_profile');
        if (resolvedProfile is Map) {
          profile = Map<String, dynamic>.from(resolvedProfile);
        }
      } catch (_) {
        // Older deployments may not have the merged-profile RPC yet.
      }
      profile ??=
          await _db.from('profiles').select().eq('id', userId).maybeSingle();

      if (profile == null) {
        // Older staff accounts can exist only in `workers`. Their authenticated
        // session is valid, and this endpoint safely creates the missing profile
        // plus business_members row after verifying that worker record.
        try {
          await ManagecareApiClient.instance
              .get('/api/session/worker-membership');
          profile = await _db
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
        } catch (_) {
          // Fall through to the normal unavailable-account response.
        }
        if (profile == null && _auth.currentUser?.id == userId) {
          // A verified GoTrue session is authoritative for its own profile ID.
          // Repair the common missing-row case without copying a possibly
          // conflicting email from a legacy profile; the auth email remains a
          // safe display fallback in _composeUserModel.
          final metadata = _auth.currentUser?.userMetadata ?? const {};
          final fullName = [
            metadata['full_name'],
            metadata['name'],
            metadata['display_name'],
          ].map((value) => value?.toString().trim() ?? '').firstWhere(
                (value) => value.isNotEmpty,
                orElse: () => '',
              );
          await _db.from('profiles').upsert(
            {
              'id': userId,
              if (fullName.isNotEmpty) 'full_name': fullName,
              if (metadata['phone_number'] != null)
                'phone_number': metadata['phone_number'],
            },
            onConflict: 'id',
            ignoreDuplicates: true,
          );
          profile = await _db
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
        }
        if (profile == null) {
          return const ResolvedUserAccess(
            isAllowed: false,
            message: 'User profile not found.',
          );
        }
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
        final recoveryProfileIds = <String>{userId};
        final legacyProfileId = profile['legacy_user_id']?.toString();
        if (legacyProfileId != null && legacyProfileId.isNotEmpty) {
          recoveryProfileIds.add(legacyProfileId);
        }
        await _db.from('profiles').update({
          'is_deleted': false,
          'is_active': true,
          'deleted_at': null,
          'recovery_deadline_at': null,
          'deleted_by_id': null,
          'deletion_reason': null,
        }).inFilter('id', recoveryProfileIds.toList());
        final refreshedProfile = await _db.rpc('current_user_profile');
        profile = refreshedProfile is Map
            ? Map<String, dynamic>.from(refreshedProfile)
            : await _db.from('profiles').select().eq('id', userId).single();
        recoveredAccount = true;
      }

      var memberships = List<Map<String, dynamic>>.from(await _db
          .from('business_members')
          .select(
              'business_id, role, is_owner, permissions, store_id, is_active')
          .eq('user_id', userId)
          .eq('is_active', true));

      Map<String, dynamic>? legacyBusiness;
      if (memberships.isEmpty) {
        try {
          final response = await ManagecareApiClient.instance
              .get('/api/session/worker-membership');
          if (response is Map) {
            final payload = Map<String, dynamic>.from(response);
            final membership = payload['membership'];
            if (membership is Map) {
              memberships = [Map<String, dynamic>.from(membership)];
            }
            final business = payload['business'];
            if (business is Map) {
              legacyBusiness = Map<String, dynamic>.from(business);
            }
          }
        } catch (_) {
          // Keep normal sign-in behavior if backend membership recovery is unavailable.
        }
      }

      final businessIds = memberships
          .map((m) => m['business_id'] as String)
          .toList(growable: false);

      final businessesById = <String, Map<String, dynamic>>{};
      if (businessIds.isNotEmpty) {
        try {
          final rows =
              await _db.from('businesses').select().inFilter('id', businessIds);
          for (final row in rows) {
            businessesById[row['id'] as String] = row;
          }
        } catch (_) {
          // Business RLS or a temporary PostgREST failure must not discard a
          // worker's valid membership. The authenticated backend endpoint
          // applies its own membership check and can provide the business row.
        }

        for (final businessId in businessIds) {
          if (businessesById.containsKey(businessId)) continue;
          try {
            final response = await ManagecareApiClient.instance.get(
              '/api/businesses/${Uri.encodeComponent(businessId)}',
            );
            if (response is Map) {
              final business = Map<String, dynamic>.from(response);
              final responseId = business['id']?.toString();
              if (responseId == businessId) {
                businessesById[businessId] = business;
              }
            }
          } catch (_) {
            // Keep the membership and business ID even if details are
            // temporarily unavailable; downstream loading can retry them.
          }
        }
      }
      if (legacyBusiness != null) {
        businessesById[legacyBusiness!['id'] as String] = legacyBusiness!;
      }

      var usableMemberships = memberships
          .where((m) => businessesById[m['business_id']]?['is_deleted'] != true)
          .toList();

      var recoveredBusiness = false;

      if (usableMemberships.isEmpty && memberships.isNotEmpty) {
        // Every membership points at a deleted business. Only an owner can
        // recover one (a worker has to wait for the owner to do it).
        final deletedOwned = memberships
            .where((m) => m['is_owner'] == true)
            .toList()
          ..sort((a, b) {
            final aDate =
                businessesById[a['business_id']]?['deleted_at']?.toString() ??
                    '';
            final bDate =
                businessesById[b['business_id']]?['deleted_at']?.toString() ??
                    '';
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

    final rawPermissions = currentMembership?['permissions'];
    final permissions = rawPermissions is Map<String, dynamic>
        ? rawPermissions.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList()
        : rawPermissions is List
            ? rawPermissions
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
            : const <String>[];

    final profileId = profile['id'] as String;
    final authUser = _auth.currentUser;
    final authMetadata =
        authUser?.id == profileId ? authUser?.userMetadata : null;
    final profileEmail = (profile['email'] as String?)?.trim() ?? '';
    final email = profileEmail.isNotEmpty
        ? profileEmail
        : (authUser?.id == profileId ? authUser?.email?.trim() : null) ?? '';
    final storedName = (profile['full_name'] as String?)?.trim() ?? '';
    final metadataName = [
      authMetadata?['full_name'],
      authMetadata?['name'],
      authMetadata?['display_name'],
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final fullName = storedName.isNotEmpty
        ? storedName
        : metadataName.isNotEmpty
            ? metadataName
            : email.split('@').first.trim();

    return UserModel(
      id: profileId,
      email: email,
      fullName: fullName,
      photoUrl: profile['photo_url'] as String?,
      phoneNumber: profile['phone_number'] as String?,
      address: profile['address'] as String?,
      jobTitle: profile['job_title'] as String?,
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
      hasActiveSubscription:
          (business?['is_subscription_active'] as bool?) ?? false,
      subscriptionPlan: business?['subscription_plan'] as String?,
      subscriptionStartDate: business?['subscription_start_date'] != null
          ? DateTime.tryParse(business!['subscription_start_date'] as String)
          : null,
      subscriptionEndDate: business?['subscription_end_date'] != null
          ? DateTime.tryParse(business!['subscription_end_date'] as String)
          : null,
      createdAt: DateTime.tryParse(profile['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(profile['updated_at'] as String? ?? '') ??
          DateTime.now(),
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
    String? storeId,
    double? commissionPercentage,
    Map<String, bool>? permissions,
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

    final resolvedPermissions = permissions ??
        <String, bool>{
          for (final p in WorkerPermissions.getPermissionsForRole(role))
            p: true,
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
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            'phone': phoneNumber.trim(),
          'role': role,
          'permissions': resolvedPermissions,
          if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
          if (pin != null && pin.isNotEmpty) 'pin': pin,
          if (commissionPercentage != null)
            'commission_percentage': commissionPercentage,
        }),
      );
    } catch (e) {
      throw Exception('Failed to reach worker management service: $e');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Failed to create worker');
    }

    final randomPin = pin ??
        (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

    return UserModel(
      id: body['id'] as String,
      email: email.trim(),
      fullName: fullName.trim(),
      phoneNumber: phoneNumber,
      role: role,
      permissions: resolvedPermissions.keys.toList(),
      businessId: businessId,
      storeId: storeId,
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
      final response =
          await _signInWithCompatibility(email: email, password: password);
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
  /// The UI used to call this value "worker ID", but the backend auth flow
  /// signs staff in with their worker email, same as owners.
  Future<UserModel> authenticateWorkerByWorkerId({
    required String workerId,
    required String password,
  }) async {
    try {
      final response =
          await _signInWithCompatibility(email: workerId, password: password);

      if (response.user == null) {
        throw Exception('Authentication failed');
      }

      var resolvedUser = await _getAccessibleUser(
        response.user!.id,
        allowSelfRecovery: true,
      );
      if (resolvedUser == null &&
          await _migrateLegacyAccount(workerId, password)) {
        resolvedUser = await _getAccessibleUser(
          response.user!.id,
          allowSelfRecovery: true,
        );
      }
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
