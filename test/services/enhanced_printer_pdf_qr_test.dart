import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/enhanced_pdf_builder.dart';

void main() {
  test('build58mmPdf generates PDF bytes and includes QR when requested', () async {
    final bytes = await EnhancedPdfBuilder.buildPdf(
      businessName: 'Test Station',
      address: '12 Example St',
      phone: '+2348012345678',
      orderId: 'R999',
      date: DateTime.now(),
      items: [
        {'name': 'Item A', 'quantity': 1, 'unitPrice': 100, 'total': 100},
      ],
      subtotal: 100,
      tax: 0,
      discount: 0,
      total: 100,
      paymentMethod: 'Cash',
      footerMessage: 'Thanks',
      currencySymbol: '₦',
      showQrCode: true,
      receiptUrlBase: 'https://example.com/receipt',
    );

    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(200));
  });
}
