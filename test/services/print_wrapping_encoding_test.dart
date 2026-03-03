import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:business_manager/services/esc_pos_receipt_generator.dart';
import 'package:business_manager/services/thermal_printer_manager.dart';

void main() {
  group('Receipt wrapping & encoding tests', () {
    test('Long single-word item is wrapped (80mm)', () {
      // Create an extremely long single-word name (no spaces)
      final longName = 'A' * 120; // 120 chars, longer than 80mm chars-per-line (48)

      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'WrapTest',
        receiptNumber: 'WRAP-001',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: longName,
            quantity: 1,
            unitPrice: 1.0,
            total: 1.0,
          ),
        ],
        subtotal: 1.0,
        tax: 0.0,
        discount: 0.0,
        total: 1.0,
        paymentMethod: 'Cash',
        paperWidth: 80,
      );

      // Decode bytes to a string for inspection
      final decoded = utf8.decode(receipt, allowMalformed: true);

      // The full longName should NOT appear as an unbroken substring (it should be split)
      expect(decoded.contains(longName), isFalse, reason: 'Long single-word should be wrapped and not appear intact');

      // The first chunk should appear (first chunk width for 80mm: 26 chars per internal layout)
      final firstChunk = longName.substring(0, 26);
      expect(decoded.contains(firstChunk), isTrue);
      // Ensure that a newline occurred within the printed long word area
      // (there should be at least one linefeed in the output)
      expect(decoded.contains('\n'), isTrue);
    });

    test('Naira symbol is normalized to NGN in encoded bytes', () {
      final text = 'Total: ₦1000';

      final bytes = encodePrintableText(text);
      final decoded = utf8.decode(bytes, allowMalformed: true);

      expect(decoded.contains('₦'), isFalse, reason: 'Naira symbol should be normalized');
      expect(decoded.contains('NGN '), isTrue, reason: 'Should contain NGN fallback');
    });
  });
}
