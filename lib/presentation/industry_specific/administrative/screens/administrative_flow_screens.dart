import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../providers/administrative_provider.dart';

class AdministrativeClientProfileScreen extends StatefulWidget {
  const AdministrativeClientProfileScreen({
    super.key,
    this.clientId,
    required this.clientName,
    required this.companyName,
    required this.location,
  });

  final String clientName;
  final String? clientId;
  final String companyName;
  final String location;

  @override
  State<AdministrativeClientProfileScreen> createState() =>
      _AdministrativeClientProfileScreenState();
}

class _AdministrativeClientProfileScreenState
    extends State<AdministrativeClientProfileScreen> {
  late Future<Map<String, dynamic>> _details;

  @override
  void initState() {
    super.initState();
    _details = _loadDetails();
  }

  Future<Map<String, dynamic>> _loadDetails() {
    final clientId = widget.clientId;
    if (clientId == null) return Future.value(const {});
    return context.read<AdministrativeProvider>().loadClientDetails(clientId);
  }

  Future<void> _editClient(Map<String, dynamic> client) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AdministrativeEditClientScreen(
        clientId: widget.clientId!,
        name: client['name']?.toString() ?? widget.clientName,
        companyName: (client['companyName'] ?? client['company_name'])?.toString() ?? widget.companyName,
        location: client['location']?.toString() ?? widget.location,
        contactAddress: (client['contactAddress'] ?? client['contact_address'])?.toString() ?? '',
      ),
    ));
    if (changed == true && mounted) setState(() => _details = _loadDetails());
  }

  Future<void> _manageAssignments(Map<String, dynamic> client) async {
    final clientId = widget.clientId;
    if (clientId == null) return;
    try {
      final provider = context.read<AdministrativeProvider>();
      final staffing = await provider.loadStaffing();
      if (!mounted) return;
      final assigned = ((client['workers'] as List?) ?? const [])
          .whereType<Map>()
          .map((worker) => worker['workerId']?.toString())
          .whereType<String>()
          .toSet();
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Assign workers to this client')),
                if (staffing.isEmpty)
                  const ListTile(title: Text('No staff records found.')),
                ...staffing.map((worker) {
                  final id = worker['id']?.toString() ?? '';
                  if (id.isEmpty || worker['is_active'] == false) {
                    return const SizedBox.shrink();
                  }
                  return CheckboxListTile(
                    value: assigned.contains(id),
                    title: Text(worker['full_name']?.toString() ?? 'Worker'),
                    subtitle: Text(worker['role']?.toString() ?? 'Staff'),
                    onChanged: (value) async {
                      try {
                        await provider.setWorkerClientAssignment(
                          workerId: id,
                          clientId: clientId,
                          assigned: value == true,
                        );
                        setSheetState(() {
                          if (value == true) {
                            assigned.add(id);
                          } else {
                            assigned.remove(id);
                          }
                        });
                      } catch (error) {
                        if (context.mounted) {
                          _message(context, 'Unable to update assignment: $error');
                        }
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      );
      if (mounted) setState(() => _details = _loadDetails());
    } catch (error) {
      if (mounted) _message(context, 'Unable to load staff assignments: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().currentUser?.role.toLowerCase();
    final canManageClient = ['owner', 'admin', 'sub_admin'].contains(role);
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Client Profile'),
          actions: [
            if (canManageClient)
              IconButton(
                tooltip: 'Edit client',
                onPressed: widget.clientId == null
                    ? null
                    : () async {
                        final client = await _details;
                        if (mounted) await _editClient(client);
                      },
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Documents'),
              Tab(text: 'Obligations'),
              Tab(text: 'Tasks'),
              Tab(text: 'Expenses'),
              Tab(text: 'Revenue'),
              Tab(text: 'Activity'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: _details,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _LoadError(onRetry: () => setState(() => _details = _loadDetails()));
                    }
                    final client = snapshot.data ?? const <String, dynamic>{};
                    final name = client['name']?.toString() ?? widget.clientName;
                    final company = (client['companyName'] ?? client['company_name'])?.toString() ?? widget.companyName;
                    final location = client['location']?.toString() ?? widget.location;
                    final address = (client['contactAddress'] ?? client['contact_address'])?.toString() ?? '';
                    final workers = ((client['workers'] as List?) ?? const [])
                        .whereType<Map>()
                        .toList();
                    final active = (client['isActive'] ?? client['is_active']) != false;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(radius: 28, child: Text(name.isEmpty ? '?' : name.substring(0, 1))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: Theme.of(context).textTheme.titleLarge),
                            Text([company, location].where((value) => value.isNotEmpty).join(' | ')),
                            const SizedBox(height: 4),
                            Text(active ? 'Active' : 'Archived', style: TextStyle(color: active ? Colors.green : Colors.grey)),
                          ])),
                        ]),
                        const SizedBox(height: 24),
                        const _SectionTitle('Client Information'),
                        if (company.isNotEmpty) _InfoRow('Company', company),
                        if (location.isNotEmpty) _InfoRow('Location', location),
                        if (address.isNotEmpty) _InfoRow('Contact address', address),
                        const SizedBox(height: 18),
                        const _SectionTitle('Portal Access'),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.lock_outline),
                          title: Text('Credentials are masked'),
                          subtitle: Text('Use Client Access & Security to manage protected access.'),
                        ),
                        if (canManageClient)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => AdministrativeSecurityScreen(
                                clientId: widget.clientId!,
                                clientName: name,
                              ),
                            )),
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text('Client Access & Security'),
                          ),
                        const SizedBox(height: 18),
                        const _SectionTitle('Assigned Workers'),
                        if (workers.isEmpty)
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('No workers assigned.'),
                          )
                        else
                          ...workers.map((worker) {
                            final details = worker['worker'] as Map? ?? const {};
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text((details['full_name']?.toString() ?? 'W').substring(0, 1)),
                              ),
                              title: Text(details['full_name']?.toString() ?? 'Worker'),
                              subtitle: Text(details['role']?.toString() ?? 'Staff'),
                            );
                          }),
                        if (canManageClient)
                          FilledButton.icon(
                            onPressed: () => _manageAssignments(client),
                            icon: const Icon(Icons.manage_accounts_outlined),
                            label: const Text('Manage Assignments'),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            AdministrativeDocumentsScreen(
              clientName: widget.clientName,
              clientId: widget.clientId,
              canManageDocuments: canManageClient,
            ),
            AdministrativeObligationsScreen(clientName: widget.clientName),
            _ClientRecordsTab(clientId: widget.clientId, title: 'Tasks', type: _ClientRecordType.tasks),
            _ClientRecordsTab(clientId: widget.clientId, title: 'Expenses', type: _ClientRecordType.expenses),
            _ClientRecordsTab(clientId: widget.clientId, title: 'Revenue', type: _ClientRecordType.revenue),
            _ClientRecordsTab(clientId: widget.clientId, title: 'Activity', type: _ClientRecordType.activity),
          ],
        ),
      ),
    );
  }
}

class AdministrativeDocumentsScreen extends StatefulWidget {
  const AdministrativeDocumentsScreen({
    super.key,
    required this.clientName,
    this.clientId,
    this.canManageDocuments = true,
  });

  final String clientName;
  final String? clientId;
  final bool canManageDocuments;

  @override
  State<AdministrativeDocumentsScreen> createState() =>
      _AdministrativeDocumentsScreenState();
}

