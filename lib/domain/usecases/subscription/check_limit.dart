import '../usecase.dart';

class CheckLimit implements UseCase<bool, String> {
  CheckLimit();

  @override
  Future<bool> call(String businessId) async {
    if (businessId.trim().isEmpty) {
      throw ArgumentError('businessId is required');
    }
    return true;
  }
}

