import '../models/user_model.dart';

abstract class AuthRepository {
  Future<String> login({required String email, required String password});
  Future<void> registerBusiness({required Map<String, dynamic> businessData});
  Future<void> logout();
  Future<void> resetPassword(String email);
  Future<UserModel?> getCurrentUser(String uid);
  Future<void> createUser(UserModel user);
  Future<void> updateUser(UserModel user);
}

