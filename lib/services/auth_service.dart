import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw Exception('Failed to send verification email: $e');
    }
  }

  // Reload user
  Future<void> reloadUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
    } catch (e) {
      throw Exception('Failed to reload user: $e');
    }
  }

  // Update email
  Future<void> updateEmail(String newEmail) async {
    try {
      // Firebase SDK v6+ uses verifyBeforeUpdateEmail instead of updateEmail
      await _firebaseAuth.currentUser?.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _firebaseAuth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  // Re-authenticate user
  Future<UserCredential> reauthenticateWithCredential({
    required String email,
    required String password,
  }) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      return await _firebaseAuth.currentUser!
          .reauthenticateWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Re-authentication failed: $e');
    }
  }

  // Delete user
  Future<void> deleteUser() async {
    try {
      await _firebaseAuth.currentUser?.delete();
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Check if user is logged in
  bool isUserLoggedIn() {
    return _firebaseAuth.currentUser != null;
  }

  // Get user ID
  String? getUserId() {
    return _firebaseAuth.currentUser?.uid;
  }

  // Get user email
  String? getUserEmail() {
    return _firebaseAuth.currentUser?.email;
  }

  // Check if email is verified
  bool isEmailVerified() {
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }
}