class _AdministrativeDocumentsScreenState
    extends State<AdministrativeDocumentsScreen> {
  String _query = '';
  String? _folderId;
  late Future<List<Map<String, dynamic>>> _folders;
  late Future<List<Map<String, dynamic>>> _documents;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (widget.clientId == null) {
      _folders = Future.value(const []);
      _documents = Future.value(const []);
      return;
    }
    final provider = context.read<AdministrativeProvider>();
    _folders = provider.loadFolders(widget.clientId!);
    _documents = provider.loadDocuments(widget.clientId!, query: _query, folderId: _folderId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clientId == null) {
      return const Center(child: Text('Client documents require a saved client record.'));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('${widget.clientName} Documents'),
        actions: [
          if (widget.canManageDocuments)
            IconButton(
              tooltip: 'Create folder',
              onPressed: _createFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.canManageDocuments)
            FilledButton.icon(
              onPressed: _uploadDocument,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Document'),
            ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) {
              setState(() {
                _query = value.trim();
                _documents = context.read<AdministrativeProvider>().loadDocuments(widget.clientId!, query: _query, folderId: _folderId);
              });
            },
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search documents', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _folders,
            builder: (context, snapshot) => Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('All folders'), selected: _folderId == null, onSelected: (_) => _selectFolder(null)),
                ...?snapshot.data?.map((folder) => ChoiceChip(
                  label: Text('${folder['name']} (${folder['document_count'] ?? 0})'),
                  selected: _folderId == folder['id']?.toString(),
                  onSelected: (_) => _selectFolder(folder['id']?.toString()),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _documents,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              if (snapshot.hasError) return _LoadError(onRetry: () => setState(_reload));
              final documents = snapshot.data ?? const <Map<String, dynamic>>[];
              if (documents.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No documents in this view.')));
              return Column(children: documents.map((document) => _LiveDocumentTile(document: document, canAssign: widget.canManageDocuments, clientId: widget.clientId!)).toList());
            },
          ),
        ],
      ),
    );
  }

  void _selectFolder(String? folderId) => setState(() {
    _folderId = folderId;
    _documents = context.read<AdministrativeProvider>().loadDocuments(widget.clientId!, query: _query, folderId: _folderId);
  });

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(title: const Text('Create Folder'), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Folder name')), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialog, controller.text.trim()), child: const Text('Create'))]));
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await context.read<AdministrativeProvider>().createFolder(widget.clientId!, name);
      if (mounted) setState(_reload);
    } catch (error) { if (mounted) _message(context, 'Unable to create folder: $error'); }
  }

  Future<void> _uploadDocument() async {
    final selected = await FilePicker.platform.pickFiles(withData: true);
    final file = selected?.files.single;
    if (file?.bytes == null || !mounted) return;
    try {
      await context.read<AdministrativeProvider>().uploadDocument(clientId: widget.clientId!, fileName: file!.name, bytes: file.bytes!, mimeType: _mimeTypeForFile(file.name), folderId: _folderId);
      if (mounted) { setState(_reload); _message(context, '${file.name} uploaded'); }
    } catch (error) { if (mounted) _message(context, 'Unable to upload document: $error'); }
  }
}

class AdministrativeAssignDocumentScreen extends StatefulWidget {
  const AdministrativeAssignDocumentScreen({super.key, required this.documentName, this.documentId, this.clientId});

  final String documentName;
  final String? documentId;
  final String? clientId;

  @override
  State<AdministrativeAssignDocumentScreen> createState() =>
      _AdministrativeAssignDocumentScreenState();
}

class _AdministrativeAssignDocumentScreenState
    extends State<AdministrativeAssignDocumentScreen> {
  final _noteController = TextEditingController();
  String _priority = 'normal';
  String? _workerId;
  DateTime _dueAt = DateTime.now().add(const Duration(days: 1));
  late Future<List<Map<String, dynamic>>> _staff;

  @override
  void initState() { super.initState(); _staff = context.read<AdministrativeProvider>().loadStaffing(); }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Assign Document to Worker')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _staff,
        builder: (context, snapshot) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf_outlined)),
            title: Text(widget.documentName),
            subtitle: const Text('Document selected for assignment'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _workerId,
            decoration: const InputDecoration(labelText: 'Assign to Worker', border: OutlineInputBorder()),
            items: (snapshot.data ?? const <Map<String, dynamic>>[])
                .where((worker) => worker['is_active'] != false)
                .map((worker) => DropdownMenuItem(value: worker['id']?.toString(), child: Text(worker['full_name']?.toString() ?? 'Worker')))
                .toList(),
            onChanged: (value) => setState(() => _workerId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _priority, decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'low', child: Text('Low')), DropdownMenuItem(value: 'normal', child: Text('Normal')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'urgent', child: Text('Urgent'))], onChanged: (value) => setState(() => _priority = value ?? 'normal')),
          ListTile(title: const Text('Due date'), subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(_dueAt)), trailing: const Icon(Icons.event_outlined), onTap: () async { final date = await showDatePicker(context: context, initialDate: _dueAt, firstDate: DateTime.now(), lastDate: DateTime(2100)); if (date != null) setState(() => _dueAt = date); }),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Please review and update the uploaded document.',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _workerId == null || widget.clientId == null ? null : () async {
              try {
                await context.read<AdministrativeProvider>().createLiveTask(title: 'Review ${widget.documentName}', clientId: widget.clientId!, documentId: widget.documentId, workerId: _workerId, remark: _noteController.text, priority: _priority, dueAt: _dueAt);
                if (mounted) { _message(context, '${widget.documentName} assigned'); Navigator.of(context).pop(); }
              } catch (error) { if (mounted) _message(context, 'Unable to assign document: $error'); }
            },
            child: const Text('Assign Document'),
          ),
        ]),
      )),
    );
  }
}

class AdministrativeTaskCompletionScreen extends StatefulWidget {
  const AdministrativeTaskCompletionScreen({
    super.key,
    required this.taskId,
    required this.taskName,
  });

  final String taskId;
  final String taskName;

  @override
  State<AdministrativeTaskCompletionScreen> createState() =>
      _AdministrativeTaskCompletionScreenState();
}

class AdministrativeWorkerDashboardScreen extends StatelessWidget {
  const AdministrativeWorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Worker Dashboard')),
      body: Consumer<AdministrativeProvider>(
        builder: (context, provider, _) {
          final tasks = provider.tasksForWorker('Sarah Daniels');
          return ListView(padding: const EdgeInsets.all(16), children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(radius: 24, child: Text('SD')),
          title: Text('Sarah Daniels'),
          subtitle: Text('General Worker | Available'),
        ),
        const _SectionTitle('Current Tasks'),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No tasks are assigned to you.'),
          ),
        ...tasks.map((task) => ListTile(
              onTap: task.isOpen
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AdministrativeTaskCompletionScreen(
                          taskId: task.id,
                          taskName: task.title,
                        ),
                      ))
                  : null,
              leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
              title: Text(task.title),
              subtitle: Text('${task.clientName} | ${_dueText(task.dueAt)}'),
              trailing: _StatusPill(status: task.status),
            )),
        const SizedBox(height: 20),
        const _SectionTitle('My Obligations'),
        if (provider.obligations.isEmpty)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.event_available_outlined),
            title: Text('No active obligations'),
          )
        else
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.event_note_outlined)),
            title: Text(provider.obligations.first.title),
            subtitle: Text(provider.obligations.first.clientName),
            trailing: Text(
              _dueText(provider.obligations.first.dueAt),
              style: const TextStyle(color: Colors.green),
            ),
          ),
      ]);
        },
      ),
    );
  }
}

class _AdministrativeTaskCompletionScreenState
    extends State<AdministrativeTaskCompletionScreen> {
  PlatformFile? _selectedFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    context.read<AdministrativeProvider>().startTask(widget.taskId).catchError(
      (Object error) {
        if (mounted) _message(context, 'Unable to start task: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = context.watch<AdministrativeProvider>().taskById(widget.taskId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Task Completion'),
        actions: [
          IconButton(
            tooltip: 'Task comments',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AdministrativeTaskCommentsScreen(taskId: widget.taskId),
            )),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf_outlined)),
            title: Text(widget.taskName),
            subtitle: Text(task?.note ?? 'Task instructions'),
          ),
          const Divider(),
          const SizedBox(height: 12),
          Text(task?.documentId == null
              ? 'Add a completion note or attach supporting work.'
              : 'Attach the completed document for review.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSubmitting
                ? null
                : () async {
                    final result = await FilePicker.platform.pickFiles(
                      withData: true,
                      allowMultiple: false,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final file = result.files.single;
                    if (file.bytes == null || file.bytes!.isEmpty) {
                      if (mounted) {
                        _message(context, 'Unable to read the selected file.');
                      }
                      return;
                    }
                    setState(() => _selectedFile = file);
                  },
            icon: Icon(_selectedFile == null
                ? Icons.upload_file_outlined
                : Icons.check_circle),
            label: Text(_selectedFile?.name ?? 'Choose completed file'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _isSubmitting ||
                    (task?.documentId != null && _selectedFile == null)
                ? null
                : () async {
                    setState(() => _isSubmitting = true);
                    try {
                      final file = _selectedFile;
                      await context.read<AdministrativeProvider>().submitTask(
                            widget.taskId,
                            file?.name ?? 'Task completed',
                            fileBytes: file?.bytes,
                            mimeType: file?.extension?.toLowerCase() == 'pdf'
                                ? 'application/pdf'
                                : 'application/octet-stream',
                          );
                      if (!mounted) return;
                      _message(context, 'Task submitted for review');
                      Navigator.of(context).pop();
                    } catch (error) {
                      if (mounted) {
                        setState(() => _isSubmitting = false);
                        _message(context, 'Unable to submit task: $error');
                      }
                    }
                  },
            child: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit for Review'),
          ),
        ]),
      ),
    );
  }
}

