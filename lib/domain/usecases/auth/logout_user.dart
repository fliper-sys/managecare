import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class NoParams {
  const NoParams();
}

class LogoutUser implements UseCase<void, NoParams> {
  final AuthRepository repository;

  LogoutUser(this.repository);

  @override
  Future<void> call(NoParams params) async {
    return await repository.logout();
  }
}

