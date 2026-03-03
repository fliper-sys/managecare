import '../usecase.dart';

class CheckLimit implements UseCase<bool, String> {
  CheckLimit();

  @override
  Future<bool> call(String businessId) async {
    // TODO: check subscription limits for the business
    return true;
  }
}

