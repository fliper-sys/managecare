import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/administrative_repository_supabase.dart';

enum AdministrativeTaskStatus { assigned, inProgress, submitted, approved, rejected }

enum AdministrativeCountdownType { fixedDate, trailing }

class AdministrativeClientRecord {
  const AdministrativeClientRecord({
    required this.id,
    required this.name,
    required this.companyName,
    required this.location,
    required this.isActive,
    this.workerCount = 0,
    this.documentCount = 0,
    this.openTaskCount = 0,
  });

  final String id;
  final String name;
  final String companyName;
  final String location;
  final bool isActive;
  final int workerCount;
  final int documentCount;
  final int openTaskCount;
}

class AdministrativeTask {
  AdministrativeTask({
    required this.id,
    required this.title,
    required this.clientName,
    required this.assignedTo,
    required this.dueAt,
    this.clientId,
    this.assignedWorkerId,
    this.documentName,
    this.note,
    this.status = AdministrativeTaskStatus.assigned,
    this.submittedFileName,
    this.reviewStorageAction,
  });

  final String id;
  final String title;
  final String clientName;
  final String assignedTo;
  final DateTime dueAt;
  final String? clientId;
  final String? assignedWorkerId;
  final String? documentName;
  final String? note;
  AdministrativeTaskStatus status;
  String? submittedFileName;
  String? reviewStorageAction;

  bool get needsReview => status == AdministrativeTaskStatus.submitted;
  bool get isOpen => status == AdministrativeTaskStatus.assigned || status == AdministrativeTaskStatus.inProgress;
}

class AdministrativeObligation {
  AdministrativeObligation({
    required this.id,
    required this.title,
    required this.clientName,
    required this.countdownType,
    required this.intervalDays,
    required this.dueAt,
    this.clientId,
    this.assignedWorkerId,
    this.fixedDayOfMonth,
    this.completedAt,
  });

  final String id;
  final String title;
  final String clientName;
  final AdministrativeCountdownType countdownType;
  final int intervalDays;
  final int? fixedDayOfMonth;
  DateTime dueAt;
  final String? clientId;
  final String? assignedWorkerId;
  DateTime? completedAt;

  bool get isCompleted => completedAt != null;
}

class AdministrativeProvider extends ChangeNotifier {
  AdministrativeProvider({AdministrativeRepositorySupabase? repository})
      : _repository = repository,
        _tasks = [
          AdministrativeTask(
            id: 'care-plan-review',
            title: 'Review Care Plan',
            clientName: 'Mary Johnson',
            assignedTo: 'Sarah Daniels',
            dueAt: DateTime.now().add(const Duration(hours: 5)),
            documentName: 'Care Plan v2.1.pdf',
            note: 'Please review and update the uploaded care plan.',
          ),
          AdministrativeTask(
            id: 'client-tax',
            title: 'Client Tax',
            clientName: 'Doe-Son',
            assignedTo: 'Sarah Daniels',
            dueAt: DateTime.now().add(const Duration(days: 1)),
          ),
          AdministrativeTask(
            id: 'office-cleaning',
            title: 'Office Cleaning',
            clientName: 'Head Office',
            assignedTo: 'Sarah Daniels',
            dueAt: DateTime.now().add(const Duration(hours: 2)),
            status: AdministrativeTaskStatus.inProgress,
          ),
        ],
        _obligations = [
          AdministrativeObligation(
            id: 'training-certificate',
            title: 'Training Certificate',
            clientName: 'Care Home',
            countdownType: AdministrativeCountdownType.fixedDate,
            intervalDays: 30,
            fixedDayOfMonth: DateTime.now().day,
            dueAt: DateTime.now().add(const Duration(days: 7)),
          ),
          AdministrativeObligation(
            id: 'medical-assessment',
            title: 'Medical Assessment',
            clientName: 'Smith Home',
            countdownType: AdministrativeCountdownType.trailing,
            intervalDays: 30,
            dueAt: DateTime.now().add(const Duration(days: 4)),
          ),
          AdministrativeObligation(
            id: 'vat-filing',
            title: 'VAT Filing',
            clientName: 'Doe-Son',
            countdownType: AdministrativeCountdownType.fixedDate,
            intervalDays: 30,
            fixedDayOfMonth: 27,
            dueAt: DateTime.now().add(const Duration(days: 12)),
          ),
        ],
        _clients = const [
          AdministrativeClientRecord(id: 'preview-mary', name: 'Mary Johnson', companyName: 'Care For Homes', location: 'Ikeja', isActive: true),
          AdministrativeClientRecord(id: 'preview-jala', name: 'Jala Smith', companyName: 'Response High', location: 'Ikeja', isActive: true),
        ];

