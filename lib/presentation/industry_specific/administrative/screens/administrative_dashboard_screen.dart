import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/constants/business_types.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../widgets/animated_lottie.dart';
import '../providers/administrative_provider.dart';
import 'administrative_flow_screens.dart';

class AdministrativeDashboardScreen extends StatefulWidget {
  const AdministrativeDashboardScreen({super.key});

  @override
  State<AdministrativeDashboardScreen> createState() =>
      _AdministrativeDashboardScreenState();
}

class _AdministrativeDashboardScreenState
    extends State<AdministrativeDashboardScreen> {
  int _page = 0;
  String _query = '';
  String? _loadedBusinessId;
  bool _showArchivedClients = false;

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    final isAdministrativeOwner =
        context.watch<AuthProvider>().currentUser?.isOwner == true &&
            BusinessTypes.getById(business?.businessType ?? '')?.id ==
                'administrative';
    final title = business?.name.isNotEmpty == true
        ? business!.name
        : 'Administrative Services';
    final businessId = business?.id ?? '';
    if (_loadedBusinessId != businessId) {
      _loadedBusinessId = businessId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final provider = context.read<AdministrativeProvider>();
          if (businessId.isEmpty) {
            provider.clearWorkspace();
          } else {
            provider.loadForBusiness(businessId);
          }
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifications, _) => IconButton(
              tooltip: 'Notifications',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none),
                  if (notifications.unreadCount > 0)
                    Positioned(
                      right: -5,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          notifications.unreadCount > 9 ? '9+' : '${notifications.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => Navigator.of(context).pushNamed(Routes.notifications),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _page,
        children: [_home(), _tasks(), _clientsPage(), _finance(), _more()],
      ),
      floatingActionButton: isAdministrativeOwner
          ? FloatingActionButton(
              tooltip: 'Go to app home',
              onPressed: () => Navigator.of(context)
                  .pushReplacementNamed(Routes.ownerDashboard),
              child: const Icon(Icons.home_outlined),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (value) => setState(() => _page = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Finance'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  Widget _home() {
    final theme = Theme.of(context);
    return Consumer<AdministrativeProvider>(
      builder: (context, provider, _) {
        final metrics = provider.dashboard['metrics'] as Map? ?? const {};
        final tasksNeedingAttention = provider.tasks
            .where((task) => task.isOpen || task.needsReview)
            .take(3)
            .toList();
        return RefreshIndicator(
          onRefresh: provider.refreshWorkspace,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _WelcomeBand(businessName: context
                  .watch<BusinessProvider>()
                  .currentBusiness
                  ?.name),
              const SizedBox(height: 18),
              if (provider.loadError != null)
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: Icon(Icons.cloud_off_outlined,
                        color: theme.colorScheme.error),
                    title: const Text('Workspace data unavailable'),
                    subtitle: Text(provider.loadError!),
                    trailing: IconButton(
                      tooltip: 'Retry loading workspace',
                      onPressed: provider.refreshWorkspace,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              if (provider.isLoading)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedLottie(
                      asset: 'assets/lottie/loop.json',
                      width: 36,
                      height: 36,
                    ),
                    SizedBox(width: 8),
                    Text('Updating workspace...'),
                  ],
                ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  _Metric('Revenue', _adminCurrency(metrics['revenue']), 'Total', Icons.trending_up, AppColors.secondary, onTap: () => setState(() => _page = 3)),
                  _Metric('Expenses', _adminCurrency(metrics['expenses']), 'Total', Icons.trending_down, AppColors.error, onTap: () => setState(() => _page = 3)),
                  _Metric('Clients', '${metrics['clients'] ?? 0}', 'Active', Icons.people_outline, AppColors.primary, onTap: () => setState(() => _page = 2)),
                  _Metric('Total Staff', '${metrics['staff'] ?? 0}', 'Active', Icons.badge_outlined, AppColors.accentDark, onTap: _staffing),
                ],
              ).animate().fadeIn(duration: 350.ms).slideY(begin: .04, end: 0),
              const SizedBox(height: 18),
              _Title('Tasks needing attention', trailing: 'View all', onTap: () => setState(() => _page = 1)),
              if (tasksNeedingAttention.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No open or submitted tasks.'),
                ),
              ...tasksNeedingAttention.map((task) => ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: theme.colorScheme.surface,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(task.needsReview ? Icons.rate_review_outlined : Icons.task_alt_outlined),
                    title: Text(task.title),
                    subtitle: Text('${task.clientName} · ${task.status.name}'),
                    onTap: () => setState(() => _page = 1),
                  ).animate().fadeIn(duration: 260.ms).slideX(begin: .025, end: 0)),
              const SizedBox(height: 18),
              const _Title('Quick Actions'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _action('Add Client', Icons.person_add_alt_1_outlined, _addClient),
                  _action('Assign Document', Icons.assignment_outlined, _assignDocument),
                  _action('Create Task', Icons.add_task_outlined, () => setState(() => _page = 1)),
                  _action('Review Work', Icons.rate_review_outlined, _reviewWork),
                  _action('Record Revenue', Icons.trending_up, () => setState(() => _page = 3)),
                  _action('Record Expense', Icons.trending_down, () => setState(() => _page = 3)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _adminCurrency(Object? value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return 'NGN ${amount.toStringAsFixed(2)}';
  }

  Widget _clientsPage() {
    return Consumer<AdministrativeProvider>(builder: (context, provider, _) {
      final source = provider.clients
        .map((client) => _Client(client.id, client.name,
          client.companyName, client.location, client.isActive))
        .toList();
      final clients = source.where((client) {
        return '${client.name} ${client.company} ${client.location}'
            .toLowerCase()
            .contains(_query.toLowerCase());
      }).toList();
      return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_showArchivedClients ? 'Archived Clients' : 'Clients',
                style: Theme.of(context).textTheme.titleLarge),
            TextButton.icon(
              onPressed: provider.isLoading ? null : _toggleArchivedClients,
              icon: Icon(_showArchivedClients
                  ? Icons.people_outline
                  : Icons.inventory_2_outlined),
              label: Text(_showArchivedClients ? 'Active' : 'Archived'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search clients',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (clients.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No clients match this search.')),
          ),
        ...clients.map((client) => Card(
              margin: const EdgeInsets.only(bottom: 7),
              color: AppColors.surface,
              child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () => _clientProfile(client),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(.1),
                foregroundColor: AppColors.primary,
                child: Text(client.name.isEmpty ? '?' : client.name.substring(0, 1).toUpperCase()),
              ),
              title: Text(client.name),
              subtitle: Text('${client.company} | ${client.location}'),
              trailing: PopupMenuButton<_ClientAction>(
                tooltip: 'Client actions',
                onSelected: (action) => _handleClientAction(client, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _ClientAction.edit,
                    child: Text('Edit client'),
                  ),
                  PopupMenuItem(
                    value: client.active
                        ? _ClientAction.archive
                        : _ClientAction.restore,
                    child: Text(client.active ? 'Archive client' : 'Restore client'),
                  ),
                ],
              ),
              ),
            )),
      ],
    );
    });
  }

  Widget _tasks() => Consumer<AdministrativeProvider>(
        builder: (context, provider, _) => RefreshIndicator(
          onRefresh: provider.refreshWorkspace,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
            _Title('Task Management', trailing: 'Calendar', onTap: _calendar),
            const SizedBox(height: 12),
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.tasks.isEmpty && !provider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No tasks have been created for this business.'),
              ),
            ...provider.tasks.map((task) => Card(
                margin: const EdgeInsets.only(bottom: 7),
                color: AppColors.surface,
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F0FF),
                    child: Icon(Icons.task_alt_outlined, color: AppColors.primary),
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                    '${task.clientName} · ${MaterialLocalizations.of(context).formatMediumDate(task.dueAt)}',
                  ),
                  trailing: Text(task.status.name),
                  onTap: task.needsReview
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AdministrativeDocumentReviewScreen(
                              taskId: task.id,
                              documentName: task.documentName ?? task.title,
                            ),
                          ))
                      : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AdministrativeTaskCompletionScreen(
                              taskId: task.id,
                              taskName: task.title,
                            ),
                          )),
                ),
              ).animate().fadeIn(duration: 220.ms).slideX(begin: .02, end: 0)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: provider.isLoading ? null : _createTask,
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
            ),
            const SizedBox(height: 22),
            _Title('Obligations', trailing: 'View all', onTap: _obligations),
            if (provider.obligations.isEmpty && !provider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No active obligations for this business.'),
              ),
            ...provider.obligations
                .where((obligation) => !obligation.isCompleted)
                .map((obligation) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_repeat_outlined),
                      title: Text(obligation.title),
                      subtitle: Text(
                        '${obligation.clientName} · ${MaterialLocalizations.of(context).formatMediumDate(obligation.dueAt)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Complete obligation',
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: () async {
                          try {
                            await provider.completeObligationLive(obligation.id);
                          } catch (error) {
                            if (mounted) {
                              _message('Unable to complete obligation: $error');
                            }
                          }
                        },
                      ),
                    )),
            ],
          ),
        ),
      );

  Future<void> _createTask() async {
    final provider = context.read<AdministrativeProvider>();
    final titleController = TextEditingController();
    final remarkController = TextEditingController();
    final staffFuture = provider.loadStaffing();
    String? clientId;
    String? workerId;
    var priority = 'normal';
    var dueAt = DateTime.now().add(const Duration(days: 1));
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Create Task'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Task title *',
                        border: OutlineInputBorder(),
                      ),
                    ),
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
                          child: Text('Business-wide task'),
                        ),
                        ...provider.clients.map((client) =>
                            DropdownMenuItem<String?>(
                              value: client.id,
                              child: Text(client.name),
                            )),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => clientId = value),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: staffFuture,
                      builder: (context, snapshot) => DropdownButtonFormField<String?>(
                        value: workerId,
                        decoration: const InputDecoration(
                          labelText: 'Assign to worker (optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ...(snapshot.data ?? const <Map<String, dynamic>>[])
                              .map((worker) => DropdownMenuItem<String?>(
                                    value: worker['id']?.toString(),
                                    child: Text(worker['full_name']?.toString() ??
                                        'Worker'),
                                  )),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => workerId = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => priority = value ?? 'normal'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due date'),
                      subtitle: Text(MaterialLocalizations.of(context)
                          .formatMediumDate(dueAt)),
                      trailing: const Icon(Icons.event_outlined),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: dueAt,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setDialogState(() => dueAt = date);
                        }
                      },
                    ),
                    TextField(
                      controller: remarkController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Instructions / remark',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          _message('Enter a task title.');
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await provider.createLiveTask(
                            title: title,
                            clientId: clientId,
                            workerId: workerId,
                            remark: remarkController.text,
                            priority: priority,
                            dueAt: dueAt,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (mounted) _message('Task created.');
                        } catch (error) {
                          setDialogState(() => isSaving = false);
                          _message('Unable to create task: $error');
                        }
                      },
                child: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Task'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      remarkController.dispose();
    }
  }

  Widget _finance() => const AdministrativeFinancePanel();

  Widget _more() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Title('More'),
          _moreTile(Icons.folder_outlined, 'Documents', 'Client folders and review', _documents),
          _moreTile(Icons.badge_outlined, 'Staffing', 'Workers and client assignments', _staffing),
          _moreTile(Icons.event_repeat_outlined, 'Obligations', 'Recurring compliance deadlines', _obligations),
          _moreTile(Icons.shield_outlined, 'Client Access & Security', 'Passcodes and portal access', _security),
          _moreTile(Icons.history_outlined, 'Activity Log', 'Client and document audit history', _activity),
          _moreTile(Icons.logout, 'Log out', 'End this session', _confirmLogout, destructive: true),
        ],
      );

  Widget _action(String label, IconData icon, VoidCallback onTap) => SizedBox(
        width: 175,
        child: FilledButton.tonalIcon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  Widget _moreTile(IconData icon, String title, String subtitle, VoidCallback onTap, {bool destructive = false}) => Card(
        margin: const EdgeInsets.only(bottom: 7),
        color: Theme.of(context).colorScheme.surface,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: onTap,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (destructive ? Theme.of(context).colorScheme.error : AppColors.primary).withOpacity(.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: destructive ? Theme.of(context).colorScheme.error : AppColors.primary, size: 19),
          ),
          title: Text(title, style: TextStyle(color: destructive ? Theme.of(context).colorScheme.error : null)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      );

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access this workspace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthProvider>().logout();
      if (mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
    } catch (error) {
      if (mounted) _message('Logout failed: $error');
    }
  }

  void _clientProfile(_Client client) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdministrativeClientProfileScreen(
            clientId: client.id,
            clientName: client.name,
            companyName: client.company,
            location: client.location,
          ),
        ),
      );

  Future<void> _assignDocument() async {
    final client = await _chooseClient('Choose a client to assign a document');
    if (client == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdministrativeDocumentsScreen(
        clientName: client.name,
        clientId: client.id,
        canManageDocuments: true,
      ),
    ));
  }

  Future<_Client?> _chooseClient(String title) {
    final clients = context.read<AdministrativeProvider>().clients
        .map((client) => _Client(client.id, client.name, client.companyName,
            client.location, client.isActive))
        .where((client) => client.active)
        .toList();
    if (clients.isEmpty) {
      _message('Create or load a client before continuing.');
      return Future.value(null);
    }
    return showModalBottomSheet<_Client>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(title)),
            ...clients.map((client) => ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(client.name),
                  subtitle: Text(client.company),
                  onTap: () => Navigator.of(sheetContext).pop(client),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _addClient() async {
    final businessId =
        context.read<BusinessProvider>().currentBusiness?.id ?? '';
    if (businessId.isEmpty) {
      _message('Select an administrative business before adding a client.');
      return;
    }
    try {
      await context.read<AdministrativeProvider>().loadForBusiness(businessId);
    } catch (error) {
      if (mounted) _message('Unable to load administrative business: $error');
      return;
    }
    if (!mounted) return;
    final client = await Navigator.of(context).push<AdministrativeClientRecord>(
      MaterialPageRoute(
        builder: (_) => const AdministrativeCreateClientScreen(),
      ),
    );
    if (client != null && mounted) {
      setState(() => _page = 2);
      _message('${client.name} added');
    }
  }

  Future<void> _toggleArchivedClients() async {
    final showArchived = !_showArchivedClients;
    setState(() => _showArchivedClients = showArchived);
    await context.read<AdministrativeProvider>().loadClients(
          active: !showArchived,
        );
  }

  Future<void> _handleClientAction(
    _Client client,
    _ClientAction action,
  ) async {
    if (action == _ClientAction.edit) {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AdministrativeEditClientScreen(
            clientId: client.id,
            name: client.name,
            companyName: client.company,
            location: client.location,
          ),
        ),
      );
      if (changed == true && mounted) _message('Client updated');
      return;
    }
    final restoring = action == _ClientAction.restore;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('${restoring ? 'Restore' : 'Archive'} client?'),
        content: Text(restoring
            ? '${client.name} will be returned to the active client list.'
            : '${client.name} will no longer appear in the active client list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(restoring ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final provider = context.read<AdministrativeProvider>();
      if (restoring) {
        await provider.restoreClient(client.id);
        await _toggleArchivedClients();
      } else {
        await provider.archiveClient(client.id);
      }
      if (mounted) _message('${client.name} ${restoring ? 'restored' : 'archived'}');
    } catch (error) {
      if (mounted) _message('Unable to update client: $error');
    }
  }

  void _reviewWork() => setState(() => _page = 1);

  Future<void> _documents() async {
    final client = await _chooseClient('Choose a client');
    if (client == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdministrativeDocumentsScreen(
        clientName: client.name,
        clientId: client.id,
        canManageDocuments: true,
      ),
    ));
  }

  void _obligations() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdministrativeObligationsScreen()),
      );

  void _calendar() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdministrativeCalendarScreen()),
      );

  void _staffing() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdministrativeStaffingScreen()),
      );

  void _activity() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdministrativeActivityScreen()),
      );

  Future<void> _security() async {
    final client = await _chooseClient('Choose a client to manage access');
    if (client == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdministrativeSecurityScreen(
        clientId: client.id,
        clientName: client.name,
      ),
    ));
  }

  void _workerDashboard() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdministrativeWorkerDashboardScreen()),
      );
  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _Client {
  const _Client(this.id, this.name, this.company, this.location, this.active);
  final String id;
  final String name;
  final String company;
  final String location;
  final bool active;
}

