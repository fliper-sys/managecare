import '../usecase.dart';

class UpdateStock implements UseCase<void, Map<String, dynamic>> {
  UpdateStock();

  @override
  Future<void> call(Map<String, dynamic> params) async {
    // TODO: update stock level in repository/local db
  }
}

