import '../usecase.dart';

class ProcessPayment
    implements UseCase<Map<String, dynamic>, Map<String, dynamic>> {
  ProcessPayment();

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
    final amount = (params['amount'] as num?)?.toDouble() ?? 0.0;
    final method = params['method']?.toString() ?? 'unknown';
    if (amount <= 0) {
      return {
        'success': false,
        'status': 'failed',
        'message': 'Invalid payment amount',
        'reference': null,
      };
    }

    return {
      'success': true,
      'status': 'completed',
      'amount': amount,
      'method': method,
      'reference': params['reference']?.toString() ??
          'pay_${DateTime.now().microsecondsSinceEpoch}',
      'processedAt': DateTime.now().toIso8601String(),
    };
  }
}

