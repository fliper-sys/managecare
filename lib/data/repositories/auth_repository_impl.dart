import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../../core/config/firebase_config.dart';
import 'auth_repository.dart';

/// Auth service implementation
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepositoryImpl({required FirebaseAuth firebaseAuth})
      : _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> login(
      {required String email, required String password}) async {
    try {
      final result = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user?.uid ?? '';
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> registerBusiness(
      {required Map<String, dynamic> businessData}) async {
    try {
      final email = businessData['email'] as String;
      final password = businessData['password'] as String;

      final result = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final displayName = businessData['businessName'] as String?;
      if (displayName != null && result.user != null) {
        await result.user!.updateDisplayName(displayName);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Persist a new user document in Firestore users collection
  @override
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(user.id)
          .set(user.toJson());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCurrentUser(String uid) async {
    try {
      // Attempt to fetch user document from Firestore users collection
      final doc = await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromJson(data);
      }

      // Fallback to Firebase Auth basic mapping
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        return UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          fullName: firebaseUser.displayName ?? '',
          phoneNumber: firebaseUser.phoneNumber ?? '',
          role: 'owner',
          businessId: '',
          createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      // Save user document to Firestore
      await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(user.id)
          .set(user.toJson(), SetOptions(merge: true));
      // Also update Firebase Auth profile if current user matches
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null && firebaseUser.uid == user.id) {
        await firebaseUser.updateDisplayName(user.fullName);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      // Update user document in Firestore. If the document doesn't exist,
      // fallback to set() with merge to create it (this avoids silent
      // failures when update() throws on missing docs).
      final docRef = _firestore.collection(FirebaseConfig.usersCollection).doc(user.id);
      try {
        await docRef.update(user.toJson());
      } catch (e) {
        // If update fails (e.g., document missing), use set with merge
        await docRef.set(user.toJson(), SetOptions(merge: true));
      }

      // Keep FirebaseAuth profile in sync if possible
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null && firebaseUser.uid == user.id) {
        try {
          await firebaseUser.updateDisplayName(user.fullName);
        } catch (_) {
          // non-fatal
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}