class AdministrativeTaskCommentsScreen extends StatefulWidget {
  const AdministrativeTaskCommentsScreen({super.key, required this.taskId});
  final String taskId;

  @override
  State<AdministrativeTaskCommentsScreen> createState() =>
      _AdministrativeTaskCommentsScreenState();
}

class _AdministrativeTaskCommentsScreenState
    extends State<AdministrativeTaskCommentsScreen> {
  final _controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> _comments;

  @override
  void initState() { super.initState(); _comments = _load(); }

  Future<List<Map<String, dynamic>>> _load() =>
      context.read<AdministrativeProvider>().loadTaskComments(widget.taskId);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Task Comments')),
    body: Column(children: [
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _comments, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _LoadError(onRetry: () => setState(() => _comments = _load()));
        final comments = snapshot.data ?? const <Map<String, dynamic>>[];
        if (comments.isEmpty) return const Center(child: Text('No comments yet.'));
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: comments.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (context, index) { final item = comments[index]; return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.comment_outlined), title: Text(item['body']?.toString() ?? ''), subtitle: Text(item['author_name']?.toString() ?? 'User')); });
      })),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: _controller, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Add a comment', border: OutlineInputBorder()))), const SizedBox(width: 8), IconButton(tooltip: 'Send comment', icon: const Icon(Icons.send), onPressed: _send)]))),
    ]),
  );

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    try {
      await context.read<AdministrativeProvider>().addTaskComment(widget.taskId, body);
      _controller.clear();
      if (mounted) setState(() => _comments = _load());
    } catch (error) { if (mounted) _message(context, 'Unable to add comment: $error'); }
  }
}

class AdministrativeDocumentReviewScreen extends StatefulWidget {
  const AdministrativeDocumentReviewScreen({
    super.key,
    required this.taskId,
    required this.documentName,
  });

  final String taskId;
  final String documentName;

  @override
  State<AdministrativeDocumentReviewScreen> createState() =>
      _AdministrativeDocumentReviewScreenState();
}

class _AdministrativeDocumentReviewScreenState
    extends State<AdministrativeDocumentReviewScreen> {
  late final Future<List<Map<String, dynamic>>> _versions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = context.read<AdministrativeProvider>().taskById(widget.taskId);
    _versions = task?.documentId == null
        ? Future.value(const [])
        : context
            .read<AdministrativeProvider>()
            .loadDocumentVersions(task!.documentId!);
  }

  @override
  Widget build(BuildContext context) {
    final task = context.watch<AdministrativeProvider>().taskById(widget.taskId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Admin Document Review')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf_outlined)),
            title: Text(task?.documentName ?? widget.documentName),
            subtitle: Text('Submitted by ${task?.assignedTo ?? 'assigned worker'}'),
          ),
          const Divider(),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _versions,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Unable to load document versions: ${snapshot.error}');
              }
              final versions = snapshot.data ?? const [];
              if (versions.isEmpty) {
                return const ListTile(
                  title: Text('Task has no linked document versions.'),
                );
              }
              return Column(
                children: versions.map((version) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(version['fileName']?.toString() ??
                      version['file_name']?.toString() ?? 'Document version'),
                  subtitle: Text('Version ${version['versionNumber'] ?? version['version_number'] ?? ''}'),
                )).toList(),
              );
            },
          ),
          const Spacer(),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _reject,
                child: const Text('Return to worker'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _approvalAction,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Approve'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _approvalAction() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.find_replace_outlined),
            title: const Text('Replace original document'),
            onTap: () => Navigator.pop(sheetContext, 'replace_original'),
          ),
          ListTile(
            leading: const Icon(Icons.file_copy_outlined),
            title: const Text('Store as a new document'),
            onTap: () => Navigator.pop(sheetContext, 'store_as_new_version'),
          ),
        ]),
      )),
    );
    if (action == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<AdministrativeProvider>().reviewTask(
            widget.taskId,
            approved: true,
            storageAction: action,
          );
      if (!mounted) return;
      _message(context, action == 'replace_original'
          ? 'Document approved and original replaced'
          : 'Document approved as a new version');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _message(context, 'Unable to approve document: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Return work to the worker'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for return *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Return'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (remark == null || remark.trim().isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<AdministrativeProvider>().reviewTask(
            widget.taskId,
            approved: false,
            remark: remark.trim(),
          );
      if (!mounted) return;
      _message(context, 'Document returned to the worker');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _message(context, 'Unable to return document: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AdministrativeObligationsScreen extends StatefulWidget {
  const AdministrativeObligationsScreen({super.key, this.clientName});

  final String? clientName;

  @override
  State<AdministrativeObligationsScreen> createState() =>
      _AdministrativeObligationsScreenState();
}

class _AdministrativeObligationsScreenState
    extends State<AdministrativeObligationsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Obligations Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Add obligation',
            onPressed: () => _createObligation(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Consumer<AdministrativeProvider>(
        builder: (context, provider, _) {
          final obligations = provider.obligations.where((obligation) {
            final matchesClient =
                widget.clientName == null || obligation.clientName == widget.clientName;
            final remaining = obligation.dueAt.difference(DateTime.now());
            if (_filter == 'Completed') return matchesClient && obligation.isCompleted;
            if (_filter == 'Urgent') {
              return matchesClient && !obligation.isCompleted && remaining.inDays <= 7;
            }
            if (_filter == '24 hours') {
              return matchesClient &&
                  !obligation.isCompleted &&
                  remaining >= Duration.zero &&
                  remaining <= const Duration(hours: 24);
            }
            if (_filter == '3 days') {
              return matchesClient &&
                  !obligation.isCompleted &&
                  remaining >= Duration.zero &&
                  remaining <= const Duration(days: 3);
            }
            return matchesClient && !obligation.isCompleted;
          }).toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                children: ['All', '24 hours', '3 days', 'Urgent', 'Completed']
                    .map((filter) => ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              if (obligations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No obligations in this view.')),
                ),
              ...obligations.map((obligation) => _Obligation(
                    obligation: obligation,
                    onComplete: () async {
                      try {
                        await provider.completeObligationLive(obligation.id);
                        if (context.mounted) {
                          _message(context, '${obligation.title} marked complete');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _message(context, 'Unable to complete obligation: $error');
                        }
                      }
                    },
                  )),
            ],
          );
        },
      ),
    );
  }

  void _createObligation(BuildContext context) {
    String countdown = 'Fixed date';
    final taskController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    final dateController = TextEditingController(text: '${DateTime.now().day}');
    String? selectedClientId = context
      .read<AdministrativeProvider>()
      .clients
      .where((client) => client.name == widget.clientName)
      .map((client) => client.id)
      .firstOrNull;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Obligation'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: taskController, decoration: const InputDecoration(labelText: 'Task name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedClientId,
              decoration: const InputDecoration(labelText: 'Client *'),
              items: context
                  .read<AdministrativeProvider>()
                  .clients
                  .map((client) => DropdownMenuItem(
                        value: client.id,
                        child: Text(client.name),
                      ))
                  .toList(),
              onChanged: (value) => setDialogState(() => selectedClientId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: countdown,
              decoration: const InputDecoration(labelText: 'Countdown type'),
              items: const ['Fixed date', 'Trailing']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setDialogState(() => countdown = value ?? countdown),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration (days)'),
            ),
            if (countdown == 'Fixed date') ...[
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fixed day of month'),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final title = taskController.text.trim();
                final duration = int.tryParse(durationController.text);
                final fixedDay = countdown == 'Fixed date'
                    ? int.tryParse(dateController.text)
                    : null;
                if (title.isEmpty || selectedClientId == null || duration == null || duration < 1) {
                  _message(context, 'Enter a task, client, and valid interval.');
                  return;
                }
                if (countdown == 'Fixed date' &&
                    (fixedDay == null || fixedDay < 1 || fixedDay > 31 || duration < 28)) {
                  _message(context, 'Fixed monthly obligations need a day from 1-31 and an interval of at least 28 days.');
                  return;
                }
                final now = DateTime.now();
                final nextDueAt = countdown == 'Fixed date'
                    ? _nextFixedObligationDate(now, fixedDay!)
                    : now.add(Duration(days: duration));
                try {
                  await context.read<AdministrativeProvider>().createLiveObligation(
                        title: title,
                        clientId: selectedClientId!,
                        countdownType: countdown == 'Fixed date'
                            ? AdministrativeCountdownType.fixedDate
                            : AdministrativeCountdownType.trailing,
                        intervalDays: duration,
                        nextDueAt: nextDueAt,
                        fixedDayOfMonth: fixedDay,
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) _message(context, 'Obligation created');
                } catch (error) {
                  if (context.mounted) _message(context, 'Unable to create obligation: $error');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _nextFixedObligationDate(DateTime from, int day) {
    final monthEnd = DateTime(from.year, from.month + 1, 0).day;
    var due = DateTime(from.year, from.month, day.clamp(1, monthEnd));
    if (!due.isAfter(from)) {
      final nextMonthEnd = DateTime(from.year, from.month + 2, 0).day;
      due = DateTime(from.year, from.month + 1, day.clamp(1, nextMonthEnd));
    }
    return due;
  }
}

class AdministrativeSecurityScreen extends StatefulWidget {
  const AdministrativeSecurityScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  final String clientId;
  final String clientName;

  @override
  State<AdministrativeSecurityScreen> createState() =>
      _AdministrativeSecurityScreenState();
}

class _AdministrativeSecurityScreenState
    extends State<AdministrativeSecurityScreen> {
  late Future<Map<String, dynamic>> _security;
  List<Map<String, dynamic>> _revealedCredentials = const [];

  @override
  void initState() {
    super.initState();
    _security = context.read<AdministrativeProvider>()
        .loadClientSecurity(widget.clientId);
  }

  Future<String?> _promptPasscode() async {
    final controller = TextEditingController();
    final passcode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify client passcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '6-digit passcode'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Verify')),
        ],
      ),
    );
    controller.dispose();
    return passcode;
  }

  Future<void> _rotatePasscode() async {
    try {
      final passcode = await context
          .read<AdministrativeProvider>()
          .rotateClientPasscode(widget.clientId);
      if (!mounted) return;
      setState(() => _security = context
          .read<AdministrativeProvider>()
          .loadClientSecurity(widget.clientId));
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('New passcode'),
          content: SelectableText(passcode),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message(context, 'Unable to generate passcode: $error');
    }
  }

  Future<List<Map<String, dynamic>>?> _getVerifiedCredentials() async {
    final passcode = await _promptPasscode();
    if (passcode == null || passcode.isEmpty || !mounted) return null;
    try {
      return await context
          .read<AdministrativeProvider>()
          .revealClientCredentials(widget.clientId, passcode);
    } catch (error) {
      if (mounted) _message(context, 'Unable to reveal credentials: $error');
      return null;
    }
  }

  Future<void> _revealCredentials() async {
    final credentials = await _getVerifiedCredentials();
    if (!mounted || credentials == null) return;
    setState(() => _revealedCredentials = credentials);
  }

  Future<void> _addCredential() async {
    final existing = await _getVerifiedCredentials();
    if (existing == null || !mounted) return;
    final portal = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final notes = TextEditingController();
    final credential = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add portal credential'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: portal, decoration: const InputDecoration(labelText: 'Portal name')),
            TextField(controller: username, decoration: const InputDecoration(labelText: 'Username / email')),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (portal.text.trim().isEmpty || username.text.trim().isEmpty || password.text.isEmpty) return;
              Navigator.pop(dialogContext, {
                'portal': portal.text.trim(),
                'username': username.text.trim(),
                'password': password.text,
                'notes': notes.text.trim(),
              });
            },
            child: const Text('Save Encrypted'),
          ),
        ],
      ),
    );
    portal.dispose();
    username.dispose();
    password.dispose();
    notes.dispose();
    if (credential == null || !mounted) return;
    try {
      await context.read<AdministrativeProvider>().saveClientCredentials(
            widget.clientId,
            [...existing, credential],
          );
      setState(() => _revealedCredentials = [...existing, credential]);
      _message(context, 'Credential saved encrypted.');
    } catch (error) {
      if (mounted) _message(context, 'Unable to save credential: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().currentUser?.role.toLowerCase();
    final canManageAccess = ['owner', 'admin', 'sub_admin'].contains(role);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Client Access & Security')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
          leading: CircleAvatar(child: Text(widget.clientName.substring(0, 1))),
          title: Text(widget.clientName),
          subtitle: const Text('Client access controls'),
        ),
        const Divider(),
        FutureBuilder<Map<String, dynamic>>(
          future: _security,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return _LoadError(onRetry: () => setState(() => _security = context
                  .read<AdministrativeProvider>()
                  .loadClientSecurity(widget.clientId)));
            }
            final hasPasscode = snapshot.data?['hasPasscode'] == true;
            final hasCredentials = snapshot.data?['hasCredentials'] == true;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Access passcode'),
                  subtitle: Text(hasPasscode ? 'A passcode is configured.' : 'No passcode configured.'),
                ),
                if (canManageAccess)
                  FilledButton.tonalIcon(
                    onPressed: _rotatePasscode,
                    icon: const Icon(Icons.refresh),
                    label: Text(hasPasscode ? 'Rotate Passcode' : 'Generate Passcode'),
                  ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Portal credentials'),
                  subtitle: Text(hasCredentials ? 'Encrypted credentials are stored.' : 'No credentials stored.'),
                ),
                if (canManageAccess) ...[
                  OutlinedButton.icon(
                    onPressed: hasPasscode ? _revealCredentials : null,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Reveal with passcode'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: hasPasscode ? _addCredential : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Portal Credential'),
                  ),
                ],
                ..._revealedCredentials.map((credential) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(credential['portal']?.toString() ?? 'Portal', style: Theme.of(context).textTheme.titleMedium),
                            Text('Username: ${credential['username'] ?? ''}'),
                            SelectableText('Password: ${credential['password'] ?? ''}'),
                            if ((credential['notes']?.toString() ?? '').isNotEmpty)
                              Text('Notes: ${credential['notes']}'),
                          ],
                        ),
                      ),
                    )),
                if (!canManageAccess)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Only an administrator can manage or reveal portal credentials.'),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Security audit'),
        const Text('Passcode rotations, credential updates, and reveal attempts are recorded in the Activity Log.'),
      ]),
    );
  }
}

