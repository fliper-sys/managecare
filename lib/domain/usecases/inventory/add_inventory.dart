import '../usecase.dart';

class AddInventory implements UseCase<void, Map<String, dynamic>> {
  AddInventory();

  @override
  Future<void> call(Map<String, dynamic> params) async {
    // TODO: add inventory item using repository
  }
}

