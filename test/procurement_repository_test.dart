import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/data/repositories/procurement_repository.dart';

void main() {
  group('ProcurementRepository bakery metadata', () {
    test('builds bakery metadata for baker and sales rep assignments', () {
      final repository = ProcurementRepository();
      final metadata = repository.buildBakeryProcurementMetadata(
        bakerId: 'baker-1',
        bakerName: 'Ada',
        salesRepId: 'rep-1',
        salesRepName: 'Ben',
      );

      expect(metadata['sourceType'], 'bakery');
      expect(metadata['bakerId'], 'baker-1');
      expect(metadata['bakerName'], 'Ada');
      expect(metadata['salesRepId'], 'rep-1');
      expect(metadata['salesRepName'], 'Ben');
    });

    test('omits empty bakery metadata values', () {
      final repository = ProcurementRepository();
      final metadata = repository.buildBakeryProcurementMetadata();

      expect(metadata, isEmpty);
    });
  });
}