class _LiveDocumentTile extends StatefulWidget {
  const _LiveDocumentTile({
    required this.document,
    required this.clientId,
    required this.canAssign,
  });
  final Map<String, dynamic> document;
  final String clientId;
  final bool canAssign;

  @override
  State<_LiveDocumentTile> createState() => _LiveDocumentTileState();
}

class _LiveDocumentTileState extends State<_LiveDocumentTile> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.document['file_name']?.toString() ?? 'Document';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: CircleAvatar(child: Icon(_documentIcon(widget.document['mime_type']?.toString()))),
      title: Text(name),
      subtitle: Text(widget.document['folder_name']?.toString() ?? 'Unfiled'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_downloading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) else IconButton(tooltip: 'Download document', icon: const Icon(Icons.download_outlined), onPressed: _download),
        PopupMenuButton<String>(
          onSelected: _action,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'versions', child: Text('Version history')),
            if (widget.canAssign) const PopupMenuItem(value: 'assign', child: Text('Assign to worker')),
            if (widget.canAssign) const PopupMenuItem(value: 'version', child: Text('Upload approved version')),
          ],
        ),
      ]),
    );
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final file = await context.read<AdministrativeProvider>().downloadDocument(widget.document['id'].toString());
      final url = Uri.tryParse(file['file_url']?.toString() ?? '');
      if (url == null || !await launchUrl(url, mode: LaunchMode.externalApplication)) throw StateError('Unable to open file');
    } catch (error) { if (mounted) _message(context, 'Unable to download document: $error'); }
    finally { if (mounted) setState(() => _downloading = false); }
  }

  Future<void> _action(String action) async {
    if (action == 'assign') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdministrativeAssignDocumentScreen(documentName: widget.document['file_name']?.toString() ?? 'Document', documentId: widget.document['id']?.toString(), clientId: widget.clientId)));
      return;
    }
    if (action == 'versions') {
      final versions = await context.read<AdministrativeProvider>().loadDocumentVersions(widget.document['id'].toString());
      if (!mounted) return;
      showModalBottomSheet<void>(context: context, builder: (sheet) => ListView(children: [const ListTile(title: Text('Version History')), ...versions.map((version) => ListTile(title: Text(version['file_name']?.toString() ?? 'Version'), subtitle: Text('Version ${version['version_number']}')))]));
      return;
    }
    final selected = await FilePicker.platform.pickFiles(withData: true);
    final file = selected?.files.single;
    if (file?.bytes == null || !mounted) return;
    final approval = await showModalBottomSheet<String>(context: context, builder: (sheet) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(title: const Text('Replace current document'), onTap: () => Navigator.pop(sheet, 'replace')), ListTile(title: const Text('Store as version history'), onTap: () => Navigator.pop(sheet, 'new_version'))])));
    if (approval == null) return;
    try {
      await context.read<AdministrativeProvider>().approveDocumentVersion(documentId: widget.document['id'].toString(), fileName: file!.name, bytes: file.bytes!, mimeType: _mimeTypeForFile(file.name), action: approval);
      if (mounted) _message(context, 'Document version approved');
    } catch (error) { if (mounted) _message(context, 'Unable to approve version: $error'); }
  }
}

