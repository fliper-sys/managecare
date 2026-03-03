import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/email_template_service.dart';

void main() {
  test('Receipt HTML contains product names from items', () {
    final items = [
      {'name': 'Premium Layer Feed', 'quantity': 2, 'price': 2500},
      {'name': 'Vitamin Supplements', 'quantity': 1, 'price': 1500},
    ];

    final html = EmailTemplateService.generateReceiptEmailHtml(
      businessName: 'Test Farm',
      businessLogo: null,
      businessContact: '08000000000',
      receiptNumber: 'RCPT-123',
      receiptDate: DateTime(2025, 1, 1),
      customerName: 'John Doe',
      items: items,
      subtotal: 6500.0,
      tax: 0.0,
      total: 6500.0,
      paymentMethod: 'Cash',
      customHeader: null,
      customFooter: null,
    );

    expect(html.contains('Premium Layer Feed'), isTrue);
    expect(html.contains('Vitamin Supplements'), isTrue);
    expect(html.contains('RCPT-123'), isTrue);
  });
}
