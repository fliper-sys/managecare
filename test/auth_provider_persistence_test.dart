import 'package:business_manager/providers/auth_provider_supabase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('persisted-session startup routing', () {
    test('keeps a cached user session alive while auth initialization is still settling', () {
      final shouldNavigateToLogin = shouldNavigateToLoginOnStartup(
        status: AuthStatus.initial,
        isAuthenticated: false,
        hasCachedUser: true,
        autoLoginEnabled: true,
      );

      expect(shouldNavigateToLogin, isFalse);
    });

    test('still routes to login when no cached session exists', () {
      final shouldNavigateToLogin = shouldNavigateToLoginOnStartup(
        status: AuthStatus.unauthenticated,
        isAuthenticated: false,
        hasCachedUser: false,
        autoLoginEnabled: false,
      );

      expect(shouldNavigateToLogin, isTrue);
    });

    test('does not force login when a persisted session exists', () {
      final shouldNavigateToLogin = shouldNavigateToLoginOnStartup(
        status: AuthStatus.authenticated,
        isAuthenticated: false,
        hasCachedUser: true,
        autoLoginEnabled: true,
      );

      expect(shouldNavigateToLogin, isFalse);
    });
  });
}
