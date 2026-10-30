import 'package:business_manager/data/models/user_model.dart';
import 'package:business_manager/services/local_user_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saved user and auto-login setting survive a storage reload', () async {
    final storage = await LocalUserStorage.create();
    final user = UserModel(
      id: 'user-id',
      email: 'owner@example.com',
      fullName: 'Business Owner',
      role: 'owner',
      businessId: 'business-id',
      businessIds: const ['business-id'],
      isActive: true,
      isOwner: true,
    );

    expect(await storage.saveUser(user), isTrue);

    final reopenedStorage = await LocalUserStorage.create();
    await reopenedStorage.reload();

    expect(reopenedStorage.isAutoLoginEnabled(), isTrue);
    expect(reopenedStorage.getCachedUser()?.id, user.id);
    expect(reopenedStorage.getCachedUser()?.businessId, user.businessId);
  });

  test('clearing user disables auto-login and removes cached profile',
      () async {
    final storage = await LocalUserStorage.create();
    final user = UserModel(
      id: 'user-id',
      email: 'owner@example.com',
      fullName: 'Business Owner',
      role: 'owner',
      businessId: 'business-id',
      isActive: true,
      isOwner: true,
    );
    await storage.saveUser(user);

    expect(await storage.clearUser(), isTrue);
    expect(storage.isAutoLoginEnabled(), isFalse);
    expect(storage.getCachedUser(), isNull);
  });
}
