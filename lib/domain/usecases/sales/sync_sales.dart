import '../usecase.dart';

class SyncSales implements UseCase<void, void> {
  SyncSales();

  @override
  Future<void> call(void params) async {
    // TODO: implement sync logic between local DB and remote
  }
}

