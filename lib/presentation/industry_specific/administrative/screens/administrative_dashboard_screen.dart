import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/notification_provider.dart';
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

  static const _clients = <_Client>[
    _Client('preview-mary', 'Mary Johnson', 'Care For Homes', 'Ikeja', true),
    _Client('preview-jala', 'Jala Smith', 'Response High', 'Ikeja', true),
    _Client('preview-pottles', 'Pottles Biy', 'Caris & Live', 'Lagos', true),
    _Client('preview-great-green', 'Great Green', 'Response Living', 'Lagos', false),
    _Client('preview-james', 'James Taylor', 'Care 4 Living', 'Ikeja', true),
  ];

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    final title = business?.name.isNotEmpty == true
        ? business!.name
        : 'Administrative Services';
    final businessId = business?.id ?? '';
    if (businessId.isNotEmpty && _loadedBusinessId != businessId) {
      _loadedBusinessId = businessId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AdministrativeProvider>().loadForBusiness(businessId);
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
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Admin Dashboard', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Insights and work that need your attention.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: const [
              _Metric('Revenue', 'NGN 4,850,000', '+7.0%', Icons.trending_up, Colors.green),
              _Metric('Expenses', 'NGN 2,940,000', '-1.0%', Icons.trending_down, Colors.red),
              _Metric('Clients', '48', '+5%', Icons.people_outline, Colors.teal),
              _Metric('Total Staff', '12', '+6%', Icons.badge_outlined, Colors.indigo),
            ],
          ),
          const SizedBox(height: 18),
          const _Title('Revenue & Expenses', trailing: 'This month'),
          const SizedBox(height: 8),
          const _Chart(),
          const SizedBox(height: 18),
          const _Title('Recent Activity', trailing: 'View all'),
          const _Activity(Icons.description_outlined, 'Document received', 'Care Plan v2.pdf', '40m ago', Colors.blue),
          const _Activity(Icons.task_alt_outlined, 'Task completed', 'Tax report review', '1h ago', Colors.green),
          const _Activity(Icons.person_search_outlined, 'Client checked', 'James T. profile', '2h ago', Colors.purple),
          const SizedBox(height: 18),
          const _Title('Quick Action'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _action('Add Client', Icons.person_add_alt_1_outlined, _addClient),
              _action('Assign Document', Icons.assignment_outlined, _assignDocument),
              _action('Create Task', Icons.add_task_outlined, () => setState(() => _page = 1)),
              _action('Review Work', Icons.rate_review_outlined, _reviewWork),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clientsPage() {
    return Consumer<AdministrativeProvider>(builder: (context, provider, _) {
      final source = provider.clients.isEmpty && provider.loadError != null
          ? _clients
          : provider.clients
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
        ...clients.map((client) => ListTile(
              onTap: () => _clientProfile(client),
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              leading: CircleAvatar(child: Text(client.name.substring(0, 1))),
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
            )),
      ],
    );
    });
  }

  Widget _tasks() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Title('Task Management', trailing: 'Calendar', onTap: _calendar),
          const SizedBox(height: 12),
          _Task(
            'Review Care Plan',
            'Mary Johnson',
            'Today, 1:00 PM',
            Colors.red,
            onTap: _completeTask,
          ),
          const _Task('Client Tax', 'Doe-Son', 'Tomorrow, 2:00 PM', Colors.orange),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => _message('Create task'), icon: const Icon(Icons.add), label: const Text('Create Task')),
          const SizedBox(height: 22),
          const _Title('Obligations', trailing: 'View all'),
          const _Task('Training Certificate', 'Care Home', '7 days left', Colors.red),
          const _Task('Medical Assessment', 'Smith Home', '7 days left', Colors.red),
        ],
      );

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
        child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label)),
      );

  Widget _moreTile(IconData icon, String title, String subtitle, VoidCallback onTap, {bool destructive = false}) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
        leading: Icon(icon, color: destructive ? Theme.of(context).colorScheme.error : null),
        title: Text(title, style: TextStyle(color: destructive ? Theme.of(context).colorScheme.error : null)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
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

  void _assignDocument() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdministrativeAssignDocumentScreen(
            documentName: 'Care Plan v2.1.pdf',
          ),
        ),
      );

  Future<void> _addClient() async {
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
    if (client.id.startsWith('preview-')) {
      _message('Preview client records cannot be changed.');
      return;
    }
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

  void _reviewWork() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdministrativeDocumentReviewScreen(
            documentName: 'Care Plan v2.1.pdf', taskId: '',
          ),
        ),
      );

  void _documents() => Navigator.of(context).push(
         MaterialPageRoute(
          builder: (_) => AdministrativeDocumentsScreen(clientName: 'Mary Johnson'),
        ),
      );

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

  void _security() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdministrativeSecurityScreen(clientName: 'Mary Johnson'),
        ),
      );

  void _completeTask() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdministrativeTaskCompletionScreen(
            taskId: 'care-plan-review',
            taskName: 'Review Care Plan',
          ),
        ),
      );

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
  const _Metric(this.label, this.value, this.change, this.icon, this.color);
  final String label;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 18),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            Row(children: [Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall)), Text(change, style: TextStyle(fontSize: 10, color: color))]),
          ]),
        ),
      );
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
