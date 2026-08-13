import 'package:flutter/foundation.dart';
import '../data/repositories/worker_repository_impl.dart';

class WorkersProvider with ChangeNotifier {
  final WorkerRepositoryImpl _repository;
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = false;
  String? _error;
  String? _businessId;

  WorkersProvider({
    required String businessId,
    WorkerRepositoryImpl? repository,
  }) : _repository = repository ?? WorkerRepositoryImpl() {
    // initial load
    if (businessId.isNotEmpty) {
      loadWorkers(businessId);
    }
  }

  List<Map<String, dynamic>> get workers => _workers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _refreshBusinessScopeAfterMutation(String? businessId) async {
    final targetBusinessId = (businessId ?? _businessId ?? '').trim();
    if (targetBusinessId.isEmpty) return;

    _businessId = targetBusinessId;
    await refreshForBusiness(targetBusinessId);
  }

  Future<void> loadWorkers(String businessId) async {
    _businessId = businessId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await _repository.getWorkers(businessId);
      // ensure a consistent map type
      _workers = list
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _error = 'Failed to load workers: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshForBusiness(String businessId) async {
    await loadWorkers(businessId);
  }

  /// Set business id and refresh workers for that business
  Future<void> setBusinessId(String businessId) async {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    await refreshForBusiness(businessId);
    notifyListeners();
  }

  Map<String, dynamic>? getById(String id) {
    try {
      return _workers.firstWhere(
          (w) => (w['id'] ?? '') == id || (w['employeeId'] ?? '') == id);
    } catch (e) {
      return null;
    }
  }

  /// Update a worker's profile fields (name, phone, role, permissions, pin, ...).
  Future<void> updateWorker(String workerId, Map<String, dynamic> data,
      {String? businessId, List<String>? roles}) async {
    try {
      final targetBusinessId = (businessId ?? _businessId ?? '').trim();
      if (targetBusinessId.isEmpty) {
        throw ArgumentError('businessId is required to update a worker');
      }

      final payload = Map<String, dynamic>.from(data);
      if (roles != null && roles.isNotEmpty) {
        payload['role'] = roles.first;
      }
      payload['businessId'] = targetBusinessId;

      await _repository.updateWorker(workerId, payload);
      await _refreshBusinessScopeAfterMutation(targetBusinessId);
    } catch (e) {
      debugPrint('[WorkersProvider] updateWorker failed: $e');
      rethrow;
    }
  }

  /// Deactivate a worker: keeps the worker record (and their business
  /// membership row) but marks both inactive, so they lose access to the
  /// business while the record stays around for historical/audit reference
  /// (sales, attendance, etc. still reference their id).
  Future<void> removeWorkerFromBusiness(
    String workerId, {
    required String businessId,
  }) async {
    final targetBusinessId = businessId.trim();
    if (targetBusinessId.isEmpty) {
      throw ArgumentError('businessId is required to remove a worker');
    }

    try {
      await _repository.updateWorker(workerId, {
        'businessId': targetBusinessId,
        'isActive': false,
      });
      await _refreshBusinessScopeAfterMutation(targetBusinessId);
    } catch (e) {
      debugPrint('[WorkersProvider] removeWorkerFromBusiness failed: $e');
      rethrow;
    }
  }

  /// Permanently delete a worker record. The backend also deactivates their
  /// business_members row atomically as part of this call
  /// (routes/workers.js), so membership/access checks stop treating them as
  /// part of the business.
  Future<void> deleteWorker(String workerId, {String? businessId}) async {
    final targetBusinessId = (businessId ?? _businessId ?? '').trim();
    if (targetBusinessId.isEmpty) {
      throw ArgumentError('businessId is required to delete a worker');
    }

    try {
      await _repository.deleteWorkerForBusiness(targetBusinessId, workerId);
      await _refreshBusinessScopeAfterMutation(targetBusinessId);
    } catch (e) {
      debugPrint('[WorkersProvider] deleteWorker failed: $e');
      rethrow;
    }
  }
}
