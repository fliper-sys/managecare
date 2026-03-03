/// Base use case interface
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// No parameters use case
class NoParams {}

