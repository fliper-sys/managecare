import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:business_manager/services/esc_pos_receipt_generator.dart';

void main() {
  group('ESC/POS Receipt Generator Tests', () {
    test('Generate receipt returns Uint8List', () {
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: 'Item 1',
            quantity: 1,
            unitPrice: 10.0,
            total: 10.0,
          ),
        ],
        subtotal: 10.0,
        tax: 1.0,
        discount: 0.0,
        total: 11.0,
        paymentMethod: 'Cash',
      );
      expect(receipt, isA<Uint8List>());
      expect(receipt.length, greaterThan(0));
    });

    test('Generated receipt contains initialization command', () {
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [],
        subtotal: 0.0,
        tax: 0.0,
        discount: 0.0,
        total: 0.0,
        paymentMethod: 'Cash',
      );
      // ESC @ = [0x1B, 0x40]
      expect(receipt.contains(0x1B), true);
      expect(receipt.contains(0x40), true);
    });

    test('Generated receipt contains cut paper command', () {
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [],
        subtotal: 0.0,
        tax: 0.0,
        discount: 0.0,
        total: 0.0,
        paymentMethod: 'Cash',
      );
      // GS V = [0x1D, 0x56]
      expect(receipt.contains(0x1D), true);
      expect(receipt.contains(0x56), true);
    });

    test('Receipt with multiple items is larger than single item', () {
      final singleItemReceipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: 'Item 1',
            quantity: 1,
            unitPrice: 10.0,
            total: 10.0,
          ),
        ],
        subtotal: 10.0,
        tax: 1.0,
        discount: 0.0,
        total: 11.0,
        paymentMethod: 'Cash',
      );

      final multipleItemsReceipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: 'Item 1',
            quantity: 1,
            unitPrice: 10.0,
            total: 10.0,
          ),
          ReceiptLineItem(
            name: 'Item 2',
            quantity: 2,
            unitPrice: 5.0,
            total: 10.0,
          ),
          ReceiptLineItem(
            name: 'Item 3',
            quantity: 1,
            unitPrice: 15.0,
            total: 15.0,
          ),
        ],
        subtotal: 35.0,
        tax: 3.5,
        discount: 0.0,
        total: 38.5,
        paymentMethod: 'Card',
      );

      expect(multipleItemsReceipt.length, greaterThan(singleItemReceipt.length));
    });

    test('Receipt with discount is generated', () {
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: 'Item 1',
            quantity: 1,
            unitPrice: 10.0,
            total: 10.0,
          ),
        ],
        subtotal: 10.0,
        tax: 0.9,
        discount: 1.0,
        total: 9.9,
        paymentMethod: 'Cash',
      );
      expect(receipt, isA<Uint8List>());
      expect(receipt.length, greaterThan(0));
    });

    test('Receipt with customer info is generated', () {
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: 'Item 1',
            quantity: 1,
            unitPrice: 10.0,
            total: 10.0,
          ),
        ],
        subtotal: 10.0,
        tax: 1.0,
        discount: 0.0,
        total: 11.0,
        paymentMethod: 'Cash',
        customerName: 'John Doe',
        storeName: 'Main Store',
        storeAddress: '123 Main St, City',
        storeTelephone: '555-1234',
      );
      expect(receipt, isA<Uint8List>());
      expect(receipt.length, greaterThan(0));
    });

    test('Receipt with 58mm paper width is generated', () {
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [],
        subtotal: 0.0,
        tax: 0.0,
        discount: 0.0,
        total: 0.0,
        paymentMethod: 'Cash',
        paperWidth: 58,
      );
      expect(receipt, isA<Uint8List>());
    });

    test('Receipt with 80mm paper width is generated', () {
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [],
        subtotal: 0.0,
        tax: 0.0,
        discount: 0.0,
        total: 0.0,
        paymentMethod: 'Cash',
        paperWidth: 80,
      );
      expect(receipt, isA<Uint8List>());
    });
  });

  group('Receipt Line Item Tests', () {
    test('Create receipt line item', () {
      final item = ReceiptLineItem(
        name: 'Product A',
        quantity: 2,
        unitPrice: 15.0,
        total: 30.0,
      );
      expect(item.name, equals('Product A'));
      expect(item.quantity, equals(2));
      expect(item.unitPrice, equals(15.0));
      expect(item.total, equals(30.0));
    });

    test('Receipt line item with decimals', () {
      final item = ReceiptLineItem(
        name: 'Service',
        quantity: 1.5,
        unitPrice: 20.5,
        total: 30.75,
      );
      expect(item.quantity, equals(1.5));
      expect(item.unitPrice, equals(20.5));
      expect(item.total, equals(30.75));
    });
  });

  group('ESC/POS Alignment Tests', () {
    test('All alignment values are defined', () {
      expect(EscPosAlignment.left, isNotNull);
      expect(EscPosAlignment.center, isNotNull);
      expect(EscPosAlignment.right, isNotNull);
    });

    test('Alignment enum has correct index values', () {
      expect(EscPosAlignment.left.index, equals(0));
      expect(EscPosAlignment.center.index, equals(1));
      expect(EscPosAlignment.right.index, equals(2));
    });
  });

  group('ESC/POS Font Size Tests', () {
    test('All font size values are defined', () {
      expect(EscPosFontSize.small, isNotNull);
      expect(EscPosFontSize.large, isNotNull);
    });

    test('Font size enum has correct index values', () {
      expect(EscPosFontSize.small.index, equals(0));
      expect(EscPosFontSize.large.index, equals(1));
    });
  });

  group('ESC/POS Buffer Tests', () {
    test('Create ESC/POS buffer for 58mm paper', () {
      final buffer = EscPosBuffer(58);
      expect(buffer.paperWidth, equals(58));
    });

    test('Create ESC/POS buffer for 80mm paper', () {
      final buffer = EscPosBuffer(80);
      expect(buffer.paperWidth, equals(80));
    });

    test('Initialize printer adds bytes', () {
      final buffer = EscPosBuffer(58);
      buffer.initializePrinter();
      final bytes = buffer.getBytes();
      expect(bytes.length, greaterThan(0));
    });

    test('Print text adds bytes', () {
      final buffer = EscPosBuffer(58);
      buffer.printText('Hello World');
      final bytes = buffer.getBytes();
      expect(bytes.length, greaterThan(0));
    });

    test('Print text with bold formatting', () {
      final buffer = EscPosBuffer(58);
      buffer.printText('Bold Text', bold: true);
      final bytes = buffer.getBytes();
      expect(bytes.length, greaterThan(0));
    });

    test('Print text with large font size', () {
      final buffer = EscPosBuffer(58);
      buffer.printText('Large Text', fontSize: EscPosFontSize.large);
      final bytes = buffer.getBytes();
      expect(bytes.length, greaterThan(0));
    });

    test('Print dashed line', () {
      final buffer = EscPosBuffer(58);
      buffer.printDashedLine();
      final bytes = buffer.getBytes();
      expect(bytes.length, greaterThan(0));
    });

    test('Set alignment center', () {
      final buffer = EscPosBuffer(58);
      buffer.setAlignment(EscPosAlignment.center);
      final bytes = buffer.getBytes();
      expect(bytes.length, greaterThan(0));
    });

    test('Cut paper adds bytes', () {
      final buffer = EscPosBuffer(58);
      buffer.cutPaper();
      final bytes = buffer.getBytes();
      expect(bytes.length, greaterThan(0));
    });

    test('Complete receipt buffer sequence', () {
      final buffer = EscPosBuffer(58);
      buffer.initializePrinter();
      buffer.setAlignment(EscPosAlignment.center);
      buffer.printText('Receipt', bold: true);
      buffer.printDashedLine();
      buffer.setAlignment(EscPosAlignment.left);
      buffer.printText('Item: 10.00');
      buffer.printLine();
      buffer.cutPaper();
      
      final bytes = buffer.getBytes();
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });
  });

  group('Thermal Receipt Generation Integration Tests', () {
    test('Complex receipt with all features', () {
      final now = DateTime.now();
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Premium Retail Store',
        receiptNumber: 'REC-2024-001',
        receiptDate: now,
        items: [
          ReceiptLineItem(
            name: 'Shirt',
            quantity: 1,
            unitPrice: 29.99,
            total: 29.99,
          ),
          ReceiptLineItem(
            name: 'Pants',
            quantity: 2,
            unitPrice: 49.99,
            total: 99.98,
          ),
          ReceiptLineItem(
            name: 'Socks',
            quantity: 3,
            unitPrice: 5.99,
            total: 17.97,
          ),
        ],
        subtotal: 147.94,
        tax: 14.79,
        discount: 5.00,
        total: 157.73,
        paymentMethod: 'Credit Card',
        customerName: 'John Smith',
        storeName: 'Main Branch',
        storeAddress: '123 Fashion Ave, Retail City, RC 12345',
        storeTelephone: '555-SHOP-123',
        paperWidth: 80,
      );

      expect(receipt, isA<Uint8List>());
      expect(receipt.length, greaterThan(100)); // Should have substantial content
    });

    test('Minimal receipt generation', () {
      final receipt = EscPosReceiptGenerator.generateReceipt(
        businessName: 'Minimal Business',
        receiptNumber: '1',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: 'Item',
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
      );

      expect(receipt, isA<Uint8List>());
      expect(receipt.length, greaterThan(0));
    });
  });
}
