import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/data/models/user_model.dart';
import 'package:business_manager/providers/auth_provider.dart';

void main() {
  group('AuthProvider startup restore logic', () {
    test('uses cached user during startup when no Firebase session is available', () {
      final cachedUser = UserModel(
        id: 'user-1',
        email: 'owner@example.com',
        fullName: 'Owner User',
        role: 'owner',
        businessId: 'business-1',
        isActive: true,
        isOwner: true,
      );

      final shouldUseCachedUser = AuthProvider.shouldUseCachedUserDuringStartup(
        autoLoginEnabled: true,
        cachedUser: cachedUser,
        firebaseUserId: null,
      );

      expect(shouldUseCachedUser, isTrue);
    });

    test('does not use cached user when auto-login is disabled', () {
      final cachedUser = UserModel(
        id: 'user-2',
        email: 'worker@example.com',
        fullName: 'Worker User',
        role: 'staff',
        businessId: 'business-2',
        isActive: true,
      );

      final shouldUseCachedUser = AuthProvider.shouldUseCachedUserDuringStartup(
        autoLoginEnabled: false,
        cachedUser: cachedUser,
        firebaseUserId: null,
      );

      expect(shouldUseCachedUser, isFalse);
    });
  });
}
