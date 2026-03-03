import '../usecase.dart';
import '../../repositories/sales_repository.dart';

class CreateSale implements UseCase<dynamic, Map<String, dynamic>> {
  final SalesRepository repository;

  CreateSale({required this.repository});

  @override
  Future<dynamic> call(Map<String, dynamic> params) async {
    // Delegate to repository - repository handles Firestore/local persistence
    return await repository.createSale(params);
  }
}

