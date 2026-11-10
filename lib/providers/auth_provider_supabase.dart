/// Supabase-only AuthProvider (replaces the Firebase-based auth_provider.dart).
///
/// Firestore/FirebaseAuth/FirebaseMessaging imports have been removed.
/// Authentication flows use GoTrue (Supabase Auth) + Postgres (profiles,
/// business_members) instead of Firebase Auth + Firestore.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/connectivity_helper.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository_supabase.dart';
import '../data/repositories/business_repository_impl.dart';
import '../services/authentication_service.dart';
import '../services/email_service.dart';
import '../services/subscription_service_supabase.dart';
import '../services/local_user_storage.dart';
import '../services/local_business_storage.dart';
import '../services/local_auth_cache.dart';
import '../services/device_logger_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

bool shouldNavigateToLoginOnStartup({
  required AuthStatus status,
  required bool isAuthenticated,
  required bool hasCachedUser,
  required bool autoLoginEnabled,
}) {
  if (status == AuthStatus.initial || status == AuthStatus.loading) {
    return false;
  }

  if (isAuthenticated) {
    return false;
  }

  return !(autoLoginEnabled && hasCachedUser);
}

class AuthProvider with ChangeNotifier {
  final AuthRepositorySupabase _authRepo;
  final AuthenticationService _authService;
  final SubscriptionServiceSupabase _subscriptionService;
  final SupabaseClient _supabase;
  LocalUserStorage? _localStorage;
  LocalBusinessStorage? _localBusinessStorage;
  final LocalAuthCache _localAuthCache = LocalAuthCache();
  UserModel? _sqliteCachedUser;

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
  bool _passwordRecoveryPending = false;
  bool _isInitializingLocalStorage = true;
  bool _isUsingCachedSessionWithoutSupabaseSession = false;
  final Completer<void> _initializationCompleter = Completer<void>();
  final Completer<void> _authRestoreCompleter = Completer<void>();

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
  Future<void> get authRestoreComplete => _authRestoreCompleter.future;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isUsingCachedSessionWithoutSupabaseSession =>
      _isUsingCachedSessionWithoutSupabaseSession &&
      _supabase.auth.currentSession == null;
  bool get subscriptionValidated => _subscriptionValidated;
  bool get passwordRecoveryPending => _passwordRecoveryPending;

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
      (_localStorage?.isAutoLoginEnabled() ?? false) ||
      _sqliteCachedUser != null;

  bool get hasCachedUser => _getCachedUser() != null;

  UserModel? _getCachedUser() =>
      _localStorage?.getCachedUser() ?? _sqliteCachedUser;

  Future<bool> _saveUserToLocalCaches(UserModel user) async {
    var preferencesSaved = false;
    final localStorage = _localStorage;
    if (localStorage != null) {
      try {
        preferencesSaved = await localStorage.saveUser(user);
      } catch (e) {
        DeviceLoggerService.capture(
          'SharedPreferences user cache save failed (${e.runtimeType})',
          severity: 'ERROR',
        );
      }
    }

    var sqliteSaved = false;
    try {
      await _localAuthCache.saveUser(user);
      _sqliteCachedUser = user;
      sqliteSaved = true;
    } catch (e) {
      DeviceLoggerService.capture(
        'SQLite user cache save failed (${e.runtimeType})',
        severity: 'ERROR',
      );
    }

    DeviceLoggerService.capture(
      'Local user cache write: preferences=$preferencesSaved, SQLite=$sqliteSaved',
      severity: preferencesSaved || sqliteSaved ? 'INFO' : 'ERROR',
    );
    return preferencesSaved || sqliteSaved;
  }

  Future<bool> _clearUserFromLocalCaches() async {
    var cleared = true;
    final localStorage = _localStorage;
    if (localStorage != null) {
      try {
        if (!await localStorage.clearUser()) {
          cleared = false;
          DeviceLoggerService.capture(
            'SharedPreferences user cache clear returned false',
            severity: 'ERROR',
          );
        }
      } catch (e) {
        cleared = false;
        DeviceLoggerService.capture(
          'SharedPreferences user cache clear failed (${e.runtimeType})',
          severity: 'ERROR',
        );
      }
    }

    _sqliteCachedUser = null;
    try {
      await _localAuthCache.clearUser();
    } catch (e) {
      cleared = false;
      DeviceLoggerService.capture(
        'SQLite user cache clear failed (${e.runtimeType})',
        severity: 'ERROR',
      );
    }
    return cleared;
  }

