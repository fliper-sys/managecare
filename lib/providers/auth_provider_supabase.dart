/// Supabase-only AuthProvider (replaces the Firebase-based auth_provider.dart).
///
/// Firestore/FirebaseAuth/FirebaseMessaging imports have been removed.
/// Authentication flows use GoTrue (Supabase Auth) + Postgres (profiles,
/// business_members) instead of Firebase Auth + Firestore.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/connectivity_helper.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository_supabase.dart';
import '../data/repositories/business_repository_impl.dart';
import '../services/authentication_service.dart';
import '../services/email_service.dart';
import '../services/subscription_service_supabase.dart';
import '../services/local_user_storage.dart';
import '../services/local_business_storage.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider with ChangeNotifier {
  final AuthRepositorySupabase _authRepo;
  final AuthenticationService _authService;
  final SubscriptionServiceSupabase _subscriptionService;
  final SupabaseClient _supabase;
  LocalUserStorage? _localStorage;
  LocalBusinessStorage? _localBusinessStorage;

  /// Poll timer for the profile row.
  ///
  /// The custom backend doesn't implement Supabase's Realtime protocol (a
  /// genuine `.stream()` against it raises unhandled
  /// RealtimeSubscribeException / JwtSignatureError exceptions), so profile
  /// updates are polled the same way ReportsProvider and
  /// InventoryRepositorySupabase poll their data.
  static const _profilePollInterval = Duration(seconds: 15);
  Timer? _profilePollTimer;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;
  bool _subscriptionValidated = false;
  bool _isInitializingLocalStorage = true;
  final Completer<void> _initializationCompleter = Completer<void>();

  AuthProvider({
    AuthRepositorySupabase? authRepo,
    AuthenticationService? authService,
    SubscriptionServiceSupabase? subscriptionService,
    SupabaseClient? supabase,
  })  : _authRepo = authRepo ?? AuthRepositorySupabase(),
        _authService = authService ?? AuthenticationService(),
        _subscriptionService = subscriptionService ??
            SubscriptionServiceSupabase(supabase: supabase),
        _supabase = supabase ?? Supabase.instance.client {
    _init();
  }

  Future<void> get initializationComplete => _initializationCompleter.future;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get subscriptionValidated => _subscriptionValidated;

  bool get isAdminUser =>
      _currentUser != null && _currentUser!.role.toLowerCase() == 'admin';

  bool get isWorkerUser {
    final user = _currentUser;
    if (user == null) return false;
    if (user.isOwner) return false;
    final role = user.role.toLowerCase().trim();
    if (role == 'admin') return false;
    return true;
  }

  bool get isOwnerUser => _currentUser?.isOwner == true;

  bool get isPersistentLoginEnabled =>
      _localStorage?.isAutoLoginEnabled() ?? false;

  String? getLastLoggedInEmail() => _localStorage?.getLastLoggedInEmail();

  // ────────────────────────────── Lifecycle ──────────────────────────────

  Future<bool> _hasNetwork() async {
    try {
      return await ConnectivityHelper.hasInternetConnection();
    } catch (_) {
      return false;
    }
  }

  void _init() {
    _initializeLocalStorage();

    // Listen to GoTrue auth state changes (replaces Firebase authStateChanges).
    _supabase.auth.onAuthStateChange.listen((event) {
      final sessionUser = event.session?.user;
      if (sessionUser != null) {
        _loadCurrentUser(
          sessionUser.id,
          allowSelfRecovery: _status == AuthStatus.loading,
        );
      } else {
        if (_isInitializingLocalStorage) return;

        if (_currentUser != null) {
          // Optimistically stay authenticated if offline.
          _hasNetwork().then((online) {
            if (!online) {
              _subscriptionValidated = true;
              _status = AuthStatus.authenticated;
              _errorMessage = null;
              notifyListeners();
            } else {
              _goUnauthenticated();
            }
          });
        } else {
          _goUnauthenticated();
        }
      }
    });
  }

  void _goUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    notifyListeners();
  }

  // ────────────────────────── Local storage init ──────────────────────────

  Future<void> _restoreCachedUserForOfflineStartup(UserModel cachedUser) async {
    debugPrint('[AuthProvider] Offline auto-login: restoring ${cachedUser.email}');
    _currentUser = cachedUser;
    _status = AuthStatus.authenticated;
    _errorMessage = null;
    _subscriptionValidated = true;
    try {
      await _cacheBusinessForUser(_resolveCurrentBusinessId(cachedUser));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _initializeLocalStorage() async {
    try {
      _localStorage = await LocalUserStorage.create();
      _localBusinessStorage = await LocalBusinessStorage.create();

      final autoLogin = _localStorage!.isAutoLoginEnabled();
      final cached = _localStorage!.getCachedUser();
      debugPrint('[AuthProvider] Local storage ready. autoLogin=$autoLogin cached=${cached != null}');

      if (autoLogin && cached != null) {
        final supaUser = _supabase.auth.currentUser;
        final online = await _hasNetwork();
        debugPrint('[AuthProvider] Startup: supaUser=${supaUser?.id}, online=$online');

        if (supaUser == null) {
          if (!online) {
            await _restoreCachedUserForOfflineStartup(cached);
          } else {
            _status = AuthStatus.unauthenticated;
            _currentUser = null;
            notifyListeners();
          }
          return;
        }

        _currentUser = cached;
        _status = AuthStatus.authenticated;
        _errorMessage = null;

        if (!online) {
          _subscriptionValidated = true;
          notifyListeners();
          return;
        }

        // Refresh profile from Postgres.
        _refreshFromBackend(cached.id);
      }
    } catch (e) {
      debugPrint('[AuthProvider] Local storage init error: $e');
      _status = AuthStatus.unauthenticated;
    } finally {
      _isInitializingLocalStorage = false;
      if (_currentUser == null &&
          _supabase.auth.currentUser == null &&
          _status == AuthStatus.initial) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    }
  }

  Future<void> _refreshFromBackend(String userId) async {
    try {
      final access = await _authService.resolveUserAccess(userId);
      if (!access.isAllowed || access.user == null) {
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }
      _currentUser = access.user;
      await _localStorage!.saveUser(access.user!);
      await _cacheBusinessForUser(_resolveCurrentBusinessId(access.user));
      // Validate subscription.
      if (_currentUser != null) {
        if (!_currentUser!.isOwner) {
          _subscriptionValidated = true;
        } else {
          _subscriptionValidated =
              await _validateSubscriptionForUser(_currentUser!);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] Backend refresh failed: $e');
    }
  }

  // ────────────────────────────── Auth actions ──────────────────────────────

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final user = await _authService.authenticateUser(
        email: email,
        password: password,
      );

      if (!user.isOwner) {
        await _rejectWorkerFromOwnerLogin();
        return false;
      }

      _currentUser = user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      if (_localStorage != null) {
        await _localStorage!.saveUser(user);
        final bId = user.primaryBusinessId;
        if (bId.isNotEmpty && _localBusinessStorage != null) {
          await _localBusinessStorage!.setCurrentBusiness(bId);
        }
      }

      if (_currentUser != null) {
        if (!_currentUser!.isOwner) {
          _subscriptionValidated = true;
        } else {
          _subscriptionValidated = await _validateSubscriptionForUser(_currentUser!);
        }
      }

      _subscribeToProfile(user.id);
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _extractMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginAsWorker({
    required String workerId,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final user = await _authService.authenticateWorkerByWorkerId(
        workerId: workerId,
        password: password,
      );

      _currentUser = user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      if (_localStorage != null) {
        await _localStorage!.saveUser(user);
      }

      // Resolve business from memberships.
      await _resolveAndCacheWorkerBusiness(user);

      // Validate the business owner's subscription.
      final resolvedBizId = _currentUser?.businessId.trim() ?? '';
      if (resolvedBizId.isNotEmpty) {
        final active = await _subscriptionService
            .validateAndUpdateBusinessSubscriptionStatus(
          resolvedBizId,
          userId: _currentUser!.id,
        );
        if (!active) {
          await _rejectWorkerDueToBusinessSubscription();
          return false;
        }
      }
      _subscriptionValidated = true;
      _subscribeToProfile(user.id);
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _extractMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    String role = 'owner',
    String businessId = '',
    String? referralEmail,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      if (businessId.isNotEmpty && role.toLowerCase() != 'owner') {
        // Worker creation goes through admin API.
        await _authService.createWorkerUser(
          email: email,
          password: password,
          fullName: fullName,
          businessId: businessId,
          role: role,
        );
        _errorMessage = null;
        _status =
            _currentUser != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
        notifyListeners();
        return true;
      }

      // Owner registration via GoTrue sign-up.
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName, 'phone_number': phoneNumber},
      );
      if (response.user == null) {
        throw Exception('Registration failed: no user returned');
      }

      // Create profile row.
      final user = UserModel(
        id: response.user!.id,
        email: email.trim(),
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: role,
        businessId: businessId,
        businessIds: businessId.isNotEmpty ? [businessId] : [],
        currentBusinessId: businessId.isNotEmpty ? businessId : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        pin: role.toLowerCase() == 'owner' ? '1234' : null,
      );
      await _authRepo.createUser(user);

      await _loadCurrentUser(response.user!.id);
      if (businessId.isNotEmpty && _localBusinessStorage != null) {
        await _localBusinessStorage!.setCurrentBusiness(businessId);
      }

      // Send welcome email.
      try {
        EmailService().sendWelcomeEmail(email.trim(), {'name': fullName});
      } catch (_) {}

      return true;
    } on Exception catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _errorMessage = null;
      await _supabase.auth.resetPasswordForEmail(email.trim());
      return true;
    } on Exception catch (e) {
      _errorMessage = _extractMessage(e, fallback: 'Password reset failed.');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _localStorage?.clearUser();
      await _localBusinessStorage?.clearAllBusinessData();
      _profilePollTimer?.cancel();
      _profilePollTimer = null;
      await _supabase.auth.signOut();
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
      _errorMessage = null;
      _subscriptionValidated = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to logout. Please try again.';
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? email,
    String? fullName,
    String? phoneNumber,
    String? address,
    String? jobTitle,
    String? photoUrl,
    String? businessId,
    List<String>? businessIds,
    String? currentBusinessId,
    bool? isOwner,
  }) async {
    if (_currentUser == null) return;
    try {
      final nextBusinessId = businessId ?? _currentUser!.businessId;
      final nextCurrentBusinessId =
          currentBusinessId ?? (businessId ?? _currentUser!.currentBusinessId);
      final merged = businessIds != null
          ? List<String>.from({..._currentUser!.businessIds, ...businessIds})
          : businessId != null && businessId.isNotEmpty
              ? List<String>.from({..._currentUser!.businessIds, businessId})
              : _currentUser!.businessIds;
      final updated = _currentUser!.copyWith(
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        address: address,
        jobTitle: jobTitle,
        photoUrl: photoUrl,
        businessId: nextBusinessId,
        businessIds: merged,
        currentBusinessId: nextCurrentBusinessId,
        isOwner: isOwner ?? _currentUser!.isOwner,
      );
      await _authRepo.updateUser(updated);
      _currentUser = updated;
      await _localStorage?.saveUser(updated);
      if (nextCurrentBusinessId != null &&
          nextCurrentBusinessId.isNotEmpty &&
          _localBusinessStorage != null) {
        await _localBusinessStorage!.setCurrentBusiness(nextCurrentBusinessId);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update profile. Please try again.';
      notifyListeners();
    }
  }

  Future<bool> changeEmail(String currentPassword, String newEmail) async {
    if (_currentUser == null) {
      _errorMessage = 'No user logged in';
      notifyListeners();
      return false;
    }
    final normalized = newEmail.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      _errorMessage = 'Enter a valid email address.';
      notifyListeners();
      return false;
    }
    final supaUser = _supabase.auth.currentUser;
    if (supaUser == null || supaUser.email == null) {
      _errorMessage = 'No authenticated email account found.';
      notifyListeners();
      return false;
    }
    if (supaUser.email!.trim().toLowerCase() == normalized) {
      _errorMessage = null;
      notifyListeners();
      return true;
    }
    try {
      await _supabase.auth.updateUser(UserAttributes(email: normalized));
      final updated = _currentUser!.copyWith(email: normalized, updatedAt: DateTime.now());
      await _authRepo.updateUser(updated);
      _currentUser = updated;
      await _localStorage?.saveUser(updated);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _errorMessage = _extractMessage(e, fallback: 'Failed to update email.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      // Re-authenticate with current password.
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) {
        _errorMessage = 'No user logged in';
        notifyListeners();
        return false;
      }
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      _errorMessage = null;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _errorMessage = _extractMessage(e, fallback: 'Failed to change password.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCurrentAccount({String? reason}) async {
    final user = _currentUser;
    if (user == null) {
      _errorMessage = 'No user is currently signed in.';
      notifyListeners();
      return false;
    }
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // Soft-delete via admin API (or direct Postgres update).
      await _supabase.from('profiles').update({
        'is_deleted': true,
        'is_active': false,
        'deleted_at': DateTime.now().toIso8601String(),
        'deletion_reason': reason,
      }).eq('id', user.id);

      await logout();
      return true;
    } on Exception catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _extractMessage(e, fallback: 'Failed to delete account.');
      notifyListeners();
      return false;
    }
  }

  Future<void> updateUserModel(UserModel updatedUser) async {
    try {
      await _authRepo.updateUser(updatedUser);
      if (_currentUser?.id == updatedUser.id) {
        _currentUser = updatedUser;
        await _localStorage?.saveUser(updatedUser);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update user.';
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh the current user profile from backend.
  Future<void> refresh() async {
    final online = await _hasNetwork();
    if (!online) {
      if (_currentUser != null) {
        _subscriptionValidated = true;
        notifyListeners();
      }
      return;
    }
    if (_currentUser == null) return;
    final id = _currentUser!.id;
    if (id.isEmpty) return;
    try {
      final access = await _authService.resolveUserAccess(id);
      if (!access.isAllowed || access.user == null) {
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }
      _currentUser = access.user;
      await _localStorage?.saveUser(access.user!);
      try {
        await _cacheBusinessForUser(_resolveCurrentBusinessId(access.user));
      } catch (_) {}
      if (_currentUser != null) {
        if (!_currentUser!.isOwner) {
          _subscriptionValidated = true;
        } else {
          _subscriptionValidated = await _validateSubscriptionForUser(_currentUser!);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] refresh error: $e');
    }
  }

  /// Switch the current business selection for the logged-in user.
  Future<bool> switchBusiness(String businessId) async {
    if (_currentUser == null) return false;
    try {
      final existing = _currentUser!.businessIds;
      final merged = List<String>.from({...existing, businessId});
      final updated = _currentUser!.copyWith(
        businessIds: merged,
        currentBusinessId: businessId,
      );
      await _authRepo.updateUser(updated);
      _currentUser = updated;
      await _localStorage?.saveUser(updated);
      if (_localBusinessStorage != null) {
        await _localBusinessStorage!.setCurrentBusiness(businessId);
      }
      await _cacheBusinessForUser(businessId);
      // Refresh subscription for the new business.
      if (updated.isOwner) {
        _subscriptionValidated = await _validateSubscriptionForUser(
          updated,
          businessId: businessId,
        );
      } else {
        _subscriptionValidated = true;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to switch business: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> setPersistentLogin(bool enabled) async {
    if (_localStorage != null) {
      if (enabled && _currentUser != null) {
        await _localStorage!.saveUser(_currentUser!);
      } else {
        await _localStorage!.clearUser();
      }
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─────────────────────────── Internal helpers ───────────────────────────

  Future<void> _loadCurrentUser(
    String uid, {
    bool allowSelfRecovery = false,
  }) async {
    try {
      final online = await _hasNetwork();
      if (!online) {
        final cached = _localStorage?.getCachedUser();
        if (cached != null && cached.id == uid) {
          _currentUser = cached;
          _status = AuthStatus.authenticated;
          _errorMessage = null;
          _subscriptionValidated = true;
          notifyListeners();
          return;
        }
        _goUnauthenticated();
        return;
      }

      final access = await _authService.resolveUserAccess(uid);
      if (!access.isAllowed || access.user == null) {
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }

      _currentUser = access.user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      if (_localStorage != null && _currentUser != null) {
        await _localStorage!.saveUser(_currentUser!);
        await _cacheBusinessForUser(_resolveCurrentBusinessId(_currentUser));
      }

      if (_currentUser != null) {
        if (!_currentUser!.isOwner) {
          _subscriptionValidated = true;
        } else {
          _subscriptionValidated = await _validateSubscriptionForUser(_currentUser!);
        }
      }

      _subscribeToProfile(uid);
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Poll for profile changes (see class-level note on why this polls
  /// instead of subscribing to a realtime stream).
  void _subscribeToProfile(String userId) {
    _profilePollTimer?.cancel();

    Future<void> poll() async {
      try {
        final access = await _authService.resolveUserAccess(userId);
        final updated = access.user;
        if (!access.isAllowed || updated == null) return;

        final bool changed =
            updated.currentBusinessId != _currentUser?.currentBusinessId ||
                updated.fullName != _currentUser?.fullName ||
                updated.email != _currentUser?.email ||
                updated.role != _currentUser?.role ||
                updated.businessIds.join(',') !=
                    _currentUser?.businessIds.join(',') ||
                updated.hasActiveSubscription !=
                    _currentUser?.hasActiveSubscription ||
                updated.subscriptionPlan != _currentUser?.subscriptionPlan;

        if (changed) {
          _currentUser = updated;
          _localStorage?.saveUser(updated);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[AuthProvider] Profile poll failed: $e');
      }
    }

    unawaited(poll());
    _profilePollTimer = Timer.periodic(_profilePollInterval, (_) => poll());
  }

  Future<bool> _validateSubscriptionForUser(
    UserModel user, {
    String? businessId,
  }) async {
    if (!user.isOwner) return true;
    final resolvedBiz = (businessId?.trim().isNotEmpty == true)
        ? businessId!.trim()
        : _resolveCurrentBusinessId(user);
    if (resolvedBiz == null || resolvedBiz.isEmpty) return true;
    return _subscriptionService.validateAndUpdateSubscriptionStatus(
      user.id,
      businessId: resolvedBiz,
    );
  }

  String? _resolveCurrentBusinessId([UserModel? user]) {
    final target = user ?? _currentUser;
    if (target == null) return _localBusinessStorage?.getCurrentBusinessId();
    return target.currentBusinessId?.trim().isNotEmpty == true
        ? target.currentBusinessId!.trim()
        : target.primaryBusinessId.trim().isNotEmpty
            ? target.primaryBusinessId.trim()
            : target.businessId.trim().isNotEmpty
                ? target.businessId.trim()
                : _localBusinessStorage?.getCurrentBusinessId();
  }

  Future<void> _cacheBusinessForUser(String? businessId) async {
    final id = businessId?.trim() ?? '';
    if (id.isEmpty || _localBusinessStorage == null) return;
    try {
      await _localBusinessStorage!.setCurrentBusiness(id);
      // BusinessRepositorySupabase.getBusinessById returns a raw,
      // unmapped Postgres row (snake_case columns) - passing that straight
      // to saveBusiness (which requires an actual BusinessModel) threw
      // "type '_Map<String, dynamic>' is not a subtype of type
      // 'BusinessModel'" on every call. BusinessRepository (the other repo
      // class) already does the snake_case-aware mapping into a real
      // BusinessModel, same as everywhere else this cache gets populated.
      final repo = BusinessRepository();
      final business = await repo.getBusinessById(id);
      if (business != null) {
        await _localBusinessStorage!.saveBusiness(business);
      }
    } catch (e) {
      debugPrint('[AuthProvider] Cache business error: $e');
    }
  }

  Future<void> _resolveAndCacheWorkerBusiness(UserModel user) async {
    String? bizId = user.businessId.trim();
    if (bizId.isEmpty) bizId = user.currentBusinessId?.trim() ?? '';
    if (bizId.isEmpty && user.businessIds.isNotEmpty) {
      bizId = user.businessIds.first;
    }

    if (bizId.isNotEmpty && _localBusinessStorage != null) {
      await _cacheBusinessForUser(bizId);
      // Persist businessId to profile if missing.
      if (user.businessId.isEmpty) {
        final updated = user.copyWith(businessId: bizId);
        _currentUser = updated;
        await _localStorage?.saveUser(updated);
      }
    }
  }

  Future<void> _rejectWorkerFromOwnerLogin() async {
    _profilePollTimer?.cancel();
    _profilePollTimer = null;
    await _supabase.auth.signOut();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _subscriptionValidated = false;
    _errorMessage =
        'This account is registered as a worker. Use Worker Sign In instead.';
    notifyListeners();
  }

  Future<void> _rejectWorkerDueToBusinessSubscription() async {
    _profilePollTimer?.cancel();
    _profilePollTimer = null;
    await _supabase.auth.signOut();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _subscriptionValidated = false;
    _errorMessage =
        'Please contact the business owner or manager for subscription renewal.';
    notifyListeners();
  }

  Future<void> _rejectWorkerDueToOwnerRestriction(String message) async {
    _profilePollTimer?.cancel();
    _profilePollTimer = null;
    await _supabase.auth.signOut();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _subscriptionValidated = false;
    _errorMessage = message.isNotEmpty
        ? message
        : 'Worker login blocked: business owner account is restricted. Contact the owner.';
    notifyListeners();
  }

  Future<void> _forceLogoutBecauseAccessChanged(String message) async {
    await logout();
    _errorMessage = message;
    notifyListeners();
  }

  String _extractMessage(
    Object error, {
    String fallback = 'Authentication failed. Please try again.',
  }) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return fallback;

    const prefixes = [
      'Exception: ',
      'AuthException: ',
      'Authentication error: ',
      'Worker authentication failed: ',
    ];

    var msg = raw;
    var changed = true;
    while (changed) {
      changed = false;
      for (final prefix in prefixes) {
        if (msg.startsWith(prefix)) {
          msg = msg.substring(prefix.length).trim();
          changed = true;
        }
      }
    }

    return msg.isEmpty ? fallback : msg;
  }

  @override
  void dispose() {
    _profilePollTimer?.cancel();
    super.dispose();
  }
}

