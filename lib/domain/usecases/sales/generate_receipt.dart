import '../usecase.dart';

class GenerateReceipt
    implements UseCase<Map<String, dynamic>, Map<String, dynamic>> {
  GenerateReceipt();

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
    final now = DateTime.now();
    final receiptId =
        params['receiptId']?.toString() ?? 'rcpt_${now.microsecondsSinceEpoch}';
    final businessName = params['businessName']?.toString() ?? 'Business';
    final orderId = params['orderId']?.toString() ?? '';
    final totalAmount = (params['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final items = (params['items'] as List?) ?? const [];

    final lines = <String>[
      businessName,
      if (orderId.isNotEmpty) 'Order: $orderId',
      'Receipt: $receiptId',
      'Date: ${now.toIso8601String()}',
      '',
      ...items.map((item) => '- ${item.toString()}'),
      '',
      'Total: $totalAmount',
    ];

    return {
      'receiptId': receiptId,
      'path': '',
      'content': lines.join('\n'),
      'createdAt': now.toIso8601String(),
    };
  }
}

