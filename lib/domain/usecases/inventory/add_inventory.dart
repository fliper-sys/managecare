import '../usecase.dart';

class AddInventory implements UseCase<void, Map<String, dynamic>> {
  AddInventory();

  @override
  Future<void> call(Map<String, dynamic> params) async {
    final businessId = params['businessId']?.toString() ?? '';
    final itemId = params['itemId']?.toString() ?? '';
    final quantity = (params['quantity'] as num?)?.toInt() ?? 0;
    if (businessId.isEmpty || itemId.isEmpty) {
      throw ArgumentError('businessId and itemId are required');
    }
    if (quantity < 0) {
      throw ArgumentError('quantity cannot be negative');
    }
  }
}

