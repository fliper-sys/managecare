import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/report_export_service.dart';

// Ensure WidgetsFlutterBinding is initialized for PDF operations in tests
void _ensureBinding() {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (_) {}
}

void main() {
  group('ReportExportService', () {
    test('exportProcurementsPdf writes a PDF file', () async {
      _ensureBinding();
      final service = ReportExportService();
      final temp = Directory.systemTemp;
      final path = '${temp.path}/procurements_test_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final procurements = [
        {
          'id': 'proc_1',
          'createdAt': DateTime.now(),
          'supplierName': 'Supplier One',
          'invoiceRef': 'INV-1001',
          'totalCost': 150.0,
          'totalQuantity': 5,
          'items': [
            {'name': 'Product A', 'quantity': 2, 'cost': 20.0, 'total': 40.0},
            {'name': 'Product B', 'quantity': 3, 'cost': 10.0, 'total': 30.0},
          ],
        }
      ];

      final ok = await service.exportProcurementsPdf(filePath: path, businessName: 'Test Business', procurements: procurements);
      expect(ok, isTrue);
      final f = File(path);
      expect(await f.exists(), isTrue);
      final len = await f.length();
      expect(len, greaterThan(0));

      // cleanup
      await f.delete();
    });
  });
}