enum _ClientRecordType { tasks, expenses, revenue, activity }

class _ClientRecordsTab extends StatelessWidget {
  const _ClientRecordsTab({required this.clientId, required this.title, required this.type});
  final String? clientId;
  final String title;
  final _ClientRecordType type;

  @override
  Widget build(BuildContext context) {
    if (clientId == null) return const Center(child: Text('This view requires a saved client record.'));
    final provider = context.read<AdministrativeProvider>();
    final Future<List<Map<String, dynamic>>> future = switch (type) {
      _ClientRecordType.tasks => provider.loadTasksForClient(clientId!),
      _ClientRecordType.expenses => provider.loadFinancialEntries(type: 'expense', clientId: clientId),
      _ClientRecordType.revenue => provider.loadFinancialEntries(type: 'revenue', clientId: clientId),
      _ClientRecordType.activity => provider.loadActivity(),
    };
    return FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const Center(child: Text('Unable to load this client data.'));
      var records = snapshot.data ?? const <Map<String, dynamic>>[];
      if (type == _ClientRecordType.activity) records = records.where((item) => item['client_id']?.toString() == clientId).toList();
      if (records.isEmpty) return Center(child: Text('No $title records yet.'));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: records.length, itemBuilder: (context, index) {
        final item = records[index];
        final recordTitle = type == _ClientRecordType.tasks ? item['title'] : type == _ClientRecordType.activity ? item['action']?.toString().replaceAll('_', ' ') : item['description'];
        final subtitle = type == _ClientRecordType.tasks ? '${item['priority'] ?? 'normal'} priority | ${item['status'] ?? 'assigned'}' : type == _ClientRecordType.activity ? item['actor_name'] ?? 'System' : _currency(_asAmount(item['amount']));
        return ListTile(title: Text(recordTitle?.toString() ?? title), subtitle: Text(subtitle.toString()));
      });
    });
  }
}

IconData _documentIcon(String? mimeType) => mimeType == 'application/pdf' ? Icons.picture_as_pdf_outlined : mimeType?.contains('spreadsheet') == true || mimeType == 'text/csv' ? Icons.table_chart_outlined : Icons.description_outlined;

String _mimeTypeForFile(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) { 'pdf' => 'application/pdf', 'png' => 'image/png', 'jpg' || 'jpeg' => 'image/jpeg', 'csv' => 'text/csv', 'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', _ => 'application/pdf' };
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({
    required this.name,
    required this.folder,
    required this.time,
    required this.icon,
    required this.canAssign,
  });
  final String name;
  final String folder;
  final String time;
  final IconData icon;

  final bool canAssign;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _downloading = false;
  bool _downloaded = false;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _downloaded = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.name} download prepared.')),
    );
  }

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
        leading: CircleAvatar(child: Icon(widget.icon, size: 18)),
        title: Text(widget.name),
        subtitle: Text(widget.folder),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.time, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _downloading
                ? const SizedBox(
                    key: ValueKey('progress'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    key: ValueKey(_downloaded),
                    tooltip: _downloaded ? 'Downloaded' : 'Download document',
                    onPressed: _download,
                    icon: Icon(
                      _downloaded
                          ? Icons.check_circle_outline
                          : Icons.download_outlined,
                      color: _downloaded ? Colors.green : null,
                    ),
                  ),
          ),
        ]),
        onTap: widget.canAssign
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AdministrativeAssignDocumentScreen(
                    documentName: widget.name,
                  ),
                ))
            : null,
      );
}

class _Obligation extends StatelessWidget {
  const _Obligation({required this.obligation, required this.onComplete});
  final AdministrativeObligation obligation;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final remaining = obligation.dueAt.difference(DateTime.now());
    final remainingDays = remaining.inDays;
    final color = obligation.isCompleted
        ? Colors.green
        : remainingDays <= 7
            ? Colors.red
            : Colors.orange;
    final status = obligation.isCompleted
        ? 'Completed'
        : remaining.isNegative
            ? 'Overdue'
            : remaining < const Duration(days: 1)
                ? '${remaining.inHours} hours left'
            : '$remainingDays days left';
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(Icons.event_note_outlined, color: color, size: 18)),
      title: Text(obligation.title),
      subtitle: Text('${obligation.clientName} | ${obligation.countdownType == AdministrativeCountdownType.fixedDate ? 'Fixed date' : 'Trailing'}'),
      trailing: obligation.isCompleted
          ? Text(status, style: TextStyle(color: color, fontSize: 11))
          : TextButton(onPressed: onComplete, child: Text('Complete', style: TextStyle(color: color))),
    );
  }
}

String _dueText(DateTime dueAt) {
  final difference = dueAt.difference(DateTime.now());
  if (difference.inDays > 0) return '${difference.inDays} days left';
  if (difference.inHours > 0) return '${difference.inHours} hours left';
  return 'Due now';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final AdministrativeTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final values = switch (status) {
      AdministrativeTaskStatus.assigned => ('Assigned', Colors.orange),
      AdministrativeTaskStatus.inProgress => ('In progress', Colors.blue),
      AdministrativeTaskStatus.submitted => ('In review', Colors.purple),
      AdministrativeTaskStatus.approved => ('Approved', Colors.green),
      AdministrativeTaskStatus.rejected => ('Returned', Colors.red),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: values.$2.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
      child: Text(values.$1, style: TextStyle(color: values.$2, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, title: Text(label), trailing: Text(value));
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class AdministrativeEditClientScreen extends StatefulWidget {
  const AdministrativeEditClientScreen({
    super.key,
    required this.clientId,
    required this.name,
    required this.companyName,
    required this.location,
    this.contactAddress = '',
  });

  final String clientId;
  final String name;
  final String companyName;
  final String location;
  final String contactAddress;

  @override
  State<AdministrativeEditClientScreen> createState() =>
      _AdministrativeEditClientScreenState();
}

class _AdministrativeEditClientScreenState
    extends State<AdministrativeEditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _location;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _company = TextEditingController(text: widget.companyName);
    _location = TextEditingController(text: widget.location);
    _address = TextEditingController(text: widget.contactAddress);
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _location.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AdministrativeProvider>().updateClient(
            widget.clientId,
            name: _name.text,
            companyName: _company.text,
            location: _location.text,
            contactAddress: _address.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _message(context, 'Unable to update client: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Edit Client')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Client name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the client name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _company,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Company name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Contact address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
              ),
            ],
          ),
        ),
      );
}

class AdministrativeCreateClientScreen extends StatefulWidget {
  const AdministrativeCreateClientScreen({super.key});

  @override
  State<AdministrativeCreateClientScreen> createState() =>
      _AdministrativeCreateClientScreenState();
}

class _AdministrativeCreateClientScreenState
    extends State<AdministrativeCreateClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _location = TextEditingController();
  final _address = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _location.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final businessId =
          context.read<BusinessProvider>().currentBusiness?.id ?? '';
      if (businessId.isEmpty) {
        throw StateError(
          'Select an administrative business before creating a client.',
        );
      }
      final provider = context.read<AdministrativeProvider>();
      await provider.loadForBusiness(businessId);
      final client = await provider.createClient(
            name: _name.text,
            companyName: _company.text,
            location: _location.text,
            contactAddress: _address.text,
            businessId: businessId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(client);
    } catch (error) {
      if (mounted) _message(context, 'Unable to create client: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Add Client')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Client name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the client name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _company,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Company name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Contact address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_outlined),
                label: Text(_saving ? 'Creating...' : 'Create Client'),
              ),
            ],
          ),
        ),
      );
}

class AdministrativeCalendarScreen extends StatefulWidget {
  const AdministrativeCalendarScreen({super.key});

  @override
  State<AdministrativeCalendarScreen> createState() =>
      _AdministrativeCalendarScreenState();
}