  String? getLastLoggedInEmail() =>
      _localStorage?.getLastLoggedInEmail() ?? _sqliteCachedUser?.email;

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
      unawaited(_handleAuthStateChange(event));
    }, onError: (Object error, StackTrace stackTrace) {
      unawaited(_handleAuthStreamError(error));
    });
  }

  Future<void> _handleAuthStreamError(Object error) async {
    DeviceLoggerService.capture(
      'Auth state stream reported ${error.runtimeType}; '
      'retaining the current local session when available',
      severity: 'WARNING',
    );
    if (_isInitializingLocalStorage) return;

    if (_currentUser != null) {
      _isUsingCachedSessionWithoutSupabaseSession =
          _supabase.auth.currentSession == null;
      if (_isUsingCachedSessionWithoutSupabaseSession) {
        _subscriptionValidated = true;
      }
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    final cached = _getCachedUser();
    if (isPersistentLoginEnabled && cached != null) {
      await _restoreCachedUserForOfflineStartup(
        cached,
        recoveryNotice: 'Your saved workspace is available on this device. '
            'Reconnect and sign in again to sync.',
      );
    }
  }

  Future<void> _handleAuthStateChange(AuthState event) async {
    try {
      DeviceLoggerService.capture(
        'Auth state event: ${event.event.name}, '
        'session=${event.session != null}, '
        'sign-out reason=${event.signOutReason?.name ?? 'none'}',
      );
      if (event.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecoveryPending = true;
        notifyListeners();
      }
      final sessionUser = event.session?.user;
      if (sessionUser != null) {
        await _loadCurrentUser(
          sessionUser.id,
          allowSelfRecovery: _status == AuthStatus.loading,
        );
        return;
      }

      if (_isInitializingLocalStorage) return;

      final cachedUser = _getCachedUser();
      final hasPersistedSession =
          isPersistentLoginEnabled && cachedUser != null;

      if (event.event == AuthChangeEvent.signedOut) {
        final refreshSessionExpired =
            event.signOutReason == SignOutReason.sessionExpired ||
                event.signOutReason == SignOutReason.sessionMissing;
        if (refreshSessionExpired) {
          final userToKeep =
              _currentUser ?? (hasPersistedSession ? cachedUser : null);
          if (userToKeep != null) {
            await _restoreCachedUserForOfflineStartup(
              userToKeep,
              recoveryNotice: 'Your saved workspace is available on this '
                  'device. Reconnect and sign in again to sync.',
            );
            return;
          }
        } else {
          // Explicit logout clears these caches before calling Supabase. Clear
          // them here too for other user-initiated sign-out paths.
          await _clearUserFromLocalCaches();
        }

        _isUsingCachedSessionWithoutSupabaseSession = false;
        _subscriptionValidated = false;
        _errorMessage = null;
        _status = AuthStatus.unauthenticated;
        _currentUser = null;
        DeviceLoggerService.capture(
          'Auth provider accepted sign-out event '
          '(reason=${event.signOutReason?.name ?? 'unknown'})',
          severity: 'WARNING',
        );
        notifyListeners();
        return;
      }

      if (_currentUser != null && hasPersistedSession) {
        _isUsingCachedSessionWithoutSupabaseSession = true;
        _hasNetwork().then((online) {
          if (!online) {
            _subscriptionValidated = true;
            _status = AuthStatus.authenticated;
            _errorMessage = null;
            notifyListeners();
            return;
          }

          // A valid cached user exists, and Supabase may still be restoring its
          // persisted session during cold app start. Do not force a logout just
          // because the auth listener briefly reports null during this window.
          if (_currentUser != null) {
            _status = AuthStatus.authenticated;
            _errorMessage = null;
            notifyListeners();
          }
        });
        return;
      }

      if (_currentUser != null) {
        // A null session on a non-sign-out event is transient (for example,
        // initial session restore). Do not invalidate a user already loaded
        // in memory based on a reachability probe; the API can still be down
        // while the device has internet access.
        _isUsingCachedSessionWithoutSupabaseSession =
            _supabase.auth.currentSession == null;
        if (_isUsingCachedSessionWithoutSupabaseSession) {
          _subscriptionValidated = true;
        }
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        DeviceLoggerService.capture(
          'Auth provider retained current user after null-session event '
          '(${event.event.name})',
          severity: 'WARNING',
        );
        notifyListeners();
        return;
      }

      _goUnauthenticated();
    } finally {
      if (!_authRestoreCompleter.isCompleted) {
        _authRestoreCompleter.complete();
      }
    }
  }

  void _goUnauthenticated() {
    final cached = _getCachedUser();
    if (isPersistentLoginEnabled && cached != null) {
      DeviceLoggerService.setRecoveryNotice(null);
      _isUsingCachedSessionWithoutSupabaseSession =
          _supabase.auth.currentSession == null;
      DeviceLoggerService.capture(
        'Auth state had no session; restored cached user '
        '(auto-login enabled, cached user available)',
        severity: 'WARNING',
      );
      _currentUser = cached;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      _subscriptionValidated = true;
      notifyListeners();
      return;
    }

    DeviceLoggerService.capture(
      'Auth state became unauthenticated: auto-login=$isPersistentLoginEnabled, '
      'cached user available=${cached != null}',
      severity: 'WARNING',
    );
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    notifyListeners();
  }

  // ────────────────────────── Local storage init ──────────────────────────

  Future<void> _restoreCachedUserForOfflineStartup(
    UserModel cachedUser, {
    String? recoveryNotice,
  }) async {
    _isUsingCachedSessionWithoutSupabaseSession =
        _supabase.auth.currentSession == null;
    if (recoveryNotice == null) {
      DeviceLoggerService.setRecoveryNotice(null);
    }
    DeviceLoggerService.capture(
      'Restoring cached user after ${_isUsingCachedSessionWithoutSupabaseSession ? 'missing Supabase session' : 'offline/uncertain auth check'}',
      severity: 'WARNING',
    );
    debugPrint(
        '[AuthProvider] Offline auto-login: restoring ${cachedUser.email}');
    _currentUser = cachedUser;
    _status = AuthStatus.authenticated;
    _errorMessage = null;
    _subscriptionValidated = true;
    try {
      await _cacheBusinessForUser(_resolveCurrentBusinessId(cachedUser));
    } catch (_) {}
    if (recoveryNotice != null) {
      DeviceLoggerService.setRecoveryNotice(recoveryNotice);
    }
    notifyListeners();
  }

  Future<void> _initializeLocalStorage() async {
    try {
      _localStorage = await LocalUserStorage.create();
      _localBusinessStorage = await LocalBusinessStorage.create();
      await _localStorage!.reload();

      UserModel? sqliteCachedUser;
      try {
        sqliteCachedUser = await _localAuthCache.readUser();
      } catch (e) {
        DeviceLoggerService.capture(
          'SQLite user cache read failed (${e.runtimeType})',
          severity: 'ERROR',
        );
      }
      _sqliteCachedUser = sqliteCachedUser;

      final preferencesCachedUser = _localStorage!.getCachedUser();
      final cached = preferencesCachedUser ?? sqliteCachedUser;
      final autoLogin =
          _localStorage!.isAutoLoginEnabled() || sqliteCachedUser != null;
      DeviceLoggerService.capture(
        'Auth cache initialized: auto-login=$autoLogin, '
        'SharedPreferences user=${preferencesCachedUser != null}, '
        'SQLite user=${sqliteCachedUser != null}',
      );
      debugPrint(
          '[AuthProvider] Local storage ready. autoLogin=$autoLogin cached=${cached != null}');

      if (sqliteCachedUser != null && preferencesCachedUser == null) {
        try {
          final repaired = await _localStorage!.saveUser(sqliteCachedUser);
          DeviceLoggerService.capture(
            'Recovered SQLite profile into SharedPreferences: $repaired',
            severity: repaired ? 'SUCCESS' : 'WARNING',
          );
        } catch (e) {
          DeviceLoggerService.capture(
            'Could not repair SharedPreferences from SQLite cache (${e.runtimeType})',
            severity: 'ERROR',
          );
        }
      }

      if (autoLogin && cached != null) {
        var supaUser = _supabase.auth.currentUser;
        final online = await _hasNetwork();
        DeviceLoggerService.capture(
          'Auth startup session check: online=$online, '
          'Supabase session available=${supaUser != null}',
        );
        debugPrint(
            '[AuthProvider] Startup: supaUser=${supaUser?.id}, online=$online');

        if (supaUser == null) {
          if (online) {
            try {
              await _authRestoreCompleter.future
                  .timeout(const Duration(seconds: 3));
            } on TimeoutException {
              // Continue below and require a live session while online.
            }
            supaUser = _supabase.auth.currentUser;
          }

          if (supaUser == null && online) {
            DeviceLoggerService.capture(
              'No Supabase session was available after startup restore; retaining the persistent local user cache',
              severity: 'WARNING',
            );
            await _restoreCachedUserForOfflineStartup(
              cached,
              recoveryNotice: 'Your saved workspace was restored from this '
                  'device, but cloud sign-in could not be verified. '
                  'Reconnect and sign in again to sync.',
            );
            return;
          }

          await _restoreCachedUserForOfflineStartup(cached);
          return;
        }

        _currentUser = cached;
        _isUsingCachedSessionWithoutSupabaseSession = false;
        DeviceLoggerService.setRecoveryNotice(null);
        _status = AuthStatus.authenticated;
        _errorMessage = null;

        if (!online) {
          DeviceLoggerService.capture(
            'Offline startup: kept cached user and skipped backend profile refresh',
            severity: 'WARNING',
          );
          _subscriptionValidated = true;
          notifyListeners();
          return;
        }

        // Refresh profile from Postgres.
        _refreshFromBackend(cached.id);
      }
    } catch (e) {
      DeviceLoggerService.setRecoveryNotice(
        'We could not read your saved sign-in. Please sign in again.',
      );
      DeviceLoggerService.capture(
        'Auth local-storage initialization failed (${e.runtimeType}); '
        'cached user available=${_getCachedUser() != null}',
        severity: 'ERROR',
      );
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
        if (_canKeepCachedUserAfterUncertainAccessFailure(
            userId, access.message)) {
          DeviceLoggerService.capture(
            'Backend profile refresh was uncertain; retaining cached user',
            severity: 'WARNING',
          );
          await _restoreCachedUserForOfflineStartup(_getCachedUser()!);
          return;
        }
        DeviceLoggerService.capture(
          'Backend profile refresh denied access; clearing authenticated state',
          severity: 'ERROR',
        );
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }
      DeviceLoggerService.capture(
        'Backend profile refresh succeeded; updating cached user',
        severity: 'SUCCESS',
      );
      _currentUser = access.user;
      await _saveUserToLocalCaches(access.user!);
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
      DeviceLoggerService.capture(
        'Backend profile refresh failed (${e.runtimeType}); '
        'cached user retained=${_currentUser != null}',
        severity: 'ERROR',
      );
      debugPrint('[AuthProvider] Backend refresh failed: $e');
    }
  }

  // ────────────────────────────── Auth actions ──────────────────────────────

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    await _initializationCompleter.future;
    DeviceLoggerService.setRecoveryNotice(null);
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
      _isUsingCachedSessionWithoutSupabaseSession = false;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      final saved = await _saveUserToLocalCaches(user);
      if (!saved) {
        DeviceLoggerService.setRecoveryNotice(
          'You are signed in, but this device could not save your login. '
          'Check device storage before closing the app.',
        );
      }
      if (_localStorage != null) {
        final bId = user.primaryBusinessId;
        if (bId.isNotEmpty && _localBusinessStorage != null) {
          await _localBusinessStorage!.setCurrentBusiness(bId);
        }
      }

      if (_currentUser != null) {
        if (!_currentUser!.isOwner) {
          _subscriptionValidated = true;
        } else {
          _subscriptionValidated =
              await _validateSubscriptionForUser(_currentUser!);
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
    await _initializationCompleter.future;
    DeviceLoggerService.setRecoveryNotice(null);
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final user = await _authService.authenticateWorkerByWorkerId(
        workerId: workerId,
        password: password,
      );

      _currentUser = user;
      _isUsingCachedSessionWithoutSupabaseSession = false;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      final saved = await _saveUserToLocalCaches(user);
      if (!saved) {
        DeviceLoggerService.setRecoveryNotice(
          'You are signed in, but this device could not save your login. '
          'Check device storage before closing the app.',
        );
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
    String? businessType,
    String? storeId,
    String? pin,
    double? commissionPercentage,
    Map<String, bool>? permissions,
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
          businessType: businessType,
          storeId: storeId,
          pin: pin,
          commissionPercentage: commissionPercentage,
          permissions: permissions,
          phoneNumber: phoneNumber,
        );
        _errorMessage = null;
        _status = _currentUser != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
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

  Future<bool> resetPassword(String email,
      {String accountType = 'owner'}) async {
    try {
      _errorMessage = null;
      await _authService.requestPasswordReset(
        email: email.trim(),
        accountType: accountType,
      );
      return true;
    } on Exception catch (e) {
      _errorMessage = _extractMessage(e, fallback: 'Password reset failed.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> completePasswordRecovery(String newPassword) async {
    try {
      if (_supabase.auth.currentSession == null) {
        throw const AuthException(
          'This recovery link is invalid or expired. Request a new one.',
        );
      }
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      await _supabase.auth.signOut();
      _passwordRecoveryPending = false;
      _errorMessage = null;
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _errorMessage =
          _extractMessage(e, fallback: 'Unable to update password.');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    DeviceLoggerService.setRecoveryNotice(null);
    DeviceLoggerService.capture(
      'Explicit logout requested; clearing locally cached user and business data',
      severity: 'WARNING',
    );
    final cachesCleared = await _clearUserFromLocalCaches();
    var businessCacheCleared = true;
    try {
      await _localBusinessStorage?.clearAllBusinessData();
    } catch (e) {
      businessCacheCleared = false;
      DeviceLoggerService.capture(
        'Business cache clear failed during logout (${e.runtimeType})',
        severity: 'ERROR',
      );
    }

    _profilePollTimer?.cancel();
    _profilePollTimer = null;
    var signedOut = true;
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      signedOut = false;
      DeviceLoggerService.capture(
        'Supabase sign-out failed (${e.runtimeType})',
        severity: 'ERROR',
      );
    }

    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    _isUsingCachedSessionWithoutSupabaseSession = false;
    _subscriptionValidated = false;
    final allLocalCachesCleared = cachesCleared && businessCacheCleared;
    _errorMessage = signedOut && allLocalCachesCleared
        ? null
        : 'Logout did not complete cleanly. Please retry while online.';
    if (!allLocalCachesCleared) {
      DeviceLoggerService.setRecoveryNotice(
        'This device could not clear all saved sign-in data. '
        'Please retry logout while online.',
      );
    }
    notifyListeners();
  }

  Future<bool> updateProfile({
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
    if (_currentUser == null) {
      _errorMessage = 'No user logged in';
      notifyListeners();
      return false;
    }
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
      await _saveUserToLocalCaches(updated);
      if (nextCurrentBusinessId != null &&
          nextCurrentBusinessId.isNotEmpty &&
          _localBusinessStorage != null) {
        await _localBusinessStorage!.setCurrentBusiness(nextCurrentBusinessId);
      }
      notifyListeners();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = _extractMessage(e, fallback: 'Failed to update profile.');
      notifyListeners();
      return false;
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
      final updated =
          _currentUser!.copyWith(email: normalized, updatedAt: DateTime.now());
      await _authRepo.updateUser(updated);
      _currentUser = updated;
      await _saveUserToLocalCaches(updated);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _errorMessage = _extractMessage(e, fallback: 'Failed to update email.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
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
      _errorMessage =
          _extractMessage(e, fallback: 'Failed to change password.');
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
        await _saveUserToLocalCaches(updatedUser);
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
    if (_isUsingCachedSessionWithoutSupabaseSession &&
        _supabase.auth.currentSession == null) {
      DeviceLoggerService.capture(
        'Profile refresh skipped: only a local cached session is available; preserving offline dashboard',
        severity: 'WARNING',
      );
      return;
    }
    final online = await _hasNetwork();
    if (!online) {
      if (_currentUser != null) {
        DeviceLoggerService.capture(
          'Profile refresh skipped: offline; keeping current cached user',
          severity: 'WARNING',
        );
        _subscriptionValidated = true;
        notifyListeners();
      } else {
        DeviceLoggerService.capture(
          'Profile refresh skipped: offline and no current user is loaded',
          severity: 'ERROR',
        );
      }
      return;
    }
    if (_currentUser == null) return;
    final id = _currentUser!.id;
    if (id.isEmpty) return;
    try {
      final access = await _authService.resolveUserAccess(id);
      if (!access.isAllowed || access.user == null) {
        if (_canKeepCachedUserAfterUncertainAccessFailure(id, access.message)) {
          DeviceLoggerService.capture(
            'Profile refresh returned uncertain access result; retaining cached user',
            severity: 'WARNING',
          );
          _status = AuthStatus.authenticated;
          _errorMessage = null;
          _subscriptionValidated = _currentUser?.isSubscriptionValid == true;
          notifyListeners();
          return;
        }
        DeviceLoggerService.capture(
          'Profile refresh denied access; forcing logout',
          severity: 'ERROR',
        );
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }
      DeviceLoggerService.capture(
        'Profile refresh succeeded; current user profile updated',
        severity: 'SUCCESS',
      );
      _currentUser = access.user;
      _isUsingCachedSessionWithoutSupabaseSession = false;
      await _saveUserToLocalCaches(access.user!);
      try {
        await _cacheBusinessForUser(_resolveCurrentBusinessId(access.user));
      } catch (_) {}
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
      DeviceLoggerService.capture(
        'Profile refresh failed (${e.runtimeType}); '
        'current user retained=${_currentUser != null}',
        severity: 'ERROR',
      );
      debugPrint('[AuthProvider] refresh error: $e');
    }
  }

  /// Switch the current business selection for the logged-in user.
  Future<bool> switchBusiness(String businessId) async {
    if (_currentUser == null) return false;
    try {
      final updated = _currentUser!.copyWith(
        currentBusinessId: businessId,
      );
      await _authRepo.setCurrentBusiness(businessId);
      _currentUser = updated;
      await _saveUserToLocalCaches(updated);
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
      debugPrint('[AuthProvider] Business switch failed: $e');
      _errorMessage = 'Failed to switch business: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> setPersistentLogin(bool enabled) async {
    if (enabled && _currentUser != null) {
      await _saveUserToLocalCaches(_currentUser!);
    } else {
      await _clearUserFromLocalCaches();
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
        final cached = _getCachedUser();
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
        if (_canKeepCachedUserAfterUncertainAccessFailure(
            uid, access.message)) {
          await _restoreCachedUserForOfflineStartup(_getCachedUser()!);
          return;
        }
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }

      _currentUser = access.user;
      _isUsingCachedSessionWithoutSupabaseSession = false;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      if (_localStorage != null && _currentUser != null) {
        await _saveUserToLocalCaches(_currentUser!);
        await _cacheBusinessForUser(_resolveCurrentBusinessId(_currentUser));
      }

      if (_currentUser != null) {
        if (!_currentUser!.isOwner) {
          _subscriptionValidated = true;
        } else {
          _subscriptionValidated =
              await _validateSubscriptionForUser(_currentUser!);
        }
      }

      _subscribeToProfile(uid);
      notifyListeners();
    } catch (e) {
      final cached = _getCachedUser();
      if (isPersistentLoginEnabled && cached != null && cached.id == uid) {
        await _restoreCachedUserForOfflineStartup(cached);
        return;
      }
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
                updated.phoneNumber != _currentUser?.phoneNumber ||
                updated.address != _currentUser?.address ||
                updated.jobTitle != _currentUser?.jobTitle ||
                updated.photoUrl != _currentUser?.photoUrl ||
                updated.role != _currentUser?.role ||
                updated.businessIds.join(',') !=
                    _currentUser?.businessIds.join(',') ||
                updated.hasActiveSubscription !=
                    _currentUser?.hasActiveSubscription ||
                updated.subscriptionPlan != _currentUser?.subscriptionPlan;

        if (changed) {
          _currentUser = updated;
          await _saveUserToLocalCaches(updated);
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
    final valid =
        await _subscriptionService.validateAndUpdateSubscriptionStatus(
      user.id,
      businessId: resolvedBiz,
    );
    if (!valid && user.isSubscriptionValid) {
      debugPrint(
        '[AuthProvider] Subscription validation failed but cached entitlement '
        'is still within access window for business $resolvedBiz.',
      );
      return true;
    }
    return valid;
  }

  bool _canKeepCachedUserAfterUncertainAccessFailure(
    String userId,
    String? message,
  ) {
    final cached = _getCachedUser();
    if (!isPersistentLoginEnabled || cached == null || cached.id != userId) {
      return false;
    }

    final lowerMessage = (message ?? '').toLowerCase();
    return lowerMessage.contains('failed to load user profile') ||
        lowerMessage.contains('socket') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('network');
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
    if (id.isEmpty || _localBusinessStorage == null) {
      DeviceLoggerService.capture(
        'Business cache skipped: business reference available=${id.isNotEmpty}, '
        'local business storage available=${_localBusinessStorage != null}',
        severity: 'WARNING',
      );
      return;
    }
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
      DeviceLoggerService.capture(
        'Failed to cache the current business (${e.runtimeType})',
        severity: 'ERROR',
      );
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
        await _saveUserToLocalCaches(updated);
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
    await _clearUserFromLocalCaches();
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
    await _clearUserFromLocalCaches();
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

    final lower = msg.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('unable to connect') ||
        lower.contains('connection timed out')) {
      return 'Cannot reach the ManageCare server. Check your internet connection or contact support if this continues.';
    }

    return msg.isEmpty ? fallback : msg;
  }

  @override
  void dispose() {
    _profilePollTimer?.cancel();
    super.dispose();
  }
}
