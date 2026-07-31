import '../../services/managecare_api_client.dart';

class AdminRepository {
  AdminRepository({ManagecareApiClient? api})
      : _api = api ?? ManagecareApiClient.instance;

  final ManagecareApiClient _api;

  Map<String, dynamic> _businessRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'] ?? row['business_name'],
      'businessName': row['name'] ?? row['business_name'],
      'ownerName': row['owner_name'],
      'ownerId': row['owner_id'],
      'businessType': row['business_type'],
      'businessClass': row['business_class'],
      'maxWorkers': row['max_workers'],
      'features': row['features'],
      'email': row['email'],
      'phone': row['phone'],
      'address': row['address'],
      'subscriptionTier': row['subscription_tier'],
      'subscriptionPlan': row['subscription_plan'],
      'subscriptionStartDate': row['subscription_start_date'],
      'subscriptionEndDate': row['subscription_end_date'],
      'isSubscriptionActive': row['is_subscription_active'],
      'hasActiveSubscription': row['is_subscription_active'],
      'isActive': row['is_active'],
      'isRestricted': row['is_restricted'],
      'restrictionStatus': row['restriction_status'],
      'restrictionReason': row['restriction_reason'],
      'restrictedAt': row['restricted_at'],
      'restrictedBy': row['restricted_by'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'totalWorkers': row['total_workers'] ?? 0,
    };
  }

  Map<String, dynamic> _userRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['full_name'] ?? row['name'] ?? row['email'],
      'fullName': row['full_name'] ?? row['name'],
      'email': row['email'],
      'phone': row['phone_number'] ?? row['phone'],
      'role': row['role'],
      'type': row['type'],
      'businessId': row['business_id'] ?? row['current_business_id'],
      'currentBusinessId': row['current_business_id'] ?? row['business_id'],
      'businessName': row['business_name'],
      'isWorker': row['is_worker'] ?? row['type'] == 'worker',
      'isActive': row['is_active'],
      'lastActive': row['last_active'],
      'subscriptionTier': row['subscription_tier'],
      'isSubscriptionActive': row['is_subscription_active'],
      'businessRestricted': row['business_restricted'],
      'businessRestrictionReason': row['business_restriction_reason'],
      'tableSource': row['table_source'],
      'tableSources': row['table_sources'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  Map<String, dynamic> _paymentRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'transactionId': row['transaction_id'],
      'businessId': row['business_id'],
      'businessName': row['business_name'],
      'amount': row['amount'],
      'currency': row['currency'] ?? 'NGN',
      'email': row['email'],
      'method': row['method'] ?? row['payment_method'],
      'status': row['status'],
      'businessCategory': row['business_category'] ?? row['business_type'],
      'businessTier': row['business_tier'] ?? row['subscription_tier'],
      'marketerRevenue': row['marketer_revenue'] ?? row['marketer_commission'],
      'processorResponse': row['processor_response'],
      'createdAt': row['created_at'],
    };
  }

  Map<String, dynamic> _internalWorkerRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'email': row['email'],
      'phone': row['phone'],
      'role': row['role'],
      'roleKey': row['role_key'] ?? row['roleKey'],
      'isActive': row['is_active'] ?? row['isActive'],
      'createdAt': row['created_at'] ?? row['createdAt'],
      'updatedAt': row['updated_at'] ?? row['updatedAt'],
    };
  }

  Map<String, dynamic> _workItemRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'assignedTo': row['assigned_to'] ?? row['assignedTo'],
      'type': row['type'],
      'priority': row['priority'],
      'status': row['status'],
      'dueDate': row['due_date'] ?? row['dueDate'],
      'createdAt': row['created_at'] ?? row['createdAt'],
      'updatedAt': row['updated_at'] ?? row['updatedAt'],
    };
  }

  Map<String, dynamic> _companyExpenseRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'title': row['title'],
      'amount': row['amount'],
      'category': row['category'],
      'description': row['description'],
      'expenseDate': row['expense_date'] ?? row['expenseDate'],
      'receiptUrl': row['receipt_url'] ?? row['receiptUrl'],
      'createdAt': row['created_at'] ?? row['createdAt'],
      'updatedAt': row['updated_at'] ?? row['updatedAt'],
    };
  }

  Future<Map<String, dynamic>> fetchDashboard() async {
    final response = await _api.get('/api/admin/dashboard');
    final data = Map<String, dynamic>.from(response as Map);
    return {
      'stats': Map<String, dynamic>.from(data['stats'] as Map? ?? const {}),
      'businesses': ((data['businesses'] as List?) ?? [])
          .map((row) => _businessRow(Map<String, dynamic>.from(row as Map)))
          .toList(),
      'users': ((data['users'] as List?) ?? [])
          .map((row) => _userRow(Map<String, dynamic>.from(row as Map)))
          .toList(),
      'usersCount': data['usersCount'] ?? 0,
      'workersCount': data['workersCount'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _api.get('/api/admin/settings');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _api.put('/api/admin/settings', body: settings);
  }

  Future<void> updateBusiness(
    String businessId,
    Map<String, dynamic> updates,
  ) async {
    await _api.patch('/api/admin/businesses/$businessId', body: updates);
  }

  Future<Map<String, dynamic>> grantBusinessSubscription({
    required String businessId,
    required String businessName,
    required String tier,
    required int durationDays,
    String source = 'admin_manual',
  }) async {
    final response = await _api.post(
      '/api/admin/businesses/$businessId/grant-subscription',
      body: {
        'businessName': businessName,
        'tier': tier,
        'durationDays': durationDays,
        'source': source,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> declineBusinessSubscription({
    required String businessId,
    String? reason,
  }) async {
    final response = await _api.post(
      '/api/admin/businesses/$businessId/decline-subscription',
      body: {if (reason != null) 'reason': reason},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> setBusinessRestriction({
    required String businessId,
    required bool restricted,
    String? reason,
  }) async {
    await _api.post('/api/admin/businesses/$businessId/restriction', body: {
      'restricted': restricted,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> fetchPayments({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _api.get('/api/admin/payments', query: {
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    });
    return ((response['data'] as List?) ?? [])
        .map((row) => _paymentRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchSubscriptionRequests() async {
    final response = await _api.get('/api/admin/subscription-requests');
    return ((response['data'] as List?) ?? [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> approveSubscriptionRequest(
    String requestId, {
    required int durationDays,
  }) {
    return _api.post(
      '/api/admin/subscription-requests/$requestId/approve',
      body: {'durationDays': durationDays},
    );
  }

  Future<void> declineSubscriptionRequest(
    String requestId, {
    String? reason,
  }) {
    return _api.post(
      '/api/admin/subscription-requests/$requestId/decline',
      body: {if (reason != null) 'reason': reason},
    );
  }

  Future<void> approvePaymentTransaction(
    String transactionRowId, {
    required String planId,
    String? planTier,
    required int durationDays,
  }) {
    return _api.post(
      '/api/admin/payment-transactions/$transactionRowId/approve',
      body: {'planId': planId, 'planTier': planTier, 'durationDays': durationDays},
    );
  }

  Future<void> declinePaymentTransaction(
    String transactionRowId, {
    String? reason,
  }) {
    return _api.post(
      '/api/admin/payment-transactions/$transactionRowId/decline',
      body: {if (reason != null) 'reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> fetchSubscriptionHistory(
    String businessId,
  ) async {
    final response = await _api.get('/api/admin/businesses/$businessId/subscriptions');
    return ((response['data'] as List?) ?? [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchInternalWorkers() async {
    final response = await _api.get('/api/admin/internal-workers');
    return ((response['data'] as List?) ?? [])
        .map((row) => _internalWorkerRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> saveInternalWorker(Map<String, dynamic> worker, {String? id}) {
    if (id == null || id.isEmpty) {
      return _api.post('/api/admin/internal-workers', body: worker);
    }
    return _api.put('/api/admin/internal-workers/$id', body: worker);
  }

  Future<List<Map<String, dynamic>>> fetchWorkItems() async {
    final response = await _api.get('/api/admin/work-items');
    return ((response['data'] as List?) ?? [])
        .map((row) => _workItemRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> createWorkItem(Map<String, dynamic> item) {
    return _api.post('/api/admin/work-items', body: item);
  }

  Future<void> updateWorkItemStatus(String id, String status) {
    return _api.patch('/api/admin/work-items/$id', body: {'status': status});
  }

  Future<List<Map<String, dynamic>>> fetchCompanyExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _api.get('/api/admin/company-expenses', query: {
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    });
    return ((response['data'] as List?) ?? [])
        .map((row) => _companyExpenseRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> createCompanyExpense(Map<String, dynamic> expense) {
    return _api.post('/api/admin/company-expenses', body: expense);
  }

  Future<Map<String, dynamic>?> getBusiness(String businessId) async {
    final response = await _api.get('/api/admin/businesses/$businessId');
    if (response == null) return null;
    return _businessRow(Map<String, dynamic>.from(response as Map));
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    final response = await _api.get('/api/admin/users/$userId');
    if (response == null) return null;
    return _userRow(Map<String, dynamic>.from(response as Map));
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) {
    return _api.patch('/api/admin/users/$userId', body: updates);
  }

  Future<void> removeMemberFromBusiness({
    required String userId,
    required String businessId,
  }) {
    return _api.post(
      '/api/admin/businesses/$businessId/members/$userId/remove',
    );
  }

  Future<Map<String, dynamic>> getDailySalesSummary(
    String businessId,
    DateTime date,
  ) async {
    final response = await _api.get(
      '/api/admin/businesses/$businessId/daily-sales',
      query: {'date': date.toIso8601String()},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> softDeleteBusiness(String businessId, {String? reason}) async {
    final response = await _api.post(
      '/api/admin/businesses/$businessId/delete',
      body: {if (reason != null) 'reason': reason},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> restoreBusiness(String businessId) async {
    final response = await _api.post('/api/admin/businesses/$businessId/restore');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> softDeleteUser(String userId, {String? reason}) async {
    final response = await _api.post(
      '/api/admin/users/$userId/delete',
      body: {if (reason != null) 'reason': reason},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> restoreUser(String userId) async {
    final response = await _api.post('/api/admin/users/$userId/restore');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> grantWorkerSubscription(String workerId) {
    return _api.post('/api/admin/workers/$workerId/subscription');
  }

  Future<void> grantWorkersSubscription(String businessId) {
    return _api.post('/api/admin/businesses/$businessId/workers/subscription');
  }

  Future<int> broadcastNotification({
    required String title,
    required String body,
    required List<String> userIds,
    String type = 'general',
  }) async {
    final response = await _api.post('/api/admin/notifications/broadcast', body: {
      'title': title,
      'body': body,
      'userIds': userIds,
      'type': type,
    });
    return (response['count'] as num?)?.toInt() ?? 0;
  }

  Future<String> createEmailLog({
    required String subject,
    required String body,
    required List<String> recipients,
  }) async {
    final response = await _api.post('/api/admin/emails', body: {
      'subject': subject,
      'body': body,
      'recipients': recipients,
    });
    return Map<String, dynamic>.from(response as Map)['id'].toString();
  }

  Future<void> completeEmailLog(
    String emailLogId, {
    required String status,
    required int sentCount,
    required int failedCount,
    required List<String> failedRecipients,
  }) {
    return _api.patch('/api/admin/emails/$emailLogId', body: {
      'status': status,
      'sentCount': sentCount,
      'failedCount': failedCount,
      'failedRecipients': failedRecipients,
    });
  }
}