class _AdministrativeCalendarScreenState
    extends State<AdministrativeCalendarScreen> {
  late DateTime _month;
  late DateTime _selectedDate;
  late Future<List<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _events = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return context.read<AdministrativeProvider>().loadCalendar(
          _month,
          DateTime(_month.year, _month.month + 1),
        );
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selectedDate = _month;
      _events = _load();
    });
  }

  Future<void> _createEvent() async {
    final title = TextEditingController();
    final description = TextEditingController();
    DateTime startsAt = _selectedDate.add(const Duration(hours: 9));
    final clients = context.read<AdministrativeProvider>().clients;
    String? clientId;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16,
              MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                  labelText: 'Event title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder()),
            ),
            ListTile(
              title: const Text('Scheduled for'),
              subtitle: Text(
                  MaterialLocalizations.of(context).formatFullDate(startsAt)),
              trailing: const Icon(Icons.event_outlined),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: startsAt,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setSheetState(() => startsAt = DateTime(
                      date.year, date.month, date.day, startsAt.hour));
                }
              },
            ),
            if (clients.isNotEmpty)
              DropdownButton<String?>(
                value: clientId,
                isExpanded: true,
                hint: const Text('Business-wide event'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Business-wide event')),
                  ...clients.map((client) => DropdownMenuItem<String?>(
                      value: client.id, child: Text(client.name))),
                ],
                onChanged: (value) => setSheetState(() => clientId = value),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                try {
                  await context
                      .read<AdministrativeProvider>()
                      .createCalendarEvent(
                        title: title.text,
                        description: description.text,
                        startsAt: startsAt,
                        clientId: clientId,
                      );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  if (context.mounted) {
                    _message(context, 'Unable to create event: $error');
                  }
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Event'),
            ),
          ]),
        ),
      ),
    );
    title.dispose();
    description.dispose();
    if (saved == true && mounted) setState(() => _events = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Calendar'),
          actions: [
            IconButton(
              tooltip: 'Add calendar event',
              onPressed: _createEvent,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(onRetry: () => setState(() => _events = _load()));
            }
            final events = snapshot.data ?? const <Map<String, dynamic>>[];
            final selectedEvents = events.where((event) {
              final startsAt = DateTime.tryParse(
                event['starts_at']?.toString() ?? '',
              );
              return startsAt != null && DateUtils.isSameDay(startsAt, _selectedDate);
            }).toList();
            return RefreshIndicator(
              onRefresh: () async => setState(() => _events = _load()),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        MaterialLocalizations.of(context).formatMonthYear(_month),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CalendarMonthGrid(
                    month: _month,
                    selectedDate: _selectedDate,
                    events: events,
                    onSelect: (date) => setState(() => _selectedDate = date),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    MaterialLocalizations.of(context).formatMediumDate(_selectedDate),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (selectedEvents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No tasks or obligations due on this day.'),
                    ),
                  ...selectedEvents.map((event) => _CalendarEventTile(event: event)),
                ],
              ),
            );
          },
        ),
      );
}

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid({
    required this.month,
    required this.selectedDate,
    required this.events,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<Map<String, dynamic>> events;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(month.year, month.month).weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
    final eventDays = <int>{
      for (final event in events)
        if (DateTime.tryParse(event['starts_at']?.toString() ?? '') case final date?)
          if (date.year == month.year && date.month == month.month) date.day,
    };
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Column(
      children: [
        Row(
          children: weekdays
              .map((day) => Expanded(
                    child: Center(
                      child: Text(day, style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: cells,
          itemBuilder: (context, index) {
            final day = index - firstWeekday + 1;
            if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, day);
            final selected = DateUtils.isSameDay(date, selectedDate);
            final hasEvents = eventDays.contains(day);
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelect(date),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('$day',
                          style: TextStyle(color: selected ? Colors.white : null)),
                      if (hasEvents)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarEventTile extends StatelessWidget {
  const _CalendarEventTile({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final isUrgent = event['status'] == 'urgent';
    final isObligation = event['event_type'] == 'obligation';
    final color = isUrgent ? Colors.red : AppColors.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(.12),
        child: Icon(
          isObligation ? Icons.event_repeat_outlined : Icons.task_alt_outlined,
          color: color,
        ),
      ),
      title: Text(event['title']?.toString() ?? 'Untitled'),
      subtitle: Text(event['client_name']?.toString() ?? 'No client'),
      trailing: Text(isObligation ? 'Obligation' : 'Task'),
    );
  }
}

class AdministrativeStaffingScreen extends StatefulWidget {
  const AdministrativeStaffingScreen({super.key});

  @override
  State<AdministrativeStaffingScreen> createState() =>
      _AdministrativeStaffingScreenState();
}

class _AdministrativeStaffingScreenState
    extends State<AdministrativeStaffingScreen> {
  late Future<List<Map<String, dynamic>>> _staff;

  @override
  void initState() {
    super.initState();
    _staff = context.read<AdministrativeProvider>().loadStaffing();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Staffing')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _staff,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _LoadError(onRetry: () => setState(() => _staff = context.read<AdministrativeProvider>().loadStaffing()));
            final staff = snapshot.data ?? const [];
            if (staff.isEmpty) return const Center(child: Text('No staff records found.'));
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: staff.length,
              itemBuilder: (context, index) {
                final worker = staff[index];
                final name = worker['full_name']?.toString() ?? 'Unnamed worker';
                return ListTile(
                  onTap: () => _manageAssignments(worker),
                  leading: CircleAvatar(child: Text(name.substring(0, 1).toUpperCase())),
                  title: Text(name),
                  subtitle: Text('${worker['role'] ?? 'Staff'} | ${worker['assigned_client_count'] ?? 0} clients'),
                  trailing: Text('${worker['open_task_count'] ?? 0} open tasks'),
                );
              },
            );
          },
        ),
      );

  Future<void> _manageAssignments(Map<String, dynamic> worker) async {
    final clients = context.read<AdministrativeProvider>().clients;
    final workerId = worker['id']?.toString() ?? '';
    if (workerId.isEmpty || clients.isEmpty) return;
    final assigned = (worker['assigned_client_ids'] as List? ?? const [])
        .map((item) => item.toString())
        .toSet();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text('Client Access: ${worker['full_name'] ?? 'Worker'}')),
            ...clients.map((client) => CheckboxListTile(
                  title: Text(client.name),
                  subtitle: Text(client.companyName),
                  value: assigned.contains(client.id),
                  onChanged: (value) async {
                    try {
                      await context
                          .read<AdministrativeProvider>()
                          .setWorkerClientAssignment(
                            workerId: workerId,
                            clientId: client.id,
                            assigned: value == true,
                          );
                      setSheetState(() {
                        if (value == true) {
                          assigned.add(client.id);
                        } else {
                          assigned.remove(client.id);
                        }
                      });
                    } catch (error) {
                      if (context.mounted) {
                        _message(context, 'Unable to update access: $error');
                      }
                    }
                  },
                )),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Done'),
            ),
          ]),
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(
        () => _staff = context.read<AdministrativeProvider>().loadStaffing(),
      );
    }
  }
}

class AdministrativeActivityScreen extends StatefulWidget {
  const AdministrativeActivityScreen({super.key});

  @override
  State<AdministrativeActivityScreen> createState() =>
      _AdministrativeActivityScreenState();
}

class _AdministrativeActivityScreenState
    extends State<AdministrativeActivityScreen> {
  late Future<List<Map<String, dynamic>>> _activity;
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _activity = context.read<AdministrativeProvider>().loadActivity();
  }

  Future<void> _exportActivity() async {
    try {
      final activity = await context.read<AdministrativeProvider>().loadActivity();
      final filtered = activity.where((item) {
        final action = item['action']?.toString() ?? 'Activity';
        final text = '${item['actor_name'] ?? ''} ${item['client_name'] ?? ''} $action'
            .toLowerCase();
        return (_filter == 'All' || action == _filter) && text.contains(_query.toLowerCase());
      });
      String escape(Object? value) => '"${(value?.toString() ?? '').replaceAll('"', '""')}"';
      final csv = ['Timestamp,Action,Actor,Client', ...filtered.map((item) => [escape(item['created_at']), escape(item['action']), escape(item['actor_name']), escape(item['client_name'])].join(','))].join('\n');
      await Share.share(csv, subject: 'ManageCare activity log export');
    } catch (error) {
      if (mounted) _message(context, 'Unable to export activity log: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Activity Log'),
          actions: [
            IconButton(
              tooltip: 'Export activity log',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: _exportActivity,
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _activity,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _LoadError(onRetry: () => setState(() => _activity = context.read<AdministrativeProvider>().loadActivity()));
            final activity = snapshot.data ?? const <Map<String, dynamic>>[];
            if (activity.isEmpty) return const Center(child: Text('No recorded activity yet.'));
            final actions = <String>{
              for (final item in activity) item['action']?.toString() ?? 'Activity',
            }.toList()
              ..sort();
            final visible = activity.where((item) {
              final action = item['action']?.toString() ?? 'Activity';
              final text = '${item['actor_name'] ?? ''} ${item['client_name'] ?? ''} $action'
                  .toLowerCase();
              return (_filter == 'All' || action == _filter) &&
                  text.contains(_query.toLowerCase());
            }).toList();
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visible.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      TextField(
                        onChanged: (value) => setState(() => _query = value.trim()),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search activity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: ['All', ...actions]
                              .map(
                                (action) => ChoiceChip(
                                  label: Text(action.replaceAll('_', ' ')),
                                  selected: _filter == action,
                                  onSelected: (_) => setState(() => _filter = action),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('No activity matches these filters.'),
                        ),
                    ],
                  );
                }
                final item = visible[index - 1];
                final at = DateTime.tryParse(item['created_at']?.toString() ?? '');
                return ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(item['action']?.toString().replaceAll('_', ' ') ?? 'Activity'),
                  subtitle: Text('${item['actor_name'] ?? 'System'} | ${item['client_name'] ?? 'Business'}'),
                  trailing: Text(at == null ? '' : MaterialLocalizations.of(context).formatShortDate(at)),
                );
              },
            );
          },
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
}

