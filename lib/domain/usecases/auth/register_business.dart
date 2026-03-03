import '../../entities/user.dart';
import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class RegisterBusiness implements UseCase<User, RegisterBusinessParams> {
  final AuthRepository repository;

  RegisterBusiness(this.repository);

  @override
  Future<User> call(RegisterBusinessParams params) async {
    return await repository.register(
      email: params.email,
      password: params.password,
      name: params.name,
      businessName: params.businessName,
      businessType: params.businessType,
    );
  }
}

class RegisterBusinessParams {
  final String email;
  final String password;
  final String name;
  final String businessName;
  final String businessType;

  RegisterBusinessParams({
    required this.email,
    required this.password,
    required this.name,
    required this.businessName,
    required this.businessType,
  });
}