  final List<AdministrativeTask> _tasks;
  final List<AdministrativeObligation> _obligations;
  final List<AdministrativeClientRecord> _clients;
  AdministrativeRepositorySupabase? _repository;
  String? _loadedBusinessId;
  bool _isLoading = false;
  String? _loadError;

  List<AdministrativeTask> get tasks => List.unmodifiable(_tasks);
  List<AdministrativeObligation> get obligations => List.unmodifiable(_obligations);
  List<AdministrativeClientRecord> get clients => List.unmodifiable(_clients);
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  Future<List<Map<String, dynamic>>> loadCalendar(
    DateTime from,
    DateTime to,
  ) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase()).getCalendar(
      businessId,
      from: from,
      to: to,
    );
  }

  Future<List<Map<String, dynamic>>> loadFolders(String clientId) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase())
        .getFolders(businessId, clientId);
  }

  Future<List<Map<String, dynamic>>> loadDocuments(
    String clientId, {
    String? query,
    String? folderId,
    String? mimeType,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase()).getDocuments(
      businessId,
      clientId,
      query: query,
      folderId: folderId,
      mimeType: mimeType,
    );
  }

  Future<Map<String, dynamic>> createFolder(String clientId, String name) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    return (_repository ??= AdministrativeRepositorySupabase())
        .createFolder(businessId, clientId, name.trim());
  }

  Future<Map<String, dynamic>> uploadDocument({
    required String clientId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    String? folderId,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    final repository = _repository ??= AdministrativeRepositorySupabase();
    final uploaded = await repository.uploadFile(
      businessId,
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      mimeType: mimeType,
    );
    return repository.createDocument(businessId, clientId, {
      'file_name': uploaded['originalName'] ?? fileName,
      'file_url': uploaded['url'],
      'file_size_bytes': uploaded['size'] ?? bytes.length,
      'mime_type': uploaded['mimetype'] ?? mimeType,
      if (folderId != null) 'folder_id': folderId,
    });
  }

  Future<List<Map<String, dynamic>>> loadDocumentVersions(
    String documentId,
  ) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase())
        .getDocumentVersions(businessId, documentId);
  }

  Future<Map<String, dynamic>> downloadDocument(String documentId) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    return (_repository ??= AdministrativeRepositorySupabase())
        .getDocumentDownload(businessId, documentId);
  }

  Future<void> approveDocumentVersion({
    required String documentId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    required String action,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    final repository = _repository ??= AdministrativeRepositorySupabase();
    final uploaded = await repository.uploadFile(
      businessId,
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      mimeType: mimeType,
    );
    await repository.createDocumentVersion(businessId, documentId, {
      'file_name': uploaded['originalName'] ?? fileName,
      'file_url': uploaded['url'],
      'file_size_bytes': uploaded['size'] ?? bytes.length,
      'mime_type': uploaded['mimetype'] ?? mimeType,
      'action': action,
    });
  }

  Future<List<Map<String, dynamic>>> loadStaffing() async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase())
        .getStaffing(businessId);
  }

  Future<void> setWorkerClientAssignment({
    required String workerId,
    required String clientId,
    required bool assigned,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    final repository = _repository ??= AdministrativeRepositorySupabase();
    if (assigned) {
      await repository.assignWorkerToClient(businessId, clientId, workerId);
    } else {
      await repository.unassignWorkerFromClient(businessId, clientId, workerId);
    }
  }

  Future<List<Map<String, dynamic>>> loadActivity() async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase())
        .getActivity(businessId);
  }

  Future<List<Map<String, dynamic>>> loadFinancialEntries({
    String? type,
    String? clientId,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase())
        .getFinancialEntries(businessId, type: type, clientId: clientId);
  }

  Future<List<Map<String, dynamic>>> loadInvoices() async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase())
        .getInvoices(businessId);
  }

  Future<List<Map<String, dynamic>>> loadTasksForClient(String clientId) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase())
        .getTasksForClient(businessId, clientId);
  }

  Future<List<Map<String, dynamic>>> loadTaskComments(String taskId) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return const [];
    return (_repository ??= AdministrativeRepositorySupabase())
        .getTaskComments(businessId, taskId);
  }

  Future<void> addTaskComment(String taskId, String body) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    await (_repository ??= AdministrativeRepositorySupabase())
        .addTaskComment(businessId, taskId, body.trim());
  }

  Future<Map<String, dynamic>> createLiveTask({
    required String title,
    required String clientId,
    String? documentId,
    String? workerId,
    String? remark,
    String priority = 'normal',
    DateTime? dueAt,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    final json = await (_repository ??= AdministrativeRepositorySupabase())
        .createTask(businessId, {
      'title': title.trim(),
      'client_id': clientId,
      if (documentId != null) 'document_id': documentId,
      if (workerId != null) 'assigned_to': workerId,
      if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
      'priority': priority,
      if (dueAt != null) 'due_at': dueAt.toIso8601String(),
    });
    return json;
  }

  Future<Map<String, dynamic>> loadInvoice(String invoiceId) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    return (_repository ??= AdministrativeRepositorySupabase())
        .getInvoice(businessId, invoiceId);
  }

  Future<void> emailInvoice(String invoiceId, String email) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    await (_repository ??= AdministrativeRepositorySupabase())
        .emailInvoice(businessId, invoiceId, email);
  }

  Future<void> createCalendarEvent({
    required String title,
    required DateTime startsAt,
    String? description,
    String? clientId,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    await (_repository ??= AdministrativeRepositorySupabase()).createCalendarEvent(
      businessId,
      {
        'title': title.trim(),
        'starts_at': startsAt.toIso8601String(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (clientId != null) 'client_id': clientId,
      },
    );
  }

  Future<AdministrativeClientRecord> createClient({
    required String name,
    String? companyName,
    String? location,
    String? contactAddress,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) {
      throw StateError('Select an administrative business before creating a client.');
    }
    final json = await (_repository ??= AdministrativeRepositorySupabase())
        .createClient(businessId, {
      'name': name.trim(),
      if (companyName != null && companyName.trim().isNotEmpty)
        'company_name': companyName.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (contactAddress != null && contactAddress.trim().isNotEmpty)
        'contact_address': contactAddress.trim(),
    });
    final client = _clientFromJson(json);
    _clients.insert(0, client);
    notifyListeners();
    return client;
  }

  Future<AdministrativeClientRecord> updateClient(
    String clientId, {
    required String name,
    String? companyName,
    String? location,
    String? contactAddress,
    bool? isActive,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) {
      throw StateError('Select an administrative business before updating a client.');
    }
    if (clientId.startsWith('preview-')) {
      throw StateError('Preview client records cannot be changed.');
    }
    final json = await (_repository ??= AdministrativeRepositorySupabase())
        .updateClient(businessId, clientId, {
      'name': name.trim(),
      'company_name': companyName?.trim() ?? '',
      'location': location?.trim() ?? '',
      if (contactAddress != null) 'contact_address': contactAddress.trim(),
      if (isActive != null) 'is_active': isActive,
    });
    final client = _clientFromJson(json);
    final index = _clients.indexWhere((item) => item.id == clientId);
    if (index >= 0) _clients[index] = client;
    notifyListeners();
    return client;
  }

  Future<void> archiveClient(String clientId) async {
    await updateClient(clientId, name: _clientName(clientId), isActive: false);
    _clients.removeWhere((client) => client.id == clientId);
    notifyListeners();
  }

  Future<void> restoreClient(String clientId) async {
    await updateClient(clientId, name: _clientName(clientId), isActive: true);
  }

  Future<void> loadClients({bool active = true}) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final records = await (_repository ??= AdministrativeRepositorySupabase())
          .getClients(businessId, active: active);
      _clients
        ..clear()
        ..addAll(records.map(_clientFromJson));
    } catch (_) {
      _loadError = 'Unable to load clients.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _clientName(String clientId) {
    for (final client in _clients) {
      if (client.id == clientId) return client.name;
    }
    throw StateError('Client record is no longer available.');
  }

  Future<Map<String, dynamic>> createInvoice({
    required String clientId,
    required String invoiceNumber,
    required String description,
    required double quantity,
    required double unitPrice,
    double taxAmount = 0,
    String? dueDate,
    String? notes,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) {
      throw StateError('Select an administrative business before creating an invoice.');
    }
    return (_repository ??= AdministrativeRepositorySupabase()).createInvoice(
      businessId,
      {
        'client_id': clientId,
        'invoice_number': invoiceNumber.trim(),
        'items': [
          {
            'description': description.trim(),
            'quantity': quantity,
            'unit_price': unitPrice,
          },
        ],
        'tax_amount': taxAmount,
        if (dueDate != null) 'due_date': dueDate,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<void> sendInvoice(String invoiceId) => _invoiceAction(
        invoiceId,
        (repository, businessId) => repository.sendInvoice(businessId, invoiceId),
      );

  Future<void> voidInvoice(String invoiceId) => _invoiceAction(
        invoiceId,
        (repository, businessId) => repository.voidInvoice(businessId, invoiceId),
      );

  Future<void> recordInvoicePayment(String invoiceId, double amount) =>
      _invoiceAction(
        invoiceId,
        (repository, businessId) =>
            repository.recordInvoicePayment(businessId, invoiceId, amount),
      );

  Future<void> createFinancialEntry({
    required String entryType,
    required double amount,
    required String description,
    String? clientId,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    await (_repository ??= AdministrativeRepositorySupabase())
        .createFinancialEntry(businessId, {
      'entry_type': entryType,
      'amount': amount,
      'description': description.trim(),
      if (clientId != null) 'client_id': clientId,
    });
  }

  Future<void> updateFinancialEntry({
    required String entryId,
    required String entryType,
    required double amount,
    required String description,
    String? clientId,
  }) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    await (_repository ??= AdministrativeRepositorySupabase())
        .updateFinancialEntry(businessId, entryId, {
      'entry_type': entryType,
      'amount': amount,
      'description': description.trim(),
      'client_id': clientId,
    });
  }

  Future<void> _invoiceAction(
    String invoiceId,
    Future<void> Function(AdministrativeRepositorySupabase, String) action,
  ) async {
    final businessId = _loadedBusinessId;
    if (businessId == null) throw StateError('Select an administrative business first.');
    await action(_repository ??= AdministrativeRepositorySupabase(), businessId);
  }

  Future<void> loadForBusiness(String businessId) async {
    if (businessId.isEmpty || _loadedBusinessId == businessId || _isLoading) {
      return;
    }
    _loadedBusinessId = businessId;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        (_repository ??= AdministrativeRepositorySupabase()).getTasks(businessId),
        (_repository ??= AdministrativeRepositorySupabase())
            .getObligations(businessId),
        (_repository ??= AdministrativeRepositorySupabase()).getClients(businessId),
      ]);
      _tasks
        ..clear()
        ..addAll(results[0].map(_taskFromJson));
      _obligations
        ..clear()
        ..addAll(results[1].map(_obligationFromJson));
      _clients
        ..clear()
        ..addAll(results[2].map(_clientFromJson));
    } catch (_) {
      _loadError = 'Unable to load administrative workspace data.';
      _loadedBusinessId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<AdministrativeTask> tasksForWorker(String worker) =>
      _tasks.where((task) => task.assignedTo == worker).toList();

  AdministrativeTask? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  void assignDocument({
    required String documentName,
    required String clientName,
    required String assignedTo,
    required String note,
    DateTime? dueAt,
  }) {
    _tasks.insert(
      0,
      AdministrativeTask(
        id: 'task-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Review $documentName',
        clientName: clientName,
        assignedTo: assignedTo,
        dueAt: dueAt ?? DateTime.now().add(const Duration(days: 1)),
        documentName: documentName,
        note: note.trim().isEmpty ? null : note.trim(),
      ),
    );
    notifyListeners();
  }

  void createTask({
    required String title,
    required String clientName,
    required String assignedTo,
    required DateTime dueAt,
  }) {
    _tasks.insert(
      0,
      AdministrativeTask(
        id: 'task-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        clientName: clientName,
        assignedTo: assignedTo,
        dueAt: dueAt,
      ),
    );
    notifyListeners();
  }

  void startTask(String taskId) {
    final task = taskById(taskId);
    if (task == null || task.status != AdministrativeTaskStatus.assigned) return;
    task.status = AdministrativeTaskStatus.inProgress;
    _persistTaskStatus(task, 'in_progress');
    notifyListeners();
  }

  void submitTask(String taskId, String fileName) {
    final task = taskById(taskId);
    if (task == null || !task.isOpen) return;
    task.status = AdministrativeTaskStatus.submitted;
    task.submittedFileName = fileName;
    _persistTaskStatus(task, 'submitted');
    notifyListeners();
  }

  void reviewTask(String taskId, {required bool approved, String? storageAction}) {
    final task = taskById(taskId);
    if (task == null || !task.needsReview) return;
    task.status = approved ? AdministrativeTaskStatus.approved : AdministrativeTaskStatus.rejected;
    task.reviewStorageAction = storageAction;
    _persistTaskStatus(
      task,
      approved ? 'approved' : 'rejected',
      reviewAction: storageAction,
    );
    notifyListeners();
  }

  void createObligation({
    required String title,
    required String clientName,
    required AdministrativeCountdownType countdownType,
    required int intervalDays,
    int? fixedDayOfMonth,
  }) {
    final now = DateTime.now();
    final dueAt = countdownType == AdministrativeCountdownType.fixedDate
        ? _nextFixedDueDate(now, fixedDayOfMonth ?? now.day)
        : now.add(Duration(days: intervalDays));
    _obligations.insert(
      0,
      AdministrativeObligation(
        id: 'obligation-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        clientName: clientName,
        countdownType: countdownType,
        intervalDays: intervalDays,
        fixedDayOfMonth: fixedDayOfMonth,
        dueAt: dueAt,
      ),
    );
    notifyListeners();
  }

  void completeObligation(String obligationId) {
    AdministrativeObligation? obligation;
    for (final item in _obligations) {
      if (item.id == obligationId) {
        obligation = item;
        break;
      }
    }
    if (obligation == null || obligation.isCompleted) return;
    final now = DateTime.now();
    obligation.completedAt = now;
    obligation.dueAt = obligation.countdownType == AdministrativeCountdownType.fixedDate
        ? _nextFixedDueDate(now, obligation.fixedDayOfMonth ?? now.day)
        : now.add(Duration(days: obligation.intervalDays));
    _persistObligationCompletion(obligation);
    notifyListeners();
  }

  DateTime _nextFixedDueDate(DateTime from, int day) {
    final validDay = day.clamp(1, 28).toInt();
    var candidate = DateTime(from.year, from.month, validDay);
    if (!candidate.isAfter(from)) candidate = DateTime(from.year, from.month + 1, validDay);
    return candidate;
  }

  AdministrativeTask _taskFromJson(Map<String, dynamic> json) =>
      AdministrativeTask(
        id: json['id'].toString(),
        title: json['title']?.toString() ?? 'Untitled task',
        clientName: json['client_name']?.toString() ?? 'Unassigned client',
        assignedTo:
            json['assigned_worker_name']?.toString() ?? 'Unassigned worker',
        dueAt: DateTime.tryParse(json['due_at']?.toString() ?? '') ??
            DateTime.now(),
        clientId: json['client_id']?.toString(),
        assignedWorkerId: json['assigned_to']?.toString(),
        documentName: json['document_name']?.toString(),
        note: json['remark']?.toString(),
        status: _taskStatus(json['status']?.toString()),
      );

  AdministrativeObligation _obligationFromJson(Map<String, dynamic> json) =>
      AdministrativeObligation(
        id: json['id'].toString(),
        title: json['title']?.toString() ?? 'Untitled obligation',
        clientName: json['client_name']?.toString() ?? 'Unassigned client',
        clientId: json['client_id']?.toString(),
        assignedWorkerId: json['assigned_to']?.toString(),
        countdownType: json['recurrence_type'] == 'trailing'
            ? AdministrativeCountdownType.trailing
            : AdministrativeCountdownType.fixedDate,
        intervalDays: (json['interval_days'] as num?)?.toInt() ?? 30,
        fixedDayOfMonth: (json['fixed_day_of_month'] as num?)?.toInt(),
        dueAt: DateTime.tryParse(json['next_due_at']?.toString() ?? '') ??
            DateTime.now(),
        completedAt:
            DateTime.tryParse(json['last_completed_at']?.toString() ?? ''),
      );

  AdministrativeTaskStatus _taskStatus(String? status) => switch (status) {
        'in_progress' => AdministrativeTaskStatus.inProgress,
        'submitted' => AdministrativeTaskStatus.submitted,
        'approved' => AdministrativeTaskStatus.approved,
        'rejected' => AdministrativeTaskStatus.rejected,
        _ => AdministrativeTaskStatus.assigned,
      };

  AdministrativeClientRecord _clientFromJson(Map<String, dynamic> json) =>
      AdministrativeClientRecord(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? 'Unnamed client',
        companyName: json['company_name']?.toString() ?? '',
        location: json['location']?.toString() ?? '',
        isActive: json['is_active'] != false,
        workerCount: (json['worker_count'] as num?)?.toInt() ?? 0,
        documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
        openTaskCount: (json['open_task_count'] as num?)?.toInt() ?? 0,
      );

  void _persistTaskStatus(
    AdministrativeTask task,
    String status, {
    String? reviewAction,
  }) {
    final businessId = _loadedBusinessId;
    if (businessId == null || task.id.startsWith('task-')) return;
    unawaited(
      (_repository ??= AdministrativeRepositorySupabase())
          .updateTaskStatus(businessId, task.id,
              status: status, reviewAction: reviewAction)
          .catchError((_) => _recordSyncError()),
    );
  }

  void _persistObligationCompletion(AdministrativeObligation obligation) {
    final businessId = _loadedBusinessId;
    if (businessId == null || obligation.id.startsWith('obligation-')) return;
    unawaited(
      (_repository ??= AdministrativeRepositorySupabase())
          .completeObligation(businessId, obligation.id)
          .catchError((_) => _recordSyncError()),
    );
  }

  void _recordSyncError() {
    _loadError = 'A status update could not be saved. Please try again.';
    notifyListeners();
  }
}