class AdministrativeFinancePanel extends StatefulWidget {
  const AdministrativeFinancePanel({super.key});

  @override
  State<AdministrativeFinancePanel> createState() =>
      _AdministrativeFinancePanelState();
}

class _AdministrativeFinancePanelState extends State<AdministrativeFinancePanel> {
  late Future<List<Map<String, dynamic>>> _entries;
  String _entryFilter = 'All';
  String? _clientFilter;

  @override
  void initState() {
    super.initState();
    _entries = context.read<AdministrativeProvider>().loadFinancialEntries();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(onRetry: () => setState(() => _entries = context.read<AdministrativeProvider>().loadFinancialEntries()));
          }
          final entries = snapshot.data ?? const <Map<String, dynamic>>[];
          final revenue = entries.where((item) => item['entry_type'] == 'revenue').fold<double>(0, (sum, item) => sum + _asAmount(item['amount']));
          final expenses = entries.where((item) => item['entry_type'] == 'expense').fold<double>(0, (sum, item) => sum + _asAmount(item['amount']));
          return RefreshIndicator(
            onRefresh: () async => setState(() => _entries = context.read<AdministrativeProvider>().loadFinancialEntries()),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(child: Text('Finance', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: 'Add financial entry',
                    onPressed: _createEntry,
                    icon: const Icon(Icons.add),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdministrativeInvoicesScreen())),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Invoices'),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Net balance'),
                    const SizedBox(height: 6),
                    Text(_currency(revenue - expenses), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _AmountSummary(label: 'Revenue', value: _currency(revenue), color: Colors.green)),
                      Expanded(child: _AmountSummary(label: 'Expenses', value: _currency(expenses), color: Colors.red)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  children: ['All', 'Revenue', 'Expenses']
                      .map((filter) => ChoiceChip(
                            label: Text(filter),
                            selected: _entryFilter == filter,
                            onSelected: (_) => _setEntryFilter(filter),
                          ))
                      .toList(),
                ),
                if (context.read<AdministrativeProvider>().clients.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: DropdownButtonFormField<String?>(
                      value: _clientFilter,
                      decoration: const InputDecoration(
                        labelText: 'Client filter',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All clients'),
                        ),
                        ...context.read<AdministrativeProvider>().clients.map(
                              (client) => DropdownMenuItem<String?>(
                                value: client.id,
                                child: Text(client.name),
                              ),
                            ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _clientFilter = value;
                          _entries = _loadEntries();
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Recent entries', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                if (entries.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: Text('No financial entries yet.'))),
                ...entries.take(20).map((entry) {
                  final revenueEntry = entry['entry_type'] == 'revenue';
                  return ListTile(
                    onTap: () => _editEntry(entry),
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: (revenueEntry ? Colors.green : Colors.red).withOpacity(.12),
                      child: Icon(revenueEntry ? Icons.trending_up : Icons.trending_down, color: revenueEntry ? Colors.green : Colors.red),
                    ),
                    title: Text(entry['description']?.toString() ?? 'Financial entry'),
                    subtitle: Text(entry['client_name']?.toString() ?? 'Business'),
                    trailing: Text('${revenueEntry ? '+' : '-'}${_currency(_asAmount(entry['amount']))}', style: TextStyle(color: revenueEntry ? Colors.green : Colors.red, fontWeight: FontWeight.w700)),
                  );
                }),
              ],
            ),
          );
        },
      );

  Future<void> _createEntry() async {
    final formKey = GlobalKey<FormState>();
    final amount = TextEditingController();
    final description = TextEditingController();
    String type = 'revenue';
    String? clientId;
    final clients = context.read<AdministrativeProvider>().clients;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add Financial Entry',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Entry type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'revenue', child: Text('Revenue')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  ],
                  onChanged: (value) => setSheetState(() => type = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'N ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed < 0
                        ? 'Enter a valid amount'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a description'
                      : null,
                ),
                if (clients.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: clientId,
                    decoration: const InputDecoration(
                      labelText: 'Client (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Business-wide'),
                      ),
                      ...clients.map(
                        (client) => DropdownMenuItem<String?>(
                          value: client.id,
                          child: Text(client.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() => clientId = value),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await context
                          .read<AdministrativeProvider>()
                          .createFinancialEntry(
                            entryType: type,
                            amount: double.parse(amount.text.trim()),
                            description: description.text,
                            clientId: clientId,
                          );
                      if (context.mounted) Navigator.of(context).pop(true);
                    } catch (error) {
                      if (context.mounted) {
                        _message(context, 'Unable to save entry: $error');
                      }
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Entry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    amount.dispose();
    description.dispose();
    if (saved == true && mounted) {
      setState(
        () => _entries = context.read<AdministrativeProvider>().loadFinancialEntries(),
      );
      _message(context, 'Financial entry saved');
    }
  }

  Future<List<Map<String, dynamic>>> _loadEntries() =>
      context.read<AdministrativeProvider>().loadFinancialEntries(
            type: _entryFilter == 'All'
                ? null
                : _entryFilter == 'Revenue'
                    ? 'revenue'
                    : 'expense',
            clientId: _clientFilter,
          );

  void _setEntryFilter(String filter) {
    setState(() {
      _entryFilter = filter;
      _entries = _loadEntries();
    });
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    if (entry['invoice_id'] != null) {
      _message(context, 'Invoice payment entries are managed from the invoice.');
      return;
    }
    final formKey = GlobalKey<FormState>();
    final amount = TextEditingController(text: _asAmount(entry['amount']).toStringAsFixed(2));
    final description = TextEditingController(text: entry['description']?.toString() ?? '');
    var type = entry['entry_type']?.toString() ?? 'expense';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Edit Financial Entry'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'revenue', child: Text('Revenue')),
                DropdownMenuItem(value: 'expense', child: Text('Expense')),
              ],
              onChanged: (value) => type = value!,
            ),
            TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: _nonNegativeNumber,
            ),
            TextFormField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: _required,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await context.read<AdministrativeProvider>().updateFinancialEntry(
                      entryId: entry['id'].toString(),
                      entryType: type,
                      amount: double.parse(amount.text),
                      description: description.text,
                      clientId: entry['client_id']?.toString(),
                    );
                if (context.mounted) Navigator.pop(dialog, true);
              } catch (error) {
                if (context.mounted) _message(context, 'Unable to update entry: $error');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    amount.dispose();
    description.dispose();
    if (saved == true && mounted) setState(() => _entries = _loadEntries());
  }

}

class AdministrativeInvoicesScreen extends StatefulWidget {
  const AdministrativeInvoicesScreen({super.key});

  @override
  State<AdministrativeInvoicesScreen> createState() =>
      _AdministrativeInvoicesScreenState();
}

