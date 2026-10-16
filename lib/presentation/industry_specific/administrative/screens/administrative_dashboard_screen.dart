import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/constants/business_types.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../providers/theme_provider.dart';
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
        surfaceTintColor: Colors.transparent,
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
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: themeProvider.isDarkMode ? 'Switch to light theme' : 'Switch to dark theme',
                child: Material(
                  color: Theme.of(context).colorScheme.primary.withOpacity(.1),
                  shape: const CircleBorder(),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: themeProvider.toggleTheme,
                    icon: Icon(themeProvider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                  ),
                ),
              ),
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
        final hasDashboardMetrics = metrics.isNotEmpty;
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
                  ?.name,
                onRefresh: provider.refreshWorkspace,
              ),
              const SizedBox(height: 16),
              if (provider.loadError != null)
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: Icon(Icons.cloud_off_outlined,
                        color: theme.colorScheme.error),
                    title: const Text('Some workspace data did not load'),
                    subtitle: const Text('Check your connection and try again.'),
                    trailing: IconButton(
                      tooltip: 'Retry loading workspace',
                      onPressed: provider.refreshWorkspace,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              if (provider.isLoading && !hasDashboardMetrics)
                const LinearProgressIndicator(minHeight: 2),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.75,
                children: [
                  _Metric('Revenue', hasDashboardMetrics ? _adminCurrency(metrics['revenue']) : '—', 'Finance', Icons.trending_up, AppColors.secondary, onTap: () => setState(() => _page = 3)),
                  _Metric('Expenses', hasDashboardMetrics ? _adminCurrency(metrics['expenses']) : '—', 'Finance', Icons.trending_down, AppColors.error, onTap: () => setState(() => _page = 3)),
                  _Metric('Clients', '${metrics['clients'] ?? provider.clients.length}', 'Directory', Icons.people_outline, AppColors.primary, onTap: () => setState(() => _page = 2)),
                  _Metric('Total Staff', metrics['staff'] == null ? '—' : '${metrics['staff']}', 'Staffing', Icons.badge_outlined, AppColors.accentDark, onTap: _staffing),
                ],
              ).animate().fadeIn(duration: 350.ms).slideY(begin: .04, end: 0),
              const SizedBox(height: 18),
              _Title('Tasks needing attention', trailing: 'View all', onTap: () => setState(() => _page = 1)),
              if (tasksNeedingAttention.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No tasks need attention.'),
                ),
              ...tasksNeedingAttention.map((task) => Card(child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: theme.colorScheme.surface,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(task.needsReview ? Icons.rate_review_outlined : Icons.task_alt_outlined),
                    title: Text(task.title),
                    subtitle: Text('${task.clientName} · ${task.status.name}'),
                    onTap: () => setState(() => _page = 1),
                  )).animate().fadeIn(duration: 260.ms).slideX(begin: .025, end: 0)),
              const SizedBox(height: 18),
              const _Title('Quick actions'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _action('Add client', Icons.person_add_alt_1_outlined, _addClient),
                  const SizedBox(width: 10),
                  _action('Assign document', Icons.assignment_outlined, _assignDocument),
                  const SizedBox(width: 10),
                  _action('Create task', Icons.add_task_outlined, () => setState(() => _page = 1)),
                  const SizedBox(width: 10),
                  _action('Review work', Icons.rate_review_outlined, _reviewWork),
                  const SizedBox(width: 10),
                  _action('Record revenue', Icons.trending_up, () => setState(() => _page = 3)),
                  const SizedBox(width: 10),
                  _action('Record expense', Icons.trending_down, () => setState(() => _page = 3)),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  String _adminCurrency(Object? value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null) return '—';
    return '₦${amount.toStringAsFixed(2)}';
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
      return RefreshIndicator(
        onRefresh: provider.refreshWorkspace,
        child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(_showArchivedClients ? 'Archived clients' : 'Clients',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              tooltip: _showArchivedClients ? 'Show active clients' : 'Show archived clients',
              onPressed: provider.isLoading ? null : _toggleArchivedClients,
              icon: Icon(_showArchivedClients ? Icons.people_outline : Icons.inventory_2_outlined),
            ),
            IconButton(
              tooltip: 'Add client',
              onPressed: provider.isLoading ? null : _addClient,
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search clients',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (clients.isEmpty)
          _InlineEmpty(icon: Icons.people_outline, message: provider.isLoading ? 'Loading clients...' : _query.isEmpty ? 'No clients yet.' : 'No clients match this search.'),
        ...clients.map((client) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: Theme.of(context).cardColor,
              child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onTap: () => _clientProfile(client),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(.1),
                foregroundColor: AppColors.primary,
                child: Text(client.name.isEmpty ? '?' : client.name.substring(0, 1).toUpperCase()),
              ),
              title: Text(client.name),
              subtitle: Text([client.company, client.location].where((value) => value.trim().isNotEmpty).join(' · ')),
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
    ));
    });
  }

  Widget _tasks() => Consumer<AdministrativeProvider>(
        builder: (context, provider, _) => RefreshIndicator(
          onRefresh: provider.refreshWorkspace,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
            _Title('Tasks', trailing: 'Calendar', onTap: _calendar),
            const SizedBox(height: 12),
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.tasks.isEmpty && !provider.isLoading)
              const _InlineEmpty(icon: Icons.task_alt_outlined, message: 'No tasks have been created yet.'),
            ...provider.tasks.map((task) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Theme.of(context).cardColor,
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(.1), child: const Icon(Icons.task_alt_outlined, color: AppColors.primary)),
                  title: Text(task.title),
                  subtitle: Text(
                    '${task.clientName} · ${MaterialLocalizations.of(context).formatMediumDate(task.dueAt)}',
                  ),
                  trailing: _TaskStatus(task: task),
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
          _moreTile(Icons.folder_outlined, 'Documents', 'Client files, folders, and review', _documents),
          _moreTile(Icons.badge_outlined, 'Staffing', 'Workers and client assignments', _staffing),
          _moreTile(Icons.event_repeat_outlined, 'Obligations', 'Upcoming and completed deadlines', _obligations),
          _moreTile(Icons.receipt_long_outlined, 'Invoices', 'Create and manage client invoices', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdministrativeInvoicesScreen()))),
          _moreTile(Icons.shield_outlined, 'Client Access', 'Passcodes and portal credentials', _security),
          _moreTile(Icons.history_outlined, 'Activity Log', 'Workspace audit history', _activity),
          _moreTile(Icons.calendar_month_outlined, 'Calendar', 'Tasks, events, and due dates', _calendar),
          _moreTile(Icons.logout, 'Log out', 'End this session', _confirmLogout, destructive: true),
        ],
      );

  Widget _action(String label, IconData icon, VoidCallback onTap) => SizedBox(
        width: 142,
        height: 78,
        child: Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconTile(icon: icon, color: AppColors.primary, size: 32),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _moreTile(IconData icon, String title, String subtitle, VoidCallback onTap, {bool destructive = false}) => Card(
        margin: const EdgeInsets.only(bottom: 7),
        color: Theme.of(context).colorScheme.surface,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onTap,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (destructive ? Theme.of(context).colorScheme.error : AppColors.primary).withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
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
              borderRadius: BorderRadius.circular(14),
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
  const _WelcomeBand({this.businessName, this.onRefresh});
  final String? businessName;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final name = businessName?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF102747),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1D3A60)),
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
        IconButton(
          tooltip: 'Refresh workspace',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
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
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface))),
        if (trailing != null) TextButton(onPressed: onTap, child: Text(trailing!)),
      ]);
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          ],
        ),
      );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: size * .52),
        ),
      );
}

class _TaskStatus extends StatelessWidget {
  const _TaskStatus({required this.task});
  final AdministrativeTask task;

  @override
  Widget build(BuildContext context) {
    final color = task.needsReview
        ? const Color(0xFFE9A23B)
        : task.isOpen
            ? const Color(0xFF2563EB)
            : const Color(0xFF16A36A);
    final label = task.needsReview
        ? 'Review'
        : task.status.name == 'inProgress'
            ? 'In progress'
            : task.status.name[0].toUpperCase() + task.status.name.substring(1);
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(9)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
