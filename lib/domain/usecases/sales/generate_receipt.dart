import '../usecase.dart';

class GenerateReceipt
    implements UseCase<Map<String, dynamic>, Map<String, dynamic>> {
  GenerateReceipt();

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
    // TODO: build receipt payload/string/pdf and return identifier/path
    return {'receiptId': '', 'path': ''};
  }
}

