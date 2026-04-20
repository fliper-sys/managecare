import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' as fb_core;
import '../data/models/user_model.dart';
import 'deletion_recovery_service.dart';

/// Comprehensive authentication service handling owner and worker login
class AuthenticationService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  late final DeletionRecoveryService _deletionRecoveryService;

  AuthenticationService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _deletionRecoveryService =
        DeletionRecoveryService(firestore: _firestore);
  }

  /// Authenticate user with email and password
  /// Returns UserModel on success, throws exception on failure
  Future<UserModel> authenticateUser({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with Firebase Auth
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Authentication failed: No user returned');
      }

      // Retrieve complete user data from Firestore and resolve
      // deletion/recovery access during explicit sign-in.
      final userModel = await _getAccessibleUserFromFirestore(
        userCredential.user!.uid,
        allowSelfRecovery: true,
      );

      if (userModel == null) {
        throw Exception('User profile not found in database');
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Authentication error: ${e.toString()}');
    }
  }

  Future<ResolvedUserAccess> resolveUserAccess(
    String firebaseUid, {
    bool allowSelfRecovery = false,
  }) {
    return _deletionRecoveryService.resolveUserAccess(
      firebaseUid,
      allowSelfRecovery: allowSelfRecovery,
    );
  }

  Future<UserModel?> _getAccessibleUserFromFirestore(
    String firebaseUid, {
    bool allowSelfRecovery = false,
  }) async {
    final access = await resolveUserAccess(
      firebaseUid,
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

  /// Get user data from Firestore by Firebase UID
  Future<UserModel?> _getUserFromFirestore(String firebaseUid) async {
    try {
      print(
          '[Auth._getUserFromFirestore] Fetching user profile for UID: $firebaseUid');
      final doc = await _firestore.collection('users').doc(firebaseUid).get();

      if (!doc.exists || doc.data() == null) {
        print(
            '[Auth._getUserFromFirestore] User document does NOT exist for UID: $firebaseUid');
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      print(
          '[Auth._getUserFromFirestore] User data: role=${data['role']}, businessId=${data['businessId']}, preferredBusinessId=${data['preferredBusinessId']}');

      // Ensure the ID matches Firebase UID
      data['id'] = firebaseUid;
      final userModel = UserModel.fromJson(data);
      print(
          '[Auth._getUserFromFirestore] Loaded UserModel: id=${userModel.id}, role=${userModel.role}, businessId=${userModel.businessId}');

      // Backfill/migrate legacy fields: if businessIds is empty but businessId exists, persist businessIds and currentBusinessId
      try {
        if ((userModel.businessIds.isEmpty) && (userModel.businessId.isNotEmpty)) {
          await _firestore.collection('users').doc(firebaseUid).set({
            'businessIds': [userModel.businessId],
            'currentBusinessId': userModel.businessId,
            'preferredBusinessId': userModel.preferredBusinessId ?? userModel.businessId,
            // Keep legacy businessId in sync
            'businessId': userModel.businessId,
          }, SetOptions(merge: true));
          print('[Auth._getUserFromFirestore] Migrated legacy businessId -> businessIds for user: $firebaseUid');
        } else if (userModel.businessIds.isNotEmpty) {
          // Ensure legacy businessId matches primary business
          final primary = userModel.primaryBusinessId;
          if (primary.isNotEmpty && primary != userModel.businessId) {
            await _firestore.collection('users').doc(firebaseUid).set({'businessId': primary}, SetOptions(merge: true));
            print('[Auth._getUserFromFirestore] Synchronized legacy businessId for user: $firebaseUid');
          }
        }
      } catch (e) {
        print('[Auth._getUserFromFirestore] Warning: failed to migrate business fields for $firebaseUid: $e');
      }

      return userModel;
    } catch (e) {
      print('[Auth._getUserFromFirestore] ERROR: $e');
      if (e is Exception) rethrow;
      throw Exception('Failed to load user profile: ${e.toString()}');
    }
  }

  /// Create a new worker user with Firebase Auth and Firestore
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
    try {
      // 1. Create Firebase Auth user using a temporary Firebase app so we don't
      // replace the currently signed-in user (common when admin creates a worker)
      try {
        // Lazily import Firebase core to reuse default app options
        final defaultApp = fb_core.Firebase.app();
        final tempAppName = 'temp_create_user_${DateTime.now().millisecondsSinceEpoch}';
        final tempApp = await fb_core.Firebase.initializeApp(
          name: tempAppName,
          options: defaultApp.options,
        );
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final authResult = await tempAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        // Clean up temp auth state and app
        await tempAuth.signOut();
        await tempApp.delete();

        if (authResult.user == null) {
          throw Exception('Failed to create authentication account');
        }

        final firebaseUid = authResult.user!.uid;

        // Continue below with creating Firestore user doc using firebaseUid
        
        // 2. Create Firestore user document
        // If businessType was not provided, attempt to read it from the businesses collection
        String? resolvedBusinessType = businessType;
        if ((resolvedBusinessType == null || resolvedBusinessType.isEmpty) &&
            businessId.isNotEmpty) {
          try {
            final bdoc = await _firestore.collection('businesses').doc(businessId).get();
            if (bdoc.exists) {
              final bdata = bdoc.data();
              resolvedBusinessType = bdata?['businessType'] as String?;
            }
          } catch (_) {}
        }

        final randomPin = pin ?? (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
        final userModel = UserModel(
          id: firebaseUid,
          email: email.trim(),
          fullName: fullName.trim(),
          phoneNumber: phoneNumber,
          role: role,
          businessId: businessId,
          // Ensure businessIds/current/preferred are set for new worker
          businessIds: businessId.isNotEmpty ? [businessId] : const [],
          currentBusinessId: businessId.isNotEmpty ? businessId : null,
          preferredBusinessId: businessId.isNotEmpty ? businessId : null,
          businessType: resolvedBusinessType,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
          isOwner: false,
          pin: randomPin,
        );

        await _firestore
            .collection('users')
            .doc(firebaseUid)
            .set(userModel.toJson());

        return userModel;
      } catch (e) {
        // If temp app approach fails, fallback to regular create (may sign-in the admin)
        final authResult = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        if (authResult.user == null) {
          throw Exception('Failed to create authentication account');
        }

        final firebaseUid = authResult.user!.uid;

        // 2. Create Firestore user document (fallback path)
        String? resolvedBusinessType = businessType;
        if ((resolvedBusinessType == null || resolvedBusinessType.isEmpty) &&
            businessId.isNotEmpty) {
          try {
            final bdoc = await _firestore.collection('businesses').doc(businessId).get();
            if (bdoc.exists) {
              final bdata = bdoc.data();
              resolvedBusinessType = bdata?['businessType'] as String?;
            }
          } catch (_) {}
        }

        final randomPin = pin ?? (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
        final userModel = UserModel(
          id: firebaseUid,
          email: email.trim(),
          fullName: fullName.trim(),
          phoneNumber: phoneNumber,
          role: role,
          businessId: businessId,
          businessIds: businessId.isNotEmpty ? [businessId] : const [],
          currentBusinessId: businessId.isNotEmpty ? businessId : null,
          preferredBusinessId: businessId.isNotEmpty ? businessId : null,
          businessType: resolvedBusinessType,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
          isOwner: false,
          pin: randomPin,
        );

        await _firestore
            .collection('users')
            .doc(firebaseUid)
            .set(userModel.toJson());

        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to create worker: ${e.toString()}');
    }
  }


  /// Verify worker credentials for manual verification
  Future<bool> verifyWorkerCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential.user != null;
    } catch (e) {
      return false;
    }
  }

  /// Get authentication error message based on Firebase error
  static String _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address';
      case 'wrong-password':
        return 'Incorrect password. Please try again';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'The email address format is invalid';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  /// Authenticate worker by worker ID or email and password
  /// Looks up the worker in Firestore by ID or email, then authenticates via Firebase
  Future<UserModel> authenticateWorkerByWorkerId({
    required String workerId,
    required String password,
  }) async {
    try {
      print('[Auth] Attempting worker authentication for: $workerId');

      // 1. First try to find worker by ID
      var workerDoc =
          await _firestore.collection('workers').doc(workerId).get();

      // 2. If not found by ID, try searching by email
      if (!workerDoc.exists) {
        print(
            '[Auth] Worker not found by ID ($workerId), searching by email...');
        final workerQuery = await _firestore
            .collection('workers')
            .where('email', isEqualTo: workerId)
            .limit(1)
            .get();

        if (workerQuery.docs.isEmpty) {
          print('[Auth] Worker document not found for ID or email: $workerId');
          throw Exception('Worker not found with ID or email: $workerId');
        }

        workerDoc = workerQuery.docs.first;
      }

      final workerData = workerDoc.data() as Map<String, dynamic>;
      final workerEmail = workerData['email'] as String?;
      final workerRole = workerData['role'] as String? ?? 'staff';
      final workerBusinessId = workerData['businessId'] as String?;

      // Try to infer businessType from worker record or business doc
      String? workerBusinessType = (workerData['businessType'] as String?) ?? (workerData['industry'] as String?);
      if ((workerBusinessType == null || workerBusinessType.isEmpty) && (workerBusinessId != null && workerBusinessId.isNotEmpty)) {
        try {
          final bdoc = await _firestore.collection('businesses').doc(workerBusinessId).get();
          if (bdoc.exists) {
            final bdata = bdoc.data();
            workerBusinessType = bdata?['businessType'] as String?;
          }
        } catch (_) {}
      }

      if (workerEmail == null || workerEmail.isEmpty) {
        print('[Auth] Worker email not configured for ID: $workerId');
        throw Exception('Worker email not configured');
      }

      print(
          '[Auth] Found worker email: $workerEmail, role: $workerRole, businessId: $workerBusinessId');

      // 3. Authenticate with the worker's email and password
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: workerEmail,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Firebase authentication failed');
      }

      // 4. Load the UserModel from users collection
      var userModel = await _getUserFromFirestore(userCredential.user!.uid);

      if (userModel == null) {
        print(
            '[Auth] User profile not found in Firestore, creating one for worker...');

        // Create a user document for the worker
        final workerStoreId = workerData['storeId'] as String?;

        userModel = UserModel(
          id: userCredential.user!.uid,
          email: workerEmail,
          fullName:
              workerEmail.split('@')[0], // Use email prefix as default name
          role: workerRole,
          businessId: workerBusinessId as String,
          // Ensure this worker user has the business in the array and current/preferred set
          businessIds: (workerBusinessId.isNotEmpty) ? [workerBusinessId] : const [],
          currentBusinessId: (workerBusinessId.isNotEmpty) ? workerBusinessId : null,
          preferredBusinessId: (workerBusinessId.isNotEmpty) ? workerBusinessId : null,
          businessType: workerBusinessType,
          storeId: workerStoreId,
          isOwner: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        // Save to Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'id': userModel.id,
          'email': userModel.email,
          'fullName': userModel.fullName,
          'role': userModel.role,
          'businessId': userModel.businessId,
          'businessIds': userModel.businessIds,
          'currentBusinessId': userModel.currentBusinessId,
          'preferredBusinessId': userModel.preferredBusinessId,
          'isOwner': false,
          'businessType': workerData['businessType'] ?? workerData['industry'] ?? null,
          'storeId': workerStoreId ?? null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        print('[Auth] Created user profile for worker: ${userModel.id}');
      }

      // 5. IMPORTANT: Ensure role and businessId are set from worker record
      // The user document might not have these fields set correctly
      if (userModel.role.isEmpty) {
        userModel = userModel.copyWith(role: workerRole);
        print('[Auth] Updated user role to: $workerRole');
      }

      if (userModel.businessId.isEmpty && workerBusinessId != null) {
        // Merge into businessIds, set current/preferred and persist to Firestore
        final mergedBusinessIds = List<String>.from({...userModel.businessIds, workerBusinessId});
        userModel = userModel.copyWith(
          businessId: workerBusinessId,
          businessIds: mergedBusinessIds,
          currentBusinessId: workerBusinessId,
          preferredBusinessId: workerBusinessId,
        );
        try {
          await _firestore.collection('users').doc(userModel.id).set({
            'businessIds': FieldValue.arrayUnion([workerBusinessId]),
            'currentBusinessId': workerBusinessId,
            'preferredBusinessId': workerBusinessId,
            'businessId': workerBusinessId,
          }, SetOptions(merge: true));
          print('[Auth] Persisted worker businessId and businessIds for user: ${userModel.id}');
        } catch (e) {
          print('[Auth] Warning: failed to persist worker business info: $e');
        }
      }

      // Ensure businessType is set on the user model and persist if missing
      if ((userModel.businessType == null || (userModel.businessType?.isEmpty ?? true)) && (workerBusinessType != null && workerBusinessType.isNotEmpty)) {
        userModel = userModel.copyWith(businessType: workerBusinessType);
        try {
          await _firestore.collection('users').doc(userModel.id).update({'businessType': workerBusinessType});
          print('[Auth] Updated user businessType to: $workerBusinessType');
        } catch (_) {
          // Non-fatal
        }
      }

      // Ensure storeId from worker record is set on user model
      final workerStoreId = workerData['storeId'] as String?;
      if ((userModel.storeId == null || (userModel.storeId?.isEmpty ?? true)) && (workerStoreId != null && workerStoreId.isNotEmpty)) {
        userModel = userModel.copyWith(storeId: workerStoreId);
        try {
          await _firestore.collection('users').doc(userModel.id).update({'storeId': workerStoreId});
          print('[Auth] Updated user storeId to: $workerStoreId');
        } catch (_) {
          // Non-fatal
        }
      }

      final resolvedUser = await _getAccessibleUserFromFirestore(
        userCredential.user!.uid,
        allowSelfRecovery: true,
      );
      if (resolvedUser == null) {
        throw Exception('Worker profile not found in database');
      }

      print(
          '[Auth] Worker authentication successful: ${resolvedUser.id}, role: ${resolvedUser.role}, businessId: ${resolvedUser.businessId}');
      return resolvedUser;
    } on FirebaseAuthException catch (e) {
      print('[Auth] Firebase Auth Exception: ${e.code} - ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      print('[Auth] Worker authentication error: $e');
      if (e is Exception) rethrow;
      throw Exception('Worker authentication failed: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Check if user is currently authenticated
  bool get isUserAuthenticated => _firebaseAuth.currentUser != null;

  /// Get current Firebase user
  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Listen to authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}

