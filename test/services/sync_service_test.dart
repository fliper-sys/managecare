import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/domain/repositories/sales_repository.dart';
import 'package:business_manager/services/sync_service.dart';

class FakeSalesRepository implements SalesRepository {
  final List<Map<String, dynamic>> pendingSales = [];
  final List<String> syncedIds = [];
  final List<Map<String, dynamic>> syncedPayloads = [];

  @override
  Future<List<Map<String, dynamic>>> getPendingOfflineSales() async =>
      pendingSales;

  @override
  Future<void> syncSaleToFirestore(Map<String, dynamic> saleData) async {
    syncedPayloads.add(Map<String, dynamic>.from(saleData));
  }

  @override
  Future<void> markSaleAsSynced(String saleId) async {
    syncedIds.add(saleId);
  }

  @override
  Future<dynamic> createSale(Map<String, dynamic> saleData) async =>
      throw UnimplementedError();

  @override
  Future<void> updateSale(String saleId, Map<String, dynamic> saleData) async =>
      throw UnimplementedError();

  @override
  Future<String> createSaleOffline(Map<String, dynamic> saleData) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteOfflineSale(String saleId) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteSale(String saleId) async => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> fetchSales({String? businessId, String? storeId}) async =>
      throw UnimplementedError();

  @override
  Future<dynamic> getSaleById(String saleId) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getReceipt(String id) async =>
      throw UnimplementedError();

  @override
  Future<List<dynamic>> getSales(String businessId,
          {Map<String, dynamic>? filters}) async =>
      throw UnimplementedError();

  @override
  Future<void> syncSales() async => throw UnimplementedError();
}

void main() {
  test('syncSales uploads pending sales and marks them synced', () async {
    final repo = FakeSalesRepository();
    repo.pendingSales.add({
      'id': 'sale-1',
      'businessId': 'b1',
      'total': 1200,
      'status': 'completed',
    });

    final service = SyncService(
      salesRepository: repo,
    );
    await service.syncSales();

    expect(repo.syncedPayloads, hasLength(1));
    expect(repo.syncedPayloads.first['id'], 'sale-1');
    expect(repo.syncedIds, ['sale-1']);
  });
}