class _AdministrativeInvoicesScreenState
    extends State<AdministrativeInvoicesScreen> {
  late Future<List<Map<String, dynamic>>> _invoices;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _invoices = context.read<AdministrativeProvider>().loadInvoices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Invoices'),
          actions: [
            IconButton(
              tooltip: 'Create invoice',
              icon: const Icon(Icons.add),
              onPressed: _createInvoice,
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _invoices,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _LoadError(onRetry: () => setState(() => _invoices = context.read<AdministrativeProvider>().loadInvoices()));
            final all = snapshot.data ?? const <Map<String, dynamic>>[];
            final invoices = _filter == 'All' ? all : all.where((invoice) => invoice['status']?.toString() == _filter.toLowerCase()).toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  children: ['All', 'Draft', 'Sent', 'Paid', 'Void'].map((value) => ChoiceChip(label: Text(value), selected: _filter == value, onSelected: (_) => setState(() => _filter = value))).toList(),
                ),
                const SizedBox(height: 12),
                if (invoices.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No invoices in this view.'))),
                ...invoices.map((invoice) {
                  final status = invoice['status']?.toString() ?? 'draft';
                  final color = switch (status) { 'paid' => Colors.green, 'void' => Colors.red, 'sent' => Colors.orange, _ => Colors.blue };
                  return ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdministrativeInvoiceDetailScreen(
                          invoiceId: invoice['id'].toString(),
                        ),
                      ),
                    ).then((_) => setState(
                          () => _invoices = context
                              .read<AdministrativeProvider>()
                              .loadInvoices(),
                        )),
                    contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(Icons.receipt_long_outlined, color: color)),
                    title: Text(invoice['invoice_number']?.toString() ?? 'Invoice'),
                    subtitle: Text(invoice['client_name']?.toString() ?? 'Client'),
                    trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_currency(_asAmount(invoice['total_amount'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(status, style: TextStyle(color: color, fontSize: 12)),
                    ]),
                  );
                }),
              ],
            );
          },
        ),
      );

  Future<void> _createInvoice() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdministrativeCreateInvoiceScreen()),
    );
    if (created == true && mounted) {
      setState(() => _invoices = context.read<AdministrativeProvider>().loadInvoices());
    }
  }

  Future<void> _invoiceActions(Map<String, dynamic> invoice) async {
    final status = invoice['status']?.toString() ?? 'draft';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (status == 'draft')
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: const Text('Mark as sent'),
              onTap: () => Navigator.pop(sheetContext, 'send'),
            ),
          if (status == 'sent')
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Record payment'),
              onTap: () => Navigator.pop(sheetContext, 'payment'),
            ),
          if (status == 'draft' || status == 'sent')
            ListTile(
              leading: Icon(Icons.block_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Void invoice', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => Navigator.pop(sheetContext, 'void'),
            ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    try {
      final provider = context.read<AdministrativeProvider>();
      if (action == 'send') await provider.sendInvoice(invoice['id'].toString());
      if (action == 'void') await provider.voidInvoice(invoice['id'].toString());
      if (action == 'payment') {
        final amount = await _paymentAmount(invoice);
        if (amount == null) return;
        await provider.recordInvoicePayment(invoice['id'].toString(), amount);
      }
      if (!mounted) return;
      setState(() => _invoices = provider.loadInvoices());
      _message(context, 'Invoice updated');
    } catch (error) {
      if (mounted) _message(context, 'Unable to update invoice: $error');
    }
  }

  Future<double?> _paymentAmount(Map<String, dynamic> invoice) async {
    final remaining = _asAmount(invoice['total_amount']) - _asAmount(invoice['paid_amount']);
    final controller = TextEditingController(text: remaining.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Record Payment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, double.tryParse(controller.text)), child: const Text('Record')),
        ],
      ),
    );
    controller.dispose();
    return result == null || result <= 0 ? null : result;
  }
}

class AdministrativeInvoiceDetailScreen extends StatefulWidget {
  const AdministrativeInvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  State<AdministrativeInvoiceDetailScreen> createState() =>
      _AdministrativeInvoiceDetailScreenState();
}

class _AdministrativeInvoiceDetailScreenState
    extends State<AdministrativeInvoiceDetailScreen> {
  late Future<Map<String, dynamic>> _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = context.read<AdministrativeProvider>().loadInvoice(widget.invoiceId);
  }

  Future<Uint8List> _buildPdf(Map<String, dynamic> invoice) async {
    final document = pw.Document();
    final items = (invoice['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('INVOICE', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('Invoice: ${invoice['invoice_number'] ?? ''}'),
            pw.Text('Client: ${invoice['client_name'] ?? ''}'),
            pw.Text('Status: ${invoice['status'] ?? ''}'),
            pw.SizedBox(height: 18),
            pw.Table.fromTextArray(
              headers: const ['Description', 'Quantity', 'Amount'],
              data: items.map((item) => [
                    item['description']?.toString() ?? '',
                    item['quantity']?.toString() ?? '',
                    _currency(_asAmount(item['line_total'])),
                  ]).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total: ${_currency(_asAmount(invoice['total_amount']))}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if ((invoice['notes']?.toString() ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Notes: ${invoice['notes']}'),
            ],
          ],
        ),
      ),
    );
    return document.save();
  }

  Future<void> _emailInvoice() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Email Invoice'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'Recipient email', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await context.read<AdministrativeProvider>().emailInvoice(widget.invoiceId, email);
      if (mounted) {
        setState(() => _invoice = context
            .read<AdministrativeProvider>()
            .loadInvoice(widget.invoiceId));
        _message(context, 'Invoice emailed');
      }
    } catch (error) {
      if (mounted) _message(context, 'Unable to email invoice: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Invoice Details')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _invoice,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _LoadError(
                  onRetry: () => setState(() => _invoice = context
                      .read<AdministrativeProvider>()
                      .loadInvoice(widget.invoiceId)));
            }
            final invoice = snapshot.data!;
            final items = (invoice['items'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(invoice['invoice_number']?.toString() ?? 'Invoice',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(invoice['client_name']?.toString() ?? 'Client'),
                const SizedBox(height: 16),
                ...items.map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['description']?.toString() ?? 'Item'),
                      subtitle: Text('${item['quantity'] ?? 0} x ${_currency(_asAmount(item['unit_price']))}'),
                      trailing: Text(_currency(_asAmount(item['line_total']))),
                    )),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Subtotal'),
                  trailing: Text(_currency(_asAmount(invoice['subtotal']))),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tax'),
                  trailing: Text(_currency(_asAmount(invoice['tax_amount']))),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Total'),
                  trailing: Text(_currency(_asAmount(invoice['total_amount'])), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if ((invoice['notes']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Notes: ${invoice['notes']}'),
                  ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async => Printing.layoutPdf(
                          onLayout: (_) => _buildPdf(invoice)),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async => Printing.sharePdf(
                        bytes: await _buildPdf(invoice),
                        filename: '${invoice['invoice_number'] ?? 'invoice'}.pdf',
                      ),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('Share PDF'),
                    ),
                    FilledButton.icon(
                      onPressed: _emailInvoice,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Email Invoice'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
}

class AdministrativeCreateInvoiceScreen extends StatefulWidget {
  const AdministrativeCreateInvoiceScreen({super.key});

  @override
  State<AdministrativeCreateInvoiceScreen> createState() =>
      _AdministrativeCreateInvoiceScreenState();
}

class _AdministrativeCreateInvoiceScreenState
    extends State<AdministrativeCreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController(
      text: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController();
  final _tax = TextEditingController(text: '0');
  final _notes = TextEditingController();
  String? _clientId;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _tax.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _clientId == null || _saving) {
      if (_clientId == null) _message(context, 'Select a client.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AdministrativeProvider>().createInvoice(
            clientId: _clientId!,
            invoiceNumber: _number.text,
            description: _description.text,
            quantity: double.parse(_quantity.text),
            unitPrice: double.parse(_unitPrice.text),
            taxAmount: double.tryParse(_tax.text) ?? 0,
            dueDate: _dueDate?.toIso8601String().substring(0, 10),
            notes: _notes.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _message(context, 'Unable to create invoice: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<AdministrativeProvider>().clients;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create Invoice')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _clientId,
              decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder()),
              items: clients.map((client) => DropdownMenuItem(value: client.id, child: Text(client.name))).toList(),
              onChanged: (value) => setState(() => _clientId = value),
              validator: (value) => value == null ? 'Select a client' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _number, decoration: const InputDecoration(labelText: 'Invoice number', border: OutlineInputBorder()), validator: _required),
            const SizedBox(height: 14),
            TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Service description', border: OutlineInputBorder()), validator: _required),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextFormField(controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()), validator: _positiveNumber)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _unitPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit price', border: OutlineInputBorder()), validator: _nonNegativeNumber)),
            ]),
            const SizedBox(height: 14),
            TextFormField(controller: _tax, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tax amount', border: OutlineInputBorder()), validator: _nonNegativeNumber),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due date'),
              subtitle: Text(_dueDate == null ? 'No due date' : MaterialLocalizations.of(context).formatMediumDate(_dueDate!)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final value = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(DateTime.now().year + 5), initialDate: _dueDate ?? DateTime.now());
                if (value != null && mounted) setState(() => _dueDate = value);
              },
            ),
            TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.receipt_long_outlined), label: Text(_saving ? 'Creating...' : 'Create Draft Invoice')),
          ],
        ),
      ),
    );
  }

}

String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
String? _positiveNumber(String? value) => (double.tryParse(value ?? '') ?? 0) > 0 ? null : 'Enter a value above zero';
String? _nonNegativeNumber(String? value) => (double.tryParse(value ?? '') ?? -1) >= 0 ? null : 'Enter zero or more';

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ]);
}

double _asAmount(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

String _currency(double amount) => 'NGN ${amount.toStringAsFixed(2)}';
