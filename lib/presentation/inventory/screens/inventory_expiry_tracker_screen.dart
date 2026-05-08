import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../providers/business_provider.dart';
import '../../../services/inventory_expiry_service.dart';

class InventoryExpiryTrackerScreen extends StatefulWidget {
  const InventoryExpiryTrackerScreen({super.key});

  @override
  State<InventoryExpiryTrackerScreen> createState() =>
      _InventoryExpiryTrackerScreenState();
}

class _InventoryExpiryTrackerScreenState
    extends State<InventoryExpiryTrackerScreen> {
  final _searchController = TextEditingController();
  final _expiryService = InventoryExpiryService();

  bool _isLoading = true;
  String _filter = 'all';
  String _query = '';
  List<InventoryExpiryAlert> _alerts = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAlerts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    final business = context.read<BusinessProvider>().currentBusiness;
    if (business == null || business.id.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please select a business first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final alerts = await _expiryService.fetchAlerts(business.id);
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load expiry tracking data: $e';
        _isLoading = false;
      });
    }
  }

  List<InventoryExpiryAlert> get _filteredAlerts {
    return _alerts.where((alert) {
      if (_filter == 'expired' && !alert.isExpired) return false;
      if (_filter == 'today' && !alert.expiresToday) return false;
      if (_filter == 'critical' && !alert.expiresWithin7Days) return false;
      if (_filter == 'warning' && !alert.expiresWithin30Days) return false;

      if (_query.isEmpty) return true;
      final haystack = [
        alert.productName,
        alert.category,
        alert.unit,
        alert.batchLabel ?? '',
        alert.source,
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    final summary = _expiryService.summarize(_alerts);
    final filtered = _filteredAlerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiry Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadAlerts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (business != null)
              Text(
                business.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 12),
            _SummaryRow(summary: summary),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search product, batch, category...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('all', 'All'),
                _buildFilterChip('expired', 'Expired'),
                _buildFilterChip('today', 'Today'),
                _buildFilterChip('critical', '7 Days'),
                _buildFilterChip('warning', '30 Days'),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _StateCard(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load expiry tracking',
                subtitle: _error!,
              )
            else if (_alerts.isEmpty)
              _StateCard(
                icon: Icons.verified_rounded,
                title: 'No expiring products found',
                subtitle:
                    'Products and procurement batches with expiry dates will appear here once they are within the warning range.',
                actionLabel: 'Open Inventory',
                onAction: () => Navigator.pushNamed(context, Routes.inventory),
              )
            else if (filtered.isEmpty)
              _StateCard(
                icon: Icons.filter_alt_off_rounded,
                title: 'No matches for this filter',
                subtitle:
                    'Try a different search or filter to see the expiry items we found.',
              )
            else
              ...filtered.map((alert) => _AlertCard(alert: alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final InventoryExpiryAlertSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Expired',
            value: summary.expired.toString(),
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Today',
            value: summary.dueToday.toString(),
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Soon',
            value: summary.dueSoon.toString(),
            color: Colors.amber.shade800,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final InventoryExpiryAlert alert;

  @override
  Widget build(BuildContext context) {
    final colors = _severityColors(alert);
    final fmt = DateFormat('dd MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.badge,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  alert.isExpired
                      ? Icons.warning_rounded
                      : Icons.schedule_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.productName,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusText(alert),
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.badge,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _badgeText(alert),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _meta('Expiry', fmt.format(alert.expiryDate.toLocal())),
              _meta(
                'Quantity',
                '${alert.quantity.toStringAsFixed(alert.quantity % 1 == 0 ? 0 : 2)} ${alert.unit}',
              ),
              _meta('Category', alert.category),
              _meta(
                'Source',
                alert.isBatchTracked
                    ? 'Batch ${alert.batchLabel?.isNotEmpty == true ? alert.batchLabel : alert.batchId}'
                    : 'Inventory item',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  _AlertColors _severityColors(InventoryExpiryAlert alert) {
    if (alert.isExpired) {
      return const _AlertColors(
        background: Color(0xFFFFF1F0),
        border: Color(0xFFF5B5B1),
        badge: Color(0xFFD14334),
        text: Color(0xFF9E1C11),
      );
    }
    if (alert.expiresToday) {
      return const _AlertColors(
        background: Color(0xFFFFF5E8),
        border: Color(0xFFF2C078),
        badge: Color(0xFFE48709),
        text: Color(0xFF8A4A00),
      );
    }
    if (alert.expiresWithin7Days) {
      return const _AlertColors(
        background: Color(0xFFFFF9E8),
        border: Color(0xFFEBD37B),
        badge: Color(0xFFCC9F00),
        text: Color(0xFF7A5C00),
      );
    }
    return const _AlertColors(
      background: Color(0xFFF5FAF2),
      border: Color(0xFFBCD8A8),
      badge: Color(0xFF5F9B3D),
      text: Color(0xFF35631D),
    );
  }

  String _statusText(InventoryExpiryAlert alert) {
    if (alert.isExpired) {
      return 'This stock has expired and should be reviewed immediately.';
    }
    if (alert.expiresToday) {
      return 'This stock reaches its expiry date today.';
    }
    return 'This stock expires in ${alert.daysUntilExpiry} day${alert.daysUntilExpiry == 1 ? '' : 's'}.';
  }

  String _badgeText(InventoryExpiryAlert alert) {
    if (alert.isExpired) return 'Expired';
    if (alert.expiresToday) return 'Today';
    return '${alert.daysUntilExpiry}d';
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertColors {
  const _AlertColors({
    required this.background,
    required this.border,
    required this.badge,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color badge;
  final Color text;
}
