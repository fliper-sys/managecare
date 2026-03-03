/// Abstract auth repository interface
abstract class AuthRepository {
  Future<dynamic> login(String email, String password);
  Future<dynamic> register({
    required String email,
    required String password,
    required String name,
    required String businessName,
    required String businessType,
  });
  Future<void> logout();
  Future<void> resetPassword(String email);
  Future<dynamic> getCurrentUser();
}