enum _ClientAction { edit, archive, restore }

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.change, this.icon, this.color,
      {this.onTap});
  final String label;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.arrow_outward, color: color.withOpacity(.7), size: 15),
            ]),
            const Spacer(),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(children: [Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall)), Text(change, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))]),
              ]),
            ),
          ),
        ),
      );
}

class _WelcomeBand extends StatelessWidget {
  const _WelcomeBand({this.businessName});
  final String? businessName;

  @override
  Widget build(BuildContext context) {
    final name = businessName?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: AppColors.secondary, width: 4)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ADMINISTRATIVE WORKSPACE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(.78),
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 5),
          Text(name?.isNotEmpty == true ? name! : 'Good to see you',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 3),
          Text('Insights and work that need your attention.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(.9),
                  )),
        ])),
        const SizedBox(width: 12),
        const Icon(Icons.space_dashboard_outlined, color: Colors.white, size: 30),
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: .06, end: 0);
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.trailing, this.onTap});
  final String text;
  final String? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
        if (trailing != null) TextButton(onPressed: onTap ?? () {}, child: Text(trailing!)),
      ]);
}

class _Chart extends StatelessWidget {
  const _Chart();
  @override
  Widget build(BuildContext context) => Container(
        height: 158,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(16),
        child: CustomPaint(painter: _ChartPainter(Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.error), child: const SizedBox.expand()),
      );
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter(this.income, this.expense);
  final Color income;
  final Color expense;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.grey.withOpacity(.2);
    for (var i = 0; i < 4; i++) canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), grid);
    _line(canvas, size, const [.72, .65, .67, .48, .54, .31, .2], income);
    _line(canvas, size, const [.84, .78, .7, .72, .63, .54, .4], expense);
  }
  void _line(Canvas canvas, Size size, List<double> values, Color color) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(size.width * i / (values.length - 1), size.height * values[i]);
      if (i == 0) path.moveTo(point.dx, point.dy); else path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
  }
  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => false;
}

class _Activity extends StatelessWidget {
  const _Activity(this.icon, this.title, this.detail, this.time, this.color);
  final IconData icon;
  final String title;
  final String detail;
  final String time;
  final Color color;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color, size: 18)),
        title: Text(title), subtitle: Text(detail), trailing: Text(time, style: Theme.of(context).textTheme.labelSmall),
      );
}

class _Task extends StatelessWidget {
  const _Task(this.title, this.client, this.due, this.color, {this.onTap});
  final String title;
  final String client;
  final String due;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(Icons.description_outlined, color: color, size: 18)),
        title: Text(title), subtitle: Text(client), trailing: Text(due, style: TextStyle(color: color, fontSize: 11)),
      );
}

class _Finance extends StatelessWidget {
  const _Finance(this.title, this.detail, this.amount, this.color);
  final String title;
  final String detail;
  final String amount;
  final Color color;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, title: Text(title), subtitle: Text(detail), trailing: Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w700)));
}
