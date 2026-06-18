import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/domain/repositories/sales_repository.dart';
import 'package:business_manager/services/offline_sales_service.dart';

class FakeSalesRepository implements SalesRepository {
  Map<String, dynamic>? lastOnlineSale;
  Map<String, dynamic>? lastOfflineSale;
  final List<Map<String, dynamic>> pendingSales = [];

  @override
  Future<dynamic> createSale(Map<String, dynamic> saleData) async {
    lastOnlineSale = Map<String, dynamic>.from(saleData);
    return {'id': 'remote-1', ...saleData};
  }

  @override
  Future<String> createSaleOffline(Map<String, dynamic> saleData) async {
    lastOfflineSale = Map<String, dynamic>.from(saleData);
    pendingSales.add({'id': 'local-1', ...saleData});
    return 'local-1';
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingOfflineSales() async {
    return pendingSales;
  }

  @override
  Future<void> markSaleAsSynced(String saleId) async {}

  @override
  Future<void> updateSale(String saleId, Map<String, dynamic> saleData) async {}

  @override
  Future<void> syncSaleToFirestore(Map<String, dynamic> saleData) async {}

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
  test('creates sale offline when connectivity is lost', () async {
    final repo = FakeSalesRepository();
    final service = OfflineSalesService(
      salesRepository: repo,
      connectivityChecker: () async => false,
    );

    final result = await service.createSale({
      'businessId': 'b1',
      'total': 2500,
      'items': [
        {'productId': 'p1', 'quantity': 1, 'price': 2500}
      ],
    });

    expect(result['success'], true);
    expect(result['mode'], 'offline');
    expect(repo.lastOfflineSale, isNotNull);
    expect(repo.lastOnlineSale, isNull);
    expect(repo.pendingSales, hasLength(1));
    expect(result['data']['id'], 'local-1');
  });

  test('creates sale online when connectivity is available', () async {
    final repo = FakeSalesRepository();
    final service = OfflineSalesService(
      salesRepository: repo,
      connectivityChecker: () async => true,
    );

    final result = await service.createSale({
      'businessId': 'b1',
      'total': 2500,
      'items': [
        {'productId': 'p1', 'quantity': 1, 'price': 2500}
      ],
    });

    expect(result['success'], true);
    expect(result['mode'], 'online');
    expect(repo.lastOnlineSale, isNotNull);
    expect(repo.lastOfflineSale, isNull);
  });
}
