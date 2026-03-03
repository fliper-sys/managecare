import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/backup_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/custom_app_bar.dart';

class BackupAndRestoreScreen extends StatefulWidget {
  const BackupAndRestoreScreen({super.key});

  @override
  State<BackupAndRestoreScreen> createState() => _BackupAndRestoreScreenState();
}

class _BackupAndRestoreScreenState extends State<BackupAndRestoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBackups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadBackups() {
    Future.microtask(
      () => context.read<BackupProvider>().loadBackups(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Backup & Restore',
        showBackButton: true,
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Create Backup'),
              Tab(text: 'Backups'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateBackupTab(),
                _buildBackupsListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateBackupTab() {
    return Consumer<BackupProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What to backup',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildBackupOption(
                context,
                provider,
                'Business Data',
                'All business information and settings',
                provider.backupBusinessData,
                (value) => provider.setBackupBusinessData(value),
                Icons.business,
              ),
              _buildBackupOption(
                context,
                provider,
                'Sales Records',
                'All sales and transaction history',
                provider.backupSalesData,
                (value) => provider.setBackupSalesData(value),
                Icons.receipt,
              ),
              _buildBackupOption(
                context,
                provider,
                'Inventory',
                'Products, stock, and inventory data',
                provider.backupInventory,
                (value) => provider.setBackupInventory(value),
                Icons.inventory,
              ),
              _buildBackupOption(
                context,
                provider,
                'Customers',
                'Customer profiles and contacts',
                provider.backupCustomers,
                (value) => provider.setBackupCustomers(value),
                Icons.people,
              ),
              _buildBackupOption(
                context,
                provider,
                'Reports',
                'Generated reports and analytics',
                provider.backupReports,
                (value) => provider.setBackupReports(value),
                Icons.analytics,
              ),
              _buildBackupOption(
                context,
                provider,
                'Settings',
                'App settings and preferences',
                provider.backupSettings,
                (value) => provider.setBackupSettings(value),
                Icons.settings,
              ),
              const SizedBox(height: 24),
              Text(
                'Backup Destination',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDestinationOption(
                context,
                provider,
                'Local Storage',
                'Save to device storage',
                BackupDestination.local,
                provider.destination,
                (value) => provider.setDestination(value),
              ),
              _buildDestinationOption(
                context,
                provider,
                'Cloud (Firebase)',
                'Save to Firebase Cloud Storage',
                BackupDestination.cloud,
                provider.destination,
                (value) => provider.setDestination(value),
              ),
              _buildDestinationOption(
                context,
                provider,
                'Both',
                'Save to both local and cloud',
                BackupDestination.both,
                provider.destination,
                (value) => provider.setDestination(value),
              ),
              const SizedBox(height: 24),
              if (provider.isBackingUp)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Creating backup...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showBackupConfirmDialog(context),
                        icon: const Icon(Icons.backup),
                        label: const Text('Create Backup'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackupsListTab() {
    return Consumer<BackupProvider>(
      builder: (context, provider, _) {
        if (provider.backups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.backup,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Backups',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first backup to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[400],
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: provider.backups.length,
          itemBuilder: (context, index) {
            final backup = provider.backups[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              backup.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(backup.createdAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getDestinationColor(backup.destination),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getDestinationLabel(backup.destination),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Size: ${_formatSize(backup.size)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showRestoreConfirmDialog(context, backup),
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('Restore'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showDeleteConfirmDialog(
                                  context, provider, backup),
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBackupOption(
    BuildContext context,
    BackupProvider provider,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationOption(
    BuildContext context,
    BackupProvider provider,
    String title,
    String subtitle,
    BackupDestination destination,
    BackupDestination currentDestination,
    Function(BackupDestination) onChanged,
  ) {
    final isSelected = destination == currentDestination;

    return GestureDetector(
      onTap: () => onChanged(destination),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected ? Colors.blue : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Colors.blue.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<BackupDestination>(
              value: destination,
              groupValue: currentDestination,
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Backup'),
        content: const Text(
          'This will create a backup of your selected data. Depending on the size, this may take a few moments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await context.read<BackupProvider>().createBackup();

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup created successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to create backup'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRestoreConfirmDialog(BuildContext context, Backup backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Text(
          'This will restore your data from the backup created on ${_formatDate(backup.createdAt)}. Current data may be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await context.read<BackupProvider>().restoreBackup(backup);

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup restored successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to restore backup'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    BackupProvider provider,
    Backup backup,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text(
          'Are you sure you want to delete the backup from ${_formatDate(backup.createdAt)}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.deleteBackup(backup);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backup deleted'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Color _getDestinationColor(BackupDestination destination) {
    switch (destination) {
      case BackupDestination.local:
        return Colors.blue;
      case BackupDestination.cloud:
        return Colors.purple;
      case BackupDestination.both:
        return Colors.green;
    }
  }

  String _getDestinationLabel(BackupDestination destination) {
    switch (destination) {
      case BackupDestination.local:
        return 'Local';
      case BackupDestination.cloud:
        return 'Cloud';
      case BackupDestination.both:
        return 'Both';
    }
  }
}

