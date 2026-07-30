import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../data/models/inventory_alert_model.dart';
import '../../../providers/inventory_alerts_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/custom_app_bar.dart';

class InventoryAlertsScreen extends StatefulWidget {
  const InventoryAlertsScreen({super.key});

  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen>
    with SingleTickerProviderStateMixin {
  late InventoryAlertsProvider alertsProvider;
  late TabController _tabController;
  // final String _filterSeverity = 'all'; // all, critical, warning

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    alertsProvider = context.read<InventoryAlertsProvider>();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    await alertsProvider.loadAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: CustomAppBar(
        title: 'Inventory Alerts',
        onBackPressed: () => Navigator.pop(context),
      ),
      body: Consumer<InventoryAlertsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return Column(
            children: [
              // Error banner if there is an error
              if (provider.errorMessage.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.errorMessage,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (provider.indexCreateUrl != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final url = Uri.parse(provider.indexCreateUrl!);
                            try {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open URL')));
                            }
                          },
                          icon: const Icon(Icons.open_in_new, color: Colors.white),
                          label: const Text('Create index in Firebase Console', style: TextStyle(color: Colors.white)),
                        )
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Alert summary
              _buildAlertSummary(provider),
              const SizedBox(height: 16),

              // Tab bar
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey[500],
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(
                    color: AppColors.primary,
                    width: 3,
                  ),
                  insets: EdgeInsets.symmetric(horizontal: 16),
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('All Alerts'),
                        if (provider.activeAlerts.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${provider.activeAlerts.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Critical'),
                        if (provider.criticalCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${provider.criticalCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Warning'),
                        if (provider.warningCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${provider.warningCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Tab content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadAlerts,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllAlertsTab(provider),
                      _buildCriticalAlertsTab(provider),
                      _buildWarningAlertsTab(provider),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertSummary(InventoryAlertsProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryItem(
            'Active Alerts',
            '${provider.activeAlerts.length}',
            AppColors.primary,
          ),
          _buildSummaryItem(
            'Critical',
            '${provider.criticalCount}',
            Colors.red,
          ),
          _buildSummaryItem(
            'Warning',
            '${provider.warningCount}',
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAllAlertsTab(InventoryAlertsProvider provider) {
    if (provider.activeAlerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'All inventory levels are healthy!',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.activeAlerts.length,
      itemBuilder: (context, index) {
        final alert = provider.activeAlerts[index];
        return _buildAlertCard(alert, provider);
      },
    );
  }

  Widget _buildCriticalAlertsTab(InventoryAlertsProvider provider) {
    final criticalAlerts = provider.getCriticalAlerts();

    if (criticalAlerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.thumb_up, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'No critical alerts',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: criticalAlerts.length,
      itemBuilder: (context, index) {
        final alert = criticalAlerts[index];
        return _buildAlertCard(alert, provider);
      },
    );
  }

  Widget _buildWarningAlertsTab(InventoryAlertsProvider provider) {
    final warningAlerts = provider.getWarningAlerts();

    if (warningAlerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'No warning alerts',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: warningAlerts.length,
      itemBuilder: (context, index) {
        final alert = warningAlerts[index];
        return _buildAlertCard(alert, provider);
      },
    );
  }

  Widget _buildAlertCard(
      InventoryAlert alert, InventoryAlertsProvider provider) {
    Color severityColor = Colors.grey;
    IconData severityIcon = Icons.info;

    switch (alert.severity) {
      case 'critical':
        severityColor = Colors.red;
        severityIcon = Icons.warning;
        break;
      case 'warning':
        severityColor = Colors.orange;
        severityIcon = Icons.warning_amber;
        break;
      default:
        severityColor = Colors.blue;
        severityIcon = Icons.info;
    }

    final stockPercentage = (alert.currentStock / alert.minimumThreshold) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severityColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(severityIcon, color: severityColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.productName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        alert.severity.toUpperCase(),
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${stockPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stock levels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStockInfo('Current Stock', '${alert.currentStock}'),
                _buildStockInfo('Minimum', '${alert.minimumThreshold}'),
                _buildStockInfo('Reorder Qty', '${alert.reorderQuantity}'),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: (stockPercentage / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(severityColor),
              ),
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await provider.placeReorder(alert.id, alert);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reorder placed successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Reorder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: severityColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await provider.acknowledgeAlert(alert.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Alert acknowledged'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Acknowledge'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfo(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

