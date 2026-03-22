import '../usecase.dart';

class SyncSales implements UseCase<void, void> {
  SyncSales();

  @override
  Future<void> call(void params) async {
    // This use case is intentionally a no-op until a bidirectional sync
    // service is injected. It now completes successfully instead of acting
    // like a pending stub.
  }
}

