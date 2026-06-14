import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../services/auth_service.dart';
import '../services/authentication_service.dart';
import '../services/email_service.dart';
import '../services/subscription_service.dart';
import '../services/local_user_storage.dart';
import '../services/local_business_storage.dart';
import '../services/deletion_recovery_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/push_service.dart';
import '../services/push_notification_service.dart';
import '../data/repositories/business_repository_impl.dart';
import '../data/repositories/worker_repository_impl.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider with ChangeNotifier {
  final AuthRepositoryImpl _authRepository =
      AuthRepositoryImpl(firebaseAuth: FirebaseAuth.instance);
  final AuthService _authService = AuthService();
  final AuthenticationService _authenticationService = AuthenticationService();
  final SubscriptionService _subscriptionService =
      SubscriptionService(firestore: FirebaseFirestore.instance);
  final DeletionRecoveryService _deletionRecoveryService =
      DeletionRecoveryService(firestore: FirebaseFirestore.instance);
  LocalUserStorage? _localStorage;
  LocalBusinessStorage? _localBusinessStorage;

  // Listen to changes on the user document so in-app changes from other screens
  // or clients are reflected immediately without requiring an app restart.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSubscription;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;
  bool _subscriptionValidated = false;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get subscriptionValidated => _subscriptionValidated;

  // Role helpers
  bool get isAdminUser {
    return _currentUser != null && _currentUser!.role.toLowerCase() == 'admin';
  }

  bool get isWorkerUser {
    final user = _currentUser;
    if (user == null) return false;
    if (user.isOwner) return false;
    final role = user.role.toLowerCase().trim();
    if (role == 'admin') return false;
    return true;
  }

  bool get isOwnerUser {
    return _currentUser != null && _currentUser!.isOwner == true;
  }

  AuthProvider() {
    _init();
  }

  void _init() {
    _initializeLocalStorage();

    // Listen to auth state changes
    _authService.authStateChanges.listen((User? firebaseUser) {
      if (firebaseUser != null) {
        _loadCurrentUser(
          firebaseUser.uid,
          allowSelfRecovery: _status == AuthStatus.loading,
        );
      } else {
        _status = AuthStatus.unauthenticated;
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  /// Initialize local storage and attempt auto-login
  Future<void> _initializeLocalStorage() async {
    try {
      _localStorage = await LocalUserStorage.create();
      // Initialize local business storage as well to persist selected business
      try {
        _localBusinessStorage = await LocalBusinessStorage.create();
      } catch (e) {
        print('[AuthProvider] Error initializing LocalBusinessStorage: $e');
      }

      // Attempt auto-login if cached user exists and auto-login is enabled
      if (_localStorage!.isAutoLoginEnabled()) {
        final cachedUser = _localStorage!.getCachedUser();
        if (cachedUser != null) {
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser == null) {
            print(
              '[AuthProvider] Auto-login skipped for cached user ${cachedUser.email} because there is no active Firebase session.',
            );
            await _localStorage!.clearUser();
            _status = AuthStatus.unauthenticated;
            _currentUser = null;
            _errorMessage = null;
            notifyListeners();
            return;
          }

          print(
              '[AuthProvider] Auto-login: restoring cached user ${cachedUser.email}');
          _currentUser = cachedUser;
          _status = AuthStatus.authenticated;
          _errorMessage = null;

          // Validate subscription status
          try {
            // Skip subscription enforcement for all non-owner users during auto-login
            if (!_currentUser!.isOwner) {
              _subscriptionValidated = true;
              if (kDebugMode) print('[AuthProvider] Skipping subscription validation for non-owner user during auto-login: ${_currentUser!.id}');
            } else {
              _subscriptionValidated =
                  await _validateSubscriptionForUser(_currentUser!);
            }
          } catch (e) {
            print('[AuthProvider] Error validating subscription during auto-login: $e');
          }

          // Sync cached user with Firebase to update profile info
          _syncCachedUserWithFirebase(cachedUser.id);

          // Try to fetch the latest user document synchronously to ensure we have businessId
          try {
            final access = await _authenticationService.resolveUserAccess(
              cachedUser.id,
              allowSelfRecovery: false,
            );
            if (!access.isAllowed || access.user == null) {
              await _forceLogoutBecauseAccessChanged(
                access.message ?? 'This account is no longer available.',
              );
              return;
            }

            final refreshedUser = access.user;
            if (refreshedUser != null) {
              _currentUser = refreshedUser;
              await _localStorage!.saveUser(refreshedUser);
            }

            // Ensure a primary business exists for worker users
            String? primaryBiz = _currentUser?.primaryBusinessId;
            if ((primaryBiz == null || primaryBiz.isEmpty) &&
                _currentUser != null) {
              // Attempt to find business id from workers collection (worker's email may be used)
              try {
                final workerRepo =
                    WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
                var workerDoc =
                    await workerRepo.getWorkerById(_currentUser!.id);
                if (workerDoc == null &&
                    _currentUser!.email.isNotEmpty &&
                    _currentUser!.email.contains('@')) {
                  final query = await FirebaseFirestore.instance
                      .collection('workers')
                      .where('email', isEqualTo: _currentUser!.email)
                      .limit(1)
                      .get();
                  if (query.docs.isNotEmpty) {
                    workerDoc = {
                      'id': query.docs.first.id,
                      ...query.docs.first.data()
                    };
                  }
                }

                if (workerDoc != null && workerDoc is Map<String, dynamic>) {
                  final found = (workerDoc['businessId'] as String?) ?? '';
                  if (found.isNotEmpty) {
                    primaryBiz = found;
                    final updatedUser = _currentUser!.copyWith(
                        businessIds: [found], currentBusinessId: found);
                    _currentUser = updatedUser;
                    await _authRepository.updateUser(updatedUser);
                    if (_localStorage != null)
                      await _localStorage!.saveUser(updatedUser);
                  }
                }
              } catch (e) {
                print(
                    '[AuthProvider] Error fetching worker doc during auto-login: $e');
              }
            }

            // If we now have a business id, set and cache the business details for faster startup
            if (primaryBiz != null &&
                primaryBiz.isNotEmpty &&
                _localBusinessStorage != null) {
              await _cacheBusinessForUser(primaryBiz);
            }

            if (_currentUser != null) {
              try {
                if (!_currentUser!.isOwner) {
                  _subscriptionValidated = true;
                } else {
                  _subscriptionValidated =
                      await _validateSubscriptionForUser(_currentUser!);
                }
              } catch (e) {
                print(
                    '[AuthProvider] Error revalidating subscription after auto-login refresh: $e');
              }
            }
          } catch (e) {
            print(
                '[AuthProvider] Error refreshing cached user during auto-login: $e');
          }

          // Also restore cached business if available for this user
          try {
            final businessId = _localBusinessStorage?.getCurrentBusinessId();
            if (businessId != null && businessId.isNotEmpty) {
              print('[AuthProvider] Restoring cached businessId: $businessId');
              // BusinessProvider will pick this up on initialization
            }
          } catch (e) {
            print('[AuthProvider] Error restoring cached business: $e');
          }

          notifyListeners();
        }
      }
    } catch (e) {
      print('[AuthProvider] Error initializing local storage: $e');
      _status = AuthStatus.unauthenticated;
    }
  }

  /// Sync cached user data with Firebase in background
  /// This ensures profile updates from other devices are reflected
  Future<void> _syncCachedUserWithFirebase(String userId) async {
    try {
      print('[AuthProvider] Syncing cached user with Firebase...');
      final access = await _authenticationService.resolveUserAccess(
        userId,
        allowSelfRecovery: false,
      );
      if (!access.isAllowed || access.user == null) {
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }
      final updatedUser = access.user;

      if (updatedUser != null && _localStorage != null) {
        _currentUser = updatedUser;
        await _localStorage!.saveUser(updatedUser);
        print('[AuthProvider] Successfully synced user with Firebase');
        notifyListeners();
      }
    } catch (e) {
      print(
          '[AuthProvider] Background sync with Firebase failed (non-critical): $e');
      // Don't fail auto-login if sync fails - cached data is still valid
    }
  }

  String? _resolveCurrentBusinessId([UserModel? user]) {
    final targetUser = user ?? _currentUser;
    if (targetUser == null) {
      return _localBusinessStorage?.getCurrentBusinessId();
    }

    final currentBusinessId = targetUser.currentBusinessId?.trim() ?? '';
    if (currentBusinessId.isNotEmpty) return currentBusinessId;

    final primaryBusinessId = targetUser.primaryBusinessId.trim();
    if (primaryBusinessId.isNotEmpty) return primaryBusinessId;

    final legacyBusinessId = targetUser.businessId.trim();
    if (legacyBusinessId.isNotEmpty) return legacyBusinessId;

    final cachedBusinessId =
        _localBusinessStorage?.getCurrentBusinessId()?.trim() ?? '';
    if (cachedBusinessId.isNotEmpty) return cachedBusinessId;

    return null;
  }

  Future<void> _cacheBusinessForUser(String? businessId) async {
    final normalizedBusinessId = businessId?.trim() ?? '';
    if (normalizedBusinessId.isEmpty || _localBusinessStorage == null) return;

    try {
      await _localBusinessStorage!.setCurrentBusiness(normalizedBusinessId);
      final repo = BusinessRepository();
      final business = await repo.getBusinessById(normalizedBusinessId);
      if (business != null) {
        await _localBusinessStorage!.saveBusiness(business);
      }
    } catch (e) {
      print('[AuthProvider] Error caching business $normalizedBusinessId: $e');
    }
  }

  Future<void> _refreshCurrentUserSnapshot(String userId) async {
    try {
      final access = await _authenticationService.resolveUserAccess(
        userId,
        allowSelfRecovery: false,
      );
      if (!access.isAllowed || access.user == null) {
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }
      final refreshedUser = access.user;

      _currentUser = refreshedUser;

      if (_localStorage != null) {
        await _localStorage!.saveUser(refreshedUser!);
      }

      await _cacheBusinessForUser(_resolveCurrentBusinessId(refreshedUser));
    } catch (e) {
      print('[AuthProvider] Error refreshing current user snapshot: $e');
    }
  }

  Future<bool> _validateSubscriptionForUser(
    UserModel user, {
    String? businessId,
  }) async {
    if (!user.isOwner) return true;

    final resolvedBusinessId = (businessId?.trim().isNotEmpty == true)
        ? businessId!.trim()
        : _resolveCurrentBusinessId(user);

    if (resolvedBusinessId != null && resolvedBusinessId.isNotEmpty) {
      try {
        await _subscriptionService.syncUserSubscriptionSummaryFromBusiness(
          userId: user.id,
          businessId: resolvedBusinessId,
        );
      } catch (e) {
        if (kDebugMode) {
          print(
              '[AuthProvider] Failed to sync subscription summary for $resolvedBusinessId: $e');
        }
      }
    }

    final isValid = await _subscriptionService.validateAndUpdateSubscriptionStatus(
      user.id,
      businessId: resolvedBusinessId,
    );

    if (_currentUser?.id == user.id) {
      await _refreshCurrentUserSnapshot(user.id);
    }

    return isValid;
  }

  Future<void> _loadCurrentUser(
    String uid, {
    bool allowSelfRecovery = false,
  }) async {
    try {
      final access = await _authenticationService.resolveUserAccess(
        uid,
        allowSelfRecovery: allowSelfRecovery,
      );
      if (!access.isAllowed || access.user == null) {
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }

      _currentUser = access.user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      // Save user to local storage after successful load
      if (_localStorage != null && _currentUser != null) {
        await _localStorage!.saveUser(_currentUser!);
        // Persist primary business id to local business storage too
        try {
          await _cacheBusinessForUser(_resolveCurrentBusinessId(_currentUser));
        } catch (e) {
          print('[AuthProvider] Error persisting business from user: $e');
        }
      }

      // Ensure that if currentBusinessId is set on the user it is also present in businessIds
      try {
        if (_currentUser != null && _currentUser!.currentBusinessId != null && _currentUser!.currentBusinessId!.isNotEmpty) {
          final cb = _currentUser!.currentBusinessId!;
          if (!_currentUser!.businessIds.contains(cb)) {
            final merged = [..._currentUser!.businessIds, cb];
            final updated = _currentUser!.copyWith(businessIds: merged);
            _currentUser = updated;
            await _authRepository.updateUser(updated);
            if (_localStorage != null) await _localStorage!.saveUser(updated);
          }
        }
      } catch (e) {
        print('[AuthProvider] Error ensuring businessIds contains currentBusinessId: $e');
      }

      // Subscribe to realtime updates on the user document so any changes made
      // elsewhere (e.g., owner dashboard, admin edits, another device) are
      // reflected immediately without the need to restart the app.
      try {
        // Cancel previous subscription if any
        await _userDocSubscription?.cancel();
        _userDocSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots()
            .listen((snap) async {
          if (!snap.exists) return;

          final data = snap.data();
          if (data == null) return;

          // Construct a UserModel from snapshot and compare key fields
          final updatedUser = UserModel.fromJson({'id': snap.id, ...data});

          final bool changed =
              updatedUser.currentBusinessId != _currentUser?.currentBusinessId ||
              updatedUser.preferredBusinessId !=
                  _currentUser?.preferredBusinessId ||
              updatedUser.businessIds.join(',') !=
                  _currentUser?.businessIds.join(',') ||
              updatedUser.fullName != _currentUser?.fullName ||
              updatedUser.email != _currentUser?.email ||
              updatedUser.role != _currentUser?.role ||
              updatedUser.permissions.join(',') !=
                  _currentUser?.permissions.join(',') ||
              updatedUser.businessId != _currentUser?.businessId ||
              updatedUser.businessType != _currentUser?.businessType ||
              updatedUser.storeId != _currentUser?.storeId ||
              updatedUser.phoneNumber != _currentUser?.phoneNumber ||
              updatedUser.isActive != _currentUser?.isActive ||
              updatedUser.isOwner != _currentUser?.isOwner ||
              updatedUser.pin != _currentUser?.pin ||
              updatedUser.hasActiveSubscription !=
                  _currentUser?.hasActiveSubscription ||
              updatedUser.subscriptionPlan !=
                  _currentUser?.subscriptionPlan ||
              updatedUser.subscriptionPaymentRequired !=
                  _currentUser?.subscriptionPaymentRequired ||
              updatedUser.subscriptionTransactionId !=
                  _currentUser?.subscriptionTransactionId ||
              updatedUser.subscriptionAmount !=
                  _currentUser?.subscriptionAmount ||
              updatedUser.subscriptionStartDate?.millisecondsSinceEpoch !=
                  _currentUser?.subscriptionStartDate?.millisecondsSinceEpoch ||
              updatedUser.subscriptionEndDate?.millisecondsSinceEpoch !=
                  _currentUser?.subscriptionEndDate?.millisecondsSinceEpoch;

          if (changed) {
            _currentUser = updatedUser;
            // Persist refreshed user locally
            if (_localStorage != null) await _localStorage!.saveUser(_currentUser!);

            // Notify listeners so other providers (BusinessProvider via ProxyProvider)
            // can react to the updated user (e.g., new currentBusinessId)
            notifyListeners();
          }
        });
      } catch (e) {
        print('[AuthProvider] Failed to subscribe to user doc snapshots: $e');
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Public method to refresh the current user profile from backend.
  ///
  /// This fetches the latest user document, updates local cache and local
  /// business storage (so UI can pick up any changed `businessId` or
  /// `preferredBusinessId`) and validates subscription status.
  Future<void> refresh() async {
    // If a current business exists in local cache that differs from user, reconcile it
    try {
      final cachedBusinessId = _localBusinessStorage?.getCurrentBusinessId();
      if (cachedBusinessId != null && _currentUser != null && _currentUser!.currentBusinessId != cachedBusinessId) {
        // Update user doc to reflect local selection as authoritative
        try {
          final updated = _currentUser!.copyWith(currentBusinessId: cachedBusinessId, businessIds: [..._currentUser!.businessIds, cachedBusinessId]);
          await _authRepository.updateUser(updated);
          _currentUser = updated;
          if (_localStorage != null) await _localStorage!.saveUser(updated);
        } catch (e) {
          if (kDebugMode) print('[AuthProvider] Failed to reconcile cached business with user doc: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) print('[AuthProvider] Error during business reconciliation: $e');
    }
    if (_currentUser == null) return;
    try {
      final id = _currentUser!.id;
      if (id.isEmpty) return;

      if (kDebugMode) print('[AuthProvider] Refreshing user: $id');

      final access = await _authenticationService.resolveUserAccess(
        id,
        allowSelfRecovery: false,
      );
      if (!access.isAllowed || access.user == null) {
        await _forceLogoutBecauseAccessChanged(
          access.message ?? 'This account is no longer available.',
        );
        return;
      }

      final refreshed = access.user;
      if (refreshed != null) {
        _currentUser = refreshed;

        // Persist refreshed user locally
        if (_localStorage != null) {
          await _localStorage!.saveUser(refreshed);
        }

        // Validate subscription status again
        try {
          // Non-owner users are not restricted by subscription checks
          if (!refreshed.isOwner) {
            _subscriptionValidated = true;
            if (kDebugMode) print('[AuthProvider] Skipping subscription validation for non-owner user during refresh: ${refreshed.id}');
          } else {
            _subscriptionValidated =
                await _validateSubscriptionForUser(refreshed);
          }
        } catch (e) {
          if (kDebugMode) print('[AuthProvider] Subscription validation failed during refresh: $e');
        }

        // Ensure primary business is cached for faster startup and for providers
        try {
          await _cacheBusinessForUser(_resolveCurrentBusinessId(refreshed));
        } catch (e) {
          if (kDebugMode)
            print(
                '[AuthProvider] Error handling business cache during refresh: $e');
        }

        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('[AuthProvider] refresh() error: $e');
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // Use enhanced authentication service for better error handling
      try {
        final user = await _authenticationService.authenticateUser(
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

        // Save user to local storage
        if (_localStorage != null && _currentUser != null) {
          await _localStorage!.saveUser(_currentUser!);
          // Persist linked business info for auto-login
          try {
            final bId = _currentUser!.primaryBusinessId;
            if (bId.isNotEmpty && _localBusinessStorage != null) {
              await _localBusinessStorage!.setCurrentBusiness(bId);
              try {
                final repo = BusinessRepository();
                final business = await repo.getBusinessById(bId);
                if (business != null)
                  await _localBusinessStorage!.saveBusiness(business);
              } catch (e) {
                print(
                    '[AuthProvider] Error caching business details post-login: $e');
              }
            }
          } catch (e) {
            print('[AuthProvider] Error persisting business post-login: $e');
          }
        }

        // Validate subscription status after loading user
        if (_currentUser != null) {
          try {
            // Skip validation for non-owner users
            if (!_currentUser!.isOwner) {
              _subscriptionValidated = true;
              print('[AuthProvider] Skipped subscription validation for non-owner user: ${_currentUser!.id}');
            } else {
              _subscriptionValidated =
                  await _validateSubscriptionForUser(_currentUser!);
              print('[AuthProvider] Subscription validated for user: ${_currentUser!.id}');
            }
          } catch (e) {
            print('[AuthProvider] Error validating subscription post-login: $e');
          }
        }

        // Send login notification to business owners
        if (_currentUser != null && !_currentUser!.isOwner) {
          await _notifyBusinessOwnerOfLogin(_currentUser!.id, email);
        }

        notifyListeners();
        return true;
      } catch (e) {
        // Fallback to original method if enhanced service fails
        final userCredential = await _authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          await _loadCurrentUser(
            userCredential.user!.uid,
            allowSelfRecovery: true,
          );

          if (_currentUser != null && !_currentUser!.isOwner) {
            await _rejectWorkerFromOwnerLogin();
            return false;
          }

          // Validate subscription status after loading user
          if (_currentUser != null) {
            if (!_currentUser!.isOwner) {
              _subscriptionValidated = true;
              print('[AuthProvider] Skipped subscription validation for non-owner (fallback): ${_currentUser!.id}');
            } else {
              _subscriptionValidated =
                  await _validateSubscriptionForUser(_currentUser!);
              print('[AuthProvider] Subscription validated for user (fallback): ${_currentUser!.id}');
            }
          }

          // Send login notification to business owners
          if (_currentUser != null && !_currentUser!.isOwner) {
            await _notifyBusinessOwnerOfLogin(_currentUser!.id, email);
          }

          notifyListeners();
          return true;
        }
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _getFirebaseAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _extractAuthErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> _rejectWorkerFromOwnerLogin() async {
    try {
      await _userDocSubscription?.cancel();
      _userDocSubscription = null;
    } catch (e) {
      print(
          '[AuthProvider] Error cancelling user doc subscription during owner-login rejection: $e');
    }

    try {
      await _authenticationService.signOut();
    } catch (e) {
      print(
          '[AuthProvider] Enhanced auth sign-out failed during owner-login rejection: $e');
      try {
        await _authService.signOut();
      } catch (signOutError) {
        print(
            '[AuthProvider] Firebase sign-out also failed during owner-login rejection: $signOutError');
      }
    }

    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _subscriptionValidated = false;
    _errorMessage =
        'This account is registered as a worker. Use Worker Sign In instead.';
    notifyListeners();
  }

  Future<void> _rejectWorkerDueToBusinessSubscription() async {
    try {
      await _userDocSubscription?.cancel();
      _userDocSubscription = null;
    } catch (e) {
      print(
          '[AuthProvider] Error cancelling user doc subscription during worker subscription rejection: $e');
    }

    try {
      await _authenticationService.signOut();
    } catch (e) {
      print(
          '[AuthProvider] Enhanced auth sign-out failed during worker subscription rejection: $e');
      try {
        await _authService.signOut();
      } catch (signOutError) {
        print(
            '[AuthProvider] Firebase sign-out also failed during worker subscription rejection: $signOutError');
      }
    }

    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _subscriptionValidated = false;
    _errorMessage =
        'Please contact the business owner or manager for subscription renewal.';
    notifyListeners();
  }

  /// Login as a worker using worker ID and password
  Future<bool> loginAsWorker({
    required String workerId,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      print('[AuthProvider] Attempting worker login with ID: $workerId');

      final user = await _authenticationService.authenticateWorkerByWorkerId(
        workerId: workerId,
        password: password,
      );

      _currentUser = user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      // Save user to local storage
      if (_localStorage != null && _currentUser != null) {
        await _localStorage!.saveUser(_currentUser!);
      }

      // Ensure business ID is persisted for workers so UI can scope to business
      try {
        final bId = _currentUser?.businessId ?? '';
        // If not present, try to fetch worker document for a businessId
        String? businessId = bId.isNotEmpty ? bId : null;
        if ((businessId == null || businessId.isEmpty)) {
          try {
            final workerRepo =
                WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
            var workerDoc = await workerRepo.getWorkerById(workerId);
            // Fallback: if lookup by id failed and workerId looks like an email,
            // try querying the workers collection for matching email
            if (workerDoc == null && workerId.contains('@')) {
              final query = await FirebaseFirestore.instance
                  .collection('workers')
                  .where('email', isEqualTo: workerId)
                  .limit(1)
                  .get();
              if (query.docs.isNotEmpty) {
                workerDoc = {
                  'id': query.docs.first.id,
                  ...query.docs.first.data()
                };
              }
            }

            if (workerDoc != null && workerDoc is Map<String, dynamic>) {
              final found = (workerDoc['businessId'] as String?) ?? '';
              if (found.isNotEmpty) {
                businessId = found;
                // Persist businessId (and possibly businessType) to the users document for future logins
                try {
                  String? workerBusinessType = (workerDoc['businessType'] as String?) ?? (workerDoc['industry'] as String?);

                  var updatedUser = _currentUser!.copyWith(businessId: businessId);
                  if (workerBusinessType != null && workerBusinessType.isNotEmpty) {
                    updatedUser = updatedUser.copyWith(businessType: workerBusinessType);
                  }

                  _currentUser = updatedUser;
                  // Persist to Firestore and local cache
                  await _authRepository.updateUser(updatedUser);
                  if (_localStorage != null) await _localStorage!.saveUser(updatedUser);
                } catch (e) {
                  print('[AuthProvider] Failed to update user with businessId: $e');
                }
              }
            }
          } catch (e) {
            print(
                '[AuthProvider] Failed to find worker doc while retrieving businessId: $e');
          }
        }

        // If we have a business id, store and cache the business details
        if (businessId != null &&
            businessId.isNotEmpty &&
            _localBusinessStorage != null) {
          // If the user's Firestore document is missing the businessId, persist it
          try {
            final storedUser =
                await _authRepository.getCurrentUser(_currentUser!.id);
            if (storedUser == null || storedUser.businessId.isEmpty) {
              final updated = _currentUser!.copyWith(businessId: businessId);
              _currentUser = updated;
              await _authRepository.updateUser(updated);
            }
          } catch (e) {
            print('[AuthProvider] Error persisting businessId to user doc: $e');
          }
          try {
            await _localBusinessStorage!.setCurrentBusiness(businessId);
            final repo = BusinessRepository();
            final business = await repo.getBusinessById(businessId);
            if (business != null) {
              await _localBusinessStorage!.saveBusiness(business);
              // Persist businessType to user document if missing or empty
              try {
                if ((_currentUser?.businessType == null || (_currentUser!.businessType?.isEmpty ?? true)) && business.businessType.isNotEmpty) {
                  _currentUser = _currentUser!.copyWith(businessType: business.businessType);
                  await _authRepository.updateUser(_currentUser!);
                  if (_localStorage != null) await _localStorage!.saveUser(_currentUser!);
                }
              } catch (e) {
                print('[AuthProvider] Failed to persist businessType from business doc: $e');
              }
            }
          } catch (e) {
            print('[AuthProvider] Error caching worker business: $e');
          }
        }
      } catch (e) {
        print(
            '[AuthProvider] Error persisting worker business during login: $e');
      }

      // Validate the business owner's subscription before completing worker login.
      final workerBusinessId = _currentUser?.businessId.trim() ?? '';
      if (workerBusinessId.isNotEmpty) {
        final businessSubscriptionActive =
            await _subscriptionService.validateAndUpdateBusinessSubscriptionStatus(
          workerBusinessId,
          userId: _currentUser!.id,
        );

        if (!businessSubscriptionActive) {
          if (kDebugMode) {
            print(
              '[AuthProvider] Blocking worker login because business subscription is inactive or expired: $workerBusinessId',
            );
          }
          await _rejectWorkerDueToBusinessSubscription();
          return false;
        }
      }

      // Validate subscription status after loading user
      if (_currentUser != null) {
        _subscriptionValidated = true;
      }

      // Send login notification to business owners
      await _notifyBusinessOwnerOfLogin(_currentUser!.id, workerId);

      print('[AuthProvider] Worker login successful: ${user.id}');
      notifyListeners();
      return true;
    } catch (e) {
      print('[AuthProvider] Worker login failed: $e');
      _status = AuthStatus.unauthenticated;
      _errorMessage = _extractAuthErrorMessage(e);
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

      // Use enhanced authentication service for worker creation if specified
      if (role == 'worker' && businessId.isNotEmpty) {
        try {
          await _authenticationService.createWorkerUser(
            email: email,
            password: password,
            fullName: fullName,
            businessId: businessId,
            role: '',
          );

          // Worker created successfully. Do NOT switch the current authenticated user.
          // Admin should remain signed in; simply return success.
          _errorMessage = null;
          _status = _currentUser != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
          notifyListeners();
          return true;
        } catch (e) {
          // Fallback to manual creation
          throw Exception('Worker creation failed: $e');
        }
      }

      // Standard owner registration flow
      final userCredential = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create user document in Firestore
        final user = UserModel(
          id: userCredential.user!.uid,
          email: email,
          fullName: fullName,
          phoneNumber: phoneNumber,
          role: role,
          businessId: businessId,
          referralEmail: referralEmail,
          // If a businessId was supplied during registration, set it as the initial business
          businessIds: businessId.isNotEmpty ? [businessId] : const [],
          currentBusinessId: businessId.isNotEmpty ? businessId : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
          // Default owner PIN: 1234 for initial owner account
          pin: role.toLowerCase() == 'owner' ? '1234' : null,
        );

        await _authRepository.createUser(user);
        await _loadCurrentUser(userCredential.user!.uid);

        // If initial businessId was provided, persist it to user's document and cache
        if (businessId.isNotEmpty) {
          try {
            // Ensure Firestore user doc includes businessIds / currentBusinessId
            await _authRepository.updateUser(user.copyWith());
            if (_localStorage != null) {
              await _localStorage!.updateCachedUser(
                businessIds: [businessId],
                currentBusinessId: businessId,
                businessId: businessId,
              );
            }
            if (_localBusinessStorage != null) {
              await _localBusinessStorage!.setCurrentBusiness(businessId);
            }
          } catch (e) {
            print('[AuthProvider] Warning: failed to persist initial business for user: $e');
          }
        }

        // Send welcome email asynchronously; don't block registration on email result
        try {
          EmailService()
              .sendWelcomeEmail(email, {'name': fullName}).then((sent) {
            // Optionally handle result or logging
          }).catchError((e) {
            // ignore email send errors for now
          });
        } catch (e) {
          // swallow exceptions from EmailService creation
        }

        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _getFirebaseAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Registration failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _errorMessage = null;
      await _authService.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      // Clear local storage
      if (_localStorage != null) {
        await _localStorage!.clearUser();
        print('[AuthProvider] Cleared cached user data');
      }
      // Clear local business cache as well
      if (_localBusinessStorage != null) {
        try {
          await _localBusinessStorage!.clearAllBusinessData();
          print('[AuthProvider] Cleared cached business data');
        } catch (e) {
          print(
              '[AuthProvider] Error clearing business cache during logout: $e');
        }
      }

      // Remove FCM token for the current user if present
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await PushService.removeTokenForCurrentUser(token);
        }
      } catch (e) {
        print('[AuthProvider] Failed to remove FCM token on logout: $e');
      }

      // Use enhanced authentication service for logout
      try {
        await _authenticationService.signOut();
        print('[AuthProvider] Signed out via enhanced authentication service');
      } catch (e) {
        // Fallback to direct Firebase sign out
        print(
            '[AuthProvider] Enhanced auth failed, falling back to Firebase: $e');
        await _authService.signOut();
      }

      _status = AuthStatus.unauthenticated;

      // Cancel any outstanding user document listener
      try {
        await _userDocSubscription?.cancel();
        _userDocSubscription = null;
      } catch (e) {
        print('[AuthProvider] Error cancelling user doc subscription on logout: $e');
      }

      _currentUser = null;
      _errorMessage = null;
      _subscriptionValidated = false;
      print('[AuthProvider] Logout completed successfully');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to logout. Please try again.';
      print('[AuthProvider] Error during logout: $e');
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
      final mergedBusinessIds = businessIds != null
          ? List<String>.from({..._currentUser!.businessIds, ...businessIds})
          : _currentUser!.businessIds;

      final updatedUser = _currentUser!.copyWith(
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        address: address,
        jobTitle: jobTitle,
        photoUrl: photoUrl,
        businessId: businessId ?? _currentUser!.businessId,
        businessIds: mergedBusinessIds,
        currentBusinessId: currentBusinessId ?? _currentUser!.currentBusinessId,
        isOwner: isOwner ?? _currentUser!.isOwner,
      );

      await _authRepository.updateUser(updatedUser);
      _currentUser = updatedUser;

      // Update cached user in local storage
      if (_localStorage != null) {
        await _localStorage!.updateCachedUser(
          email: email,
          fullName: fullName,
          phoneNumber: phoneNumber,
          address: address,
          jobTitle: jobTitle,
          photoUrl: photoUrl,
          businessId: businessId,
          businessIds: businessIds,
          currentBusinessId: currentBusinessId,
          isOwner: isOwner,
        );
      }

      // Update local business selection if changed
      if (currentBusinessId != null && _localBusinessStorage != null) {
        await _localBusinessStorage!.setCurrentBusiness(currentBusinessId);
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update profile. Please try again.';
      notifyListeners();
    }
  }

  Future<bool> changeEmail(
      String currentPassword, String newEmail) async {
    if (_currentUser == null) {
      _errorMessage = 'No user logged in';
      notifyListeners();
      return false;
    }

    final normalizedEmail = newEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      _errorMessage = 'Enter a valid email address.';
      notifyListeners();
      return false;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      _errorMessage = 'No authenticated email account found.';
      notifyListeners();
      return false;
    }

    if (firebaseUser.email!.trim().toLowerCase() == normalizedEmail) {
      _errorMessage = null;
      notifyListeners();
      return true;
    }

    try {
      await _authService.reauthenticateWithCredential(
        email: firebaseUser.email!,
        password: currentPassword,
      );

      await _authService.updateEmail(normalizedEmail);

      final updatedUser = _currentUser!.copyWith(
        email: normalizedEmail,
        updatedAt: DateTime.now(),
      );

      await _authRepository.updateUser(updatedUser);
      _currentUser = updatedUser;

      if (_localStorage != null) {
        await _localStorage!.saveUser(updatedUser);
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update email: $e';
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

      await _deletionRecoveryService.softDeleteUserAccount(
        userId: user.id,
        actorId: user.id,
        actorType: 'user',
        actorRole: user.role,
        reason: reason,
        cascadeOwnedBusinesses: user.isOwner,
      );

      await logout();
      return true;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _extractAuthErrorMessage(
        e,
        fallback: 'Failed to delete account. Please try again.',
      );
      notifyListeners();
      return false;
    }
  }

  /// Update a full user model and persist it across services/local storage
  Future<void> updateUserModel(UserModel updatedUser) async {
    try {
      await _authRepository.updateUser(updatedUser);
      // If the updated user matches the current user, update local state
      if (_currentUser != null && _currentUser!.id == updatedUser.id) {
        _currentUser = updatedUser;
        if (_localStorage != null) {
          await _localStorage!.saveUser(updatedUser);
        }
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update user. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  /// Switch current business for the logged-in user
  Future<bool> switchBusiness(String businessId) async {
    if (_currentUser == null) return false;
    try {
      // Debug: show previous currentBusinessId
      final prev = _currentUser?.currentBusinessId;
      debugPrint('[AuthProvider] switchBusiness: prev currentBusinessId=$prev; requested=$businessId');

      // Ensure businessId is present in businessIds
      final existing = _currentUser!.businessIds;
      final merged = List<String>.from({...existing, businessId});

      final updated = _currentUser!.copyWith(
        businessIds: merged,
        currentBusinessId: businessId,
      );

      // Persist to backend and local cache
      await _authRepository.updateUser(updated);
      _currentUser = updated;
      if (_localStorage != null) await _localStorage!.saveUser(updated);
      if (_localBusinessStorage != null) {
        final ok = await _localBusinessStorage!.setCurrentBusiness(businessId);
        debugPrint('[AuthProvider] switchBusiness: saved to local business storage: $ok');
      }
      await _cacheBusinessForUser(businessId);

      // Also update Firestore users collection for other clients
      try {
        await FirebaseFirestore.instance.collection('users').doc(updated.id).update({
          'currentBusinessId': businessId,
          'businessIds': FieldValue.arrayUnion([businessId]),
        });
        debugPrint('[AuthProvider] switchBusiness: firestore update sent for ${updated.id}');
      } catch (e) {
        // ignore best-effort failure
        print('[AuthProvider] Warning: failed to update user doc with currentBusinessId: $e');
      }

      if (updated.isOwner) {
        try {
          await _subscriptionService.syncUserSubscriptionSummaryFromBusiness(
            userId: updated.id,
            businessId: businessId,
          );
          _subscriptionValidated = await _validateSubscriptionForUser(
            updated,
            businessId: businessId,
          );
        } catch (e) {
          print(
              '[AuthProvider] Warning: failed to refresh subscription after switch: $e');
        }
      } else {
        _subscriptionValidated = true;
      }

      notifyListeners();
      debugPrint('[AuthProvider] switchBusiness: completed; new currentBusinessId=${_currentUser?.currentBusinessId}');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to switch business: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Change password for current user
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _errorMessage = 'No user logged in';
        notifyListeners();
        return false;
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to change password: $e';
      notifyListeners();
      return false;
    }
  }

  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  String _extractAuthErrorMessage(
    Object error, {
    String fallback = 'Authentication failed. Please try again.',
  }) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return fallback;

    const prefixes = [
      'Exception: ',
      'FirebaseException: ',
      'Authentication error: ',
      'Worker authentication failed: ',
    ];

    var message = raw;
    var changed = true;
    while (changed) {
      changed = false;
      for (final prefix in prefixes) {
        if (message.startsWith(prefix)) {
          message = message.substring(prefix.length).trim();
          changed = true;
        }
      }
    }

    return message.isEmpty ? fallback : message;
  }

  Future<void> _forceLogoutBecauseAccessChanged(String message) async {
    await logout();
    _errorMessage = message;
    notifyListeners();
  }

  /// Get persistent login status getter
  /// Returns true if user has opted in to stay logged in
  bool get isPersistentLoginEnabled =>
      _localStorage?.isAutoLoginEnabled() ?? false;

  /// Enable or disable persistent login
  /// When enabled, user will be auto-logged in on app restart
  Future<void> setPersistentLogin(bool enabled) async {
    try {
      if (_localStorage != null) {
        if (enabled && _currentUser != null) {
          await _localStorage!.saveUser(_currentUser!);
        } else {
          await _localStorage!.clearUser();
        }
        print(
            '[AuthProvider] Persistent login: ${enabled ? 'ENABLED' : 'DISABLED'}');
      }
    } catch (e) {
      print('[AuthProvider] Error setting persistent login: $e');
    }
  }

  /// Get the last logged-in email (useful for pre-filling login form)
  String? getLastLoggedInEmail() => _localStorage?.getLastLoggedInEmail();

  /// Notify business owner when a worker logs in
  Future<void> _notifyBusinessOwnerOfLogin(String workerId, String workerEmail) async {
    try {
      // Get worker's business associations
      final workerDoc = await FirebaseFirestore.instance.collection('users').doc(workerId).get();
      if (!workerDoc.exists) return;

      final workerData = workerDoc.data() as Map<String, dynamic>;
      final businessIds = workerData['businesses'] as List<dynamic>? ?? [];

      for (final businessId in businessIds) {
        if (businessId is String) {
          // Get business details to find owner
          final businessDoc = await FirebaseFirestore.instance.collection('businesses').doc(businessId).get();
          if (businessDoc.exists) {
            final businessData = businessDoc.data() as Map<String, dynamic>;
            final ownerId = businessData['ownerId'] as String?;
            final businessName = businessData['name'] as String? ?? 'Business';

            if (ownerId != null && ownerId.isNotEmpty) {
              // Send push notification to business owner
              final pushService = PushNotificationService();
              await pushService.sendNotificationToUser(
                userId: ownerId,
                title: '👤 Worker Login',
                body: '${workerData['name'] ?? workerEmail} logged into $businessName',
                data: {
                  'type': 'worker_login',
                  'workerId': workerId,
                  'workerEmail': workerEmail,
                  'businessId': businessId,
                  'businessName': businessName,
                  'timestamp': DateTime.now().toIso8601String(),
                },
              );
            }
          }
        }
      }
    } catch (e) {
      print('[AuthProvider] Error notifying business owner of login: $e');
    }
  }
}

