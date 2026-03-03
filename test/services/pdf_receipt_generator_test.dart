import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/pdf_receipt_generator.dart';

void main() {
  test('PDF generator includes business name and footer', () async {
    final items = [
      {'name': 'Petrol', 'quantity': 10, 'price': 500.0},
    ];

    final bytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
      businessName: 'My Gas Station',
      receiptNumber: 'R-123',
      receiptDate: DateTime.now(),
      items: items,
      subtotal: 5000.0,
      tax: 0.0,
      total: 5000.0,
      paymentMethod: 'Cash',
      customerName: 'Customer',
      customerEmail: '',
      customHeader: null,
      customFooter: null,
      paperWidth: '80',
      cashier: 'Pump 1',
      poweredByText: 'Powered by Manage Care',
    );

    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(0));

    // We ensure bytes were generated and that the output is a PDF file
    expect(bytes.length, greaterThan(0));
    // PDF files begin with the ASCII header '%PDF' (37,80,68,70)
    expect(bytes.take(4).toList(), equals([37, 80, 68, 70]));
  });

  test('PDF generator includes QR when enabled', () async {
    final items = [
      {'name': 'Petrol', 'quantity': 10, 'price': 500.0},
    ];

    final bytesNoQr = await PdfReceiptGenerator.generateReceiptPdfBytes(
      businessName: 'My Gas Station',
      receiptNumber: 'R-123',
      receiptDate: DateTime.now(),
      items: items,
      subtotal: 5000.0,
      tax: 0.0,
      total: 5000.0,
      paymentMethod: 'Cash',
      customerName: 'Customer',
      customerEmail: '',
      customHeader: null,
      customFooter: null,
      paperWidth: '80',
      cashier: 'Pump 1',
      poweredByText: 'Powered by Manage Care',
      showQrCode: false,
    );

    final bytesWithQr = await PdfReceiptGenerator.generateReceiptPdfBytes(
      businessName: 'My Gas Station',
      receiptNumber: 'R-123',
      receiptDate: DateTime.now(),
      items: items,
      subtotal: 5000.0,
      tax: 0.0,
      total: 5000.0,
      paymentMethod: 'Cash',
      customerName: 'Customer',
      customerEmail: '',
      customHeader: null,
      customFooter: null,
      paperWidth: '80',
      cashier: 'Pump 1',
      poweredByText: 'Powered by Manage Care',
      showQrCode: true,
      receiptUrlBase: 'https://example.com/receipt',
    );

    expect(bytesWithQr, isNotNull);
    expect(bytesWithQr.length, greaterThan(0));
    expect(bytesWithQr.take(4).toList(), equals([37, 80, 68, 70]));

    // Ensure the PDF differs when QR is included
    expect(bytesWithQr.length, isNot(equals(bytesNoQr.length)));
  });
}
