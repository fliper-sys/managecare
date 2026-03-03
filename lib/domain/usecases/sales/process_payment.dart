import '../usecase.dart';

class ProcessPayment
    implements UseCase<Map<String, dynamic>, Map<String, dynamic>> {
  ProcessPayment();

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
    // TODO: integrate with PaymentRepository/service
    return {};
  }
}

