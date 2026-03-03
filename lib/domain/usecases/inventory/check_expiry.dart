import '../usecase.dart';

class CheckExpiry implements UseCase<List<Map<String, dynamic>>, String> {
  CheckExpiry();

  @override
  Future<List<Map<String, dynamic>>> call(String params) async {
    // TODO: return list of expired or near-expiry items for a business
    return [];
  }
}

