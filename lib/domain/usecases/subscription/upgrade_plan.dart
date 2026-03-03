import '../usecase.dart';

class UpgradePlan implements UseCase<void, Map<String, dynamic>> {
  UpgradePlan();

  @override
  Future<void> call(Map<String, dynamic> params) async {
    // TODO: call billing / subscription service to upgrade plan
  }
}

