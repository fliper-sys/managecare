import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase Auth (GoTrue), mirroring the previous
/// FirebaseAuth-backed AuthService's public surface so callers don't need to
/// change. Session persistence/restore across app restarts is handled by the
/// supabase_flutter SDK itself (equivalent to FirebaseAuth's own behavior).
class AuthService {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  User? get currentUser => _auth.currentUser;

  /// Stream of the current Supabase auth user, or null when signed out.
  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user);

  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<AuthResponse> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signUp(email: email.trim(), password: password);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final email = _auth.currentUser?.email;
      if (email != null && _auth.currentUser?.emailConfirmedAt == null) {
        await _auth.resend(type: OtpType.signup, email: email);
      }
    } catch (e) {
      throw Exception('Failed to send verification email: $e');
    }
  }

  Future<void> reloadUser() async {
    try {
      await _auth.refreshSession();
    } catch (e) {
      throw Exception('Failed to reload user: $e');
    }
  }

  Future<void> updateEmail(String newEmail) async {
    try {
      await _auth.updateUser(UserAttributes(email: newEmail.trim()));
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Verifies the given credentials by signing in again. GoTrue has no
  /// separate "reauthenticate without replacing the session" primitive the
  /// way Firebase does; since this only succeeds for the same account, the
  /// resulting session is equivalent to the one it replaces.
  Future<AuthResponse> reauthenticateWithCredential({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Re-authentication failed: $e');
    }
  }

  /// Self-deletion requires the admin API (service-role key), which must
  /// never live client-side. Account deletion/soft-delete is handled through
  /// a server-side endpoint instead - see managecare-admin-api on the VPS.
  Future<void> deleteUser() async {
    throw UnimplementedError(
      'Self-service account deletion goes through a server-side admin '
      'endpoint, not the client SDK. See managecare-admin-api.',
    );
  }

  bool isUserLoggedIn() => _auth.currentUser != null;

  String? getUserId() => _auth.currentUser?.id;

  String? getUserEmail() => _auth.currentUser?.email;

  bool isEmailVerified() => _auth.currentUser?.emailConfirmedAt != null;
}
