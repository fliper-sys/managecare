import '../usecase.dart';

class UpdateStock implements UseCase<void, Map<String, dynamic>> {
  UpdateStock();

  @override
  Future<void> call(Map<String, dynamic> params) async {
    final businessId = params['businessId']?.toString() ?? '';
    final itemId = params['itemId']?.toString() ?? '';
    if (businessId.isEmpty || itemId.isEmpty) {
      throw ArgumentError('businessId and itemId are required');
    }
    if (!params.containsKey('quantityChange') && !params.containsKey('newQuantity')) {
      throw ArgumentError('quantityChange or newQuantity is required');
    }
  }
}

