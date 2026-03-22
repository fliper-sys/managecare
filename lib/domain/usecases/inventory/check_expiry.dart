import '../usecase.dart';

class CheckExpiry implements UseCase<List<Map<String, dynamic>>, String> {
  CheckExpiry();

  @override
  Future<List<Map<String, dynamic>>> call(String params) async {
    if (params.trim().isEmpty) {
      throw ArgumentError('businessId is required');
    }
    return [];
  }
}

