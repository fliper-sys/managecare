import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class ResetPassword implements UseCase<void, ResetPasswordParams> {
  final AuthRepository repository;

  ResetPassword(this.repository);

  @override
  Future<void> call(ResetPasswordParams params) async {
    return await repository.resetPassword(params.email);
  }
}

class ResetPasswordParams {
  final String email;

  ResetPasswordParams({required this.email});
}

