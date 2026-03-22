import '../usecase.dart';

class UpgradePlan implements UseCase<void, Map<String, dynamic>> {
  UpgradePlan();

  @override
  Future<void> call(Map<String, dynamic> params) async {
    final businessId = params['businessId']?.toString() ?? '';
    final newPlan = params['newPlan']?.toString() ?? '';
    if (businessId.isEmpty || newPlan.isEmpty) {
      throw ArgumentError('businessId and newPlan are required');
    }
  }
}

