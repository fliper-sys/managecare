import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../../providers/admin_provider.dart';
import '../../services/whatsapp_service.dart';
import '../../services/report_service.dart';
import '../../services/email_service.dart';
import '../../../core/utils/datetime_utils.dart';
import '../admin_theme.dart';

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class AllBusinessesPage extends StatefulWidget {
  const AllBusinessesPage({super.key});

  @override
  State<AllBusinessesPage> createState() => _AllBusinessesPageState();
}

class _AllBusinessesPageState extends State<AllBusinessesPage> {
  late TextEditingController _searchController;
  String _filterTier = 'all';
  bool _filterActive = false;
  // Selected business IDs for combined actions (sending reports)
  final Set<String> _selectedBusinessIds = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.adminBackground,
      appBar: AppBar(
        title: const Text('All Businesses'),
        elevation: 0,
        backgroundColor: context.adminSurface,
        foregroundColor: context.adminTextPrimary,
      ),
      floatingActionButton: _selectedBusinessIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _sendCombinedDailyReport(context),
              icon: const Icon(Icons.send),
              label: Text('Send Combined (${_selectedBusinessIds.length})'),
              backgroundColor: const Color(0xFF3B82F6),
            )
          : null,
      body: Consumer<AdminProvider>(
        builder: (context, admin, _) {
          if (admin.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final businesses = _filterBusinesses(admin.allBusinesses);

          return SingleChildScrollView(
            child: Column(
              children: [
                // Search and Filter
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name, owner, or type...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: context.adminSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.adminBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.adminBorder),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Filters
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterChip(
                              'Tier',
                              _filterTier,
                              ['all', 'tier1', 'tier2', 'tier3'],
                              (value) => setState(() => _filterTier = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilterChip(
                              label: Text(
                                _filterActive ? 'Active Only' : 'All Status',
                              ),
                              selected: _filterActive,
                              onSelected: (value) =>
                                  setState(() => _filterActive = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Business List
                if (businesses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.business_rounded,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No businesses found',
                            style: TextStyle(
                              fontSize: 16,
                              color: context.adminTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: businesses.length,
                    itemBuilder: (context, index) {
                      final business = businesses[index];
                      return _buildBusinessTile(context, business);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String selected, List<String> options,
      Function(String) onSelect) {
    return GestureDetector(
      onTap: () => _showFilterMenu(context, label, options, onSelect),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.adminSurface,
          border: Border.all(color: context.adminBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label: ${selected.toUpperCase()}',
              style: TextStyle(
                fontSize: 12,
                color: context.adminTextPrimary,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: context.adminTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu(BuildContext context, String label, List<String> options,
      Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.adminSurface,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Filter by $label',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...options.map((option) => ListTile(
                title: Text(option.toUpperCase()),
                onTap: () {
                  onSelect(option);
                  Navigator.pop(ctx);
                },
              )),
        ],
      ),
    );
  }

  Widget _buildBusinessTile(
      BuildContext context, Map<String, dynamic> business) {
    final name = business['name'] ?? 'Unknown';
    final owner = business['ownerName'] ?? 'Unknown';
    final type = business['businessType'] ?? 'General';
    final businessClass = business['businessClass']?.toString().toLowerCase() ?? 'tier1';
    final isActive = business['isActive'] ?? true;
    final isDeleted = business['isDeleted'] == true;
    final workers = business['totalWorkers'] ?? 0;

    Color classColor;
    if (businessClass == 'tier3') {
      classColor = const Color(0xFFF59E0B);
    } else if (businessClass == 'tier2') {
      classColor = const Color(0xFF8B5CF6);
    } else {
      classColor = const Color(0xFF3B82F6);
    }

    final idVal = (business['id'] ?? business['businessId'])?.toString() ?? '';
    final isSelected = _selectedBusinessIds.contains(idVal);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    if (idVal.isNotEmpty) _selectedBusinessIds.add(idVal);
                  } else {
                    _selectedBusinessIds.remove(idVal);
                  }
                });
              },
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: classColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.business_rounded, color: classColor),
            ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.adminTextPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$owner • $type',
              style: TextStyle(
                fontSize: 12,
                color: context.adminTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: classColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    businessClass.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: classColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'INACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                      ),
                    ),
                if (isDeleted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DELETED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '$workers workers',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.adminTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: context.adminTextTertiary,
        ),
        onTap: () => _showBusinessDetails(context, business),
      ),
    );
  }

  void _showBusinessDetails(
      BuildContext context, Map<String, dynamic> business) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => BusinessDetailPage(business: business),
      ),
    );
  }

  /// Send a combined daily transactions email grouped by owner email for the selected businesses.
  Future<void> _sendCombinedDailyReport(BuildContext context) async {
    if (_selectedBusinessIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final emailSvc = EmailService();

    messenger.showSnackBar(const SnackBar(content: Text('Preparing combined report...')));

    // Build a map of selected business objects
    final selected = admin.allBusinesses.where((b) {
      final id = (b['id'] ?? b['businessId'])?.toString() ?? '';
      return id.isNotEmpty && _selectedBusinessIds.contains(id);
    }).toList();

    if (selected.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('No selected businesses available')));
      return;
    }

    // Group businesses by owner email (resolve from business['ownerEmail'] or ownerId -> user email)
    final Map<String, List<Map<String, dynamic>>> byOwner = {};
    final List<String> skipped = [];

    for (var b in selected) {
      String? ownerEmail =
          (b['ownerEmail'] ?? b['owner_email'] ?? b['email'])?.toString().trim();
      if ((ownerEmail == null || ownerEmail.isEmpty) &&
          (b['ownerId'] != null || b['owner_id'] != null)) {
        final ownerId = (b['ownerId'] ?? b['owner_id'])?.toString();
        final ownerUser = admin.allUsers.firstWhere(
            (u) => (u['id'] ?? '') == ownerId,
            orElse: () => {});
        ownerEmail = ownerUser['email']?.toString().trim();
      }
      if (ownerEmail == null || ownerEmail.isEmpty) {
        skipped.add((b['name'] ?? b['businessId'] ?? 'Unknown').toString());
        continue;
      }
      byOwner.putIfAbsent(ownerEmail, () => []).add(b);
    }

    if (byOwner.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('No owner emails found for selected businesses. Skipped: ${skipped.join(', ')}')));
      return;
    }

    bool allOk = true;

    for (final entry in byOwner.entries) {
      final ownerEmail = entry.key;
      final bizList = entry.value;

      // Collect transactions across businesses
      final List<Map<String, dynamic>> combinedTransactions = [];
      for (var b in bizList) {
        final bizId = (b['id'] ?? b['businessId'])?.toString() ?? '';
        try {
          final summary = await admin.getDailySalesSummary(bizId, DateTime.now());
          final txs = List<Map<String, dynamic>>.from((summary['transactions'] ?? []));
          final bizName = b['name'] ?? bizId;
          for (var t in txs) {
            final total = (t['total'] ?? t['totalAmount'] ?? t['amount'] ?? 0).toDouble();
            final cashier = t['cashier'] ?? t['cashierName'] ?? '';
            final createdAt = t['createdAt'] ?? t['createdAt'] ?? '';
            final rawItems = t['items'] as List<dynamic>? ?? [];
            final itemSummary = rawItems.map((it) {
              final nm = it['productName'] ?? it['product_name'] ?? it['name'] ?? '';
              final qty = (it['quantity'] ?? it['qty'] ?? 0);
              return '$nm x$qty';
            }).join(', ');
            combinedTransactions.add({
              'note': '$bizName • ${createdAt.toString()} • $cashier • $itemSummary',
              'amount': total,
            });
          }
        } catch (e) {
          // ignore per-business fetch errors
        }
      }

      // Prepare email payload
      final bizNames = bizList.map((b) => b['name'] ?? '').where((s) => (s ?? '').toString().isNotEmpty).toList();
      final businessNameForEmail = bizNames.isEmpty ? 'Multiple Businesses' : bizNames.join(', ');
      final dateStr = DateTime.now().toIso8601String().split('T').first;

      final data = {
        'businessName': businessNameForEmail,
        'date': dateStr,
        'transactions': combinedTransactions,
      };

      messenger.showSnackBar(SnackBar(content: Text('Sending combined report to $ownerEmail...')));
      final ok = await emailSvc.sendTemplateEmail('daily_transactions', ownerEmail, data, subject: 'Daily Transactions Report — $dateStr');
      if (!ok) allOk = false;
    }

    messenger.showSnackBar(SnackBar(content: Text(allOk ? 'Combined daily reports sent.' : 'Some reports failed to send.')));

    // Clear selection after send
    setState(() {
      _selectedBusinessIds.clear();
    });
  }

  List<Map<String, dynamic>> _filterBusinesses(
      List<Map<String, dynamic>> businesses) {
    return businesses.where((business) {
      final name = business['name']?.toString().toLowerCase() ?? '';
      final owner = business['ownerName']?.toString().toLowerCase() ?? '';
      final type = business['businessType']?.toString().toLowerCase() ?? '';
      final businessClass = business['businessClass']?.toString().toLowerCase() ?? 'tier1';
      final isRestricted = business['isRestricted'] == true ||
          (business['restrictionStatus']?.toString().toLowerCase() == 'restricted');
      final hasActiveSubscription = business['isSubscriptionActive'] == true ||
          business['hasActiveSubscription'] == true;
      final isActive =
          (business['isActive'] ?? true) == true &&
          !isRestricted &&
          business['isDeleted'] != true &&
          hasActiveSubscription;

      final searchQuery = _searchController.text.toLowerCase();
      final matchesSearch = name.contains(searchQuery) ||
          owner.contains(searchQuery) ||
          type.contains(searchQuery);

      final matchesTier = _filterTier == 'all' || businessClass.contains(_filterTier.toLowerCase());
      final matchesActive = !_filterActive || isActive;

      return matchesSearch && matchesTier && matchesActive;
    }).toList();
  }
}

class BusinessDetailPage extends StatelessWidget {
  final Map<String, dynamic> business;

  const BusinessDetailPage({
    super.key,
    required this.business,
  });

  @override
  Widget build(BuildContext context) {
    final businessClass = business['businessClass']?.toString().toLowerCase() ?? 'tier1';
    final isDeleted = business['isDeleted'] == true;
    Color tierColor;
    if (businessClass == 'tier3') {
      tierColor = const Color(0xFFF59E0B);
    } else if (businessClass == 'tier2') {
      tierColor = const Color(0xFF8B5CF6);
    } else {
      tierColor = const Color(0xFF3B82F6);
    }

    return Scaffold(
      backgroundColor: context.adminBackground,
      appBar: AppBar(
        title: const Text('Business Details'),
        elevation: 0,
        backgroundColor: context.adminSurface,
        foregroundColor: context.adminTextPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tierColor, tierColor.withOpacity(0.6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business['name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    business['businessType'] ?? 'General',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${businessClass.toUpperCase()} Plan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Business Information
            _buildSection(
              context,
              'Business Information',
              [
                _buildInfoRow(context, 'Owner Name', business['ownerName'] ?? '-'),
                _buildInfoRow(context, 'Email', business['email'] ?? '-'),
                _buildInfoRow(context, 'Phone', business['phone'] ?? '-'),
                _buildInfoRow(context, 'Business Type', business['businessType'] ?? '-'),
                _buildInfoRow(
                  context,
                  'Total Workers',
                  '${business['totalWorkers'] ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Subscription Information with Edit Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subscription Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showEditSubscriptionDialog(context, business),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(context, 'Business Class', businessClass.toUpperCase()),
                _buildInfoRow(
                  context,
                  'Status',
                  isDeleted
                      ? 'Deleted (admin recovery only)'
                      : (business['isActive'] == true ? 'Active' : 'Inactive'),
                ),
                _buildInfoRow(
                    context,
                    'Created At', _formatTimestamp(business['createdAt'])),
                _buildInfoRow(
                    context,
                    'Updated At', _formatTimestamp(business['updatedAt'])),
              ],
            ),
            const SizedBox(height: 20),

            // Features (if available) - defaults to an empty JSONB object
            // ('{}') on the backend when unset, not an array, so guard the
            // cast rather than assuming list shape whenever it's non-null.
            if (business['features'] is List &&
                (business['features'] as List).isNotEmpty)
              _buildSection(
                context,
                'Enabled Features',
                [
                  ...(business['features'] as List)
                      .map((feature) => _buildFeatureRow(feature.toString()))
                ],
              ),
            const SizedBox(height: 12),

            // Workers section
            _buildSection(
              context,
              'Workers',
              [
                _buildWorkersList(context, business),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDeleted ? null : () => _editBusiness(context, business),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isDeleted ? null : () => _toggleStatus(context, business),
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(
                      business['isActive'] == true ? 'Deactivate' : 'Activate',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isDeleted ? null : () => _showDailySales(context),
                    icon: const Icon(Icons.message),
                    label: const Text('Daily Sales'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      side: const BorderSide(color: Color(0xFF3B82F6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isDeleted
                    ? () => _restoreDeletedBusiness(context, business)
                    : () => _deleteBusinessCompletely(context, business),
                icon: Icon(
                  isDeleted ? Icons.restore_rounded : Icons.delete_forever,
                ),
                label: Text(
                  isDeleted ? 'Restore Business' : 'Delete Business',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDeleted ? Colors.green : Colors.red,
                  side: BorderSide(
                    color: isDeleted ? Colors.green : Colors.red,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isDeleted ? null : () async {
                  final admin = Provider.of<AdminProvider>(context, listen: false);
                  final businessId = business['id'] ?? business['businessId'];
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Grant Yearly Subscription'),
                      content: const Text('Activate a yearly subscription for all workers of this business? This will mark their records to avoid access restrictions.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                      ],
                    ),
                  );
                  if (confirmed != true) return;

                  // show progress
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: CircularProgressIndicator()),
                  );

                  final ok = await admin.activateYearlySubscriptionForWorkers(businessId);

                  Navigator.pop(context); // remove progress
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Workers updated with yearly subscription.' : 'Failed to update workers.')),
                  );
                },
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Grant Yearly Subscription to Workers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSubscriptionDialog(BuildContext context, Map<String, dynamic> business) {
    final businessId = business['id'] ?? business['businessId'];
    final currentClass = business['businessClass']?.toString().toLowerCase() ?? 'tier1';
    final isActive = business['isActive'] ?? true;
    final maxWorkers = (business['maxWorkers'] ?? 50) as int;
    final rawFeatures = business['features'];
    final currentFeatures =
        List<String>.from(rawFeatures is List ? rawFeatures : []);
    
    String selectedClass = currentClass;
    bool selectedActive = isActive;
    int selectedMaxWorkers = maxWorkers;
    List<String> selectedFeatures = [...currentFeatures];
    
    final availableFeatures = [
      'Inventory Management',
      'Customer Database',
      'Sales Reports',
      'Staff Management',
      'WhatsApp Integration',
      'SMS Notifications',
      'Email Marketing',
      'Advanced Analytics',
      'Multi-location',
      'API Access',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_membership, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Subscription Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Class
                      const Text('Business Class', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: selectedClass,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [
                            DropdownMenuItem(
                              value: 'tier1',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Tier 1 - Basic', style: TextStyle(fontWeight: FontWeight.w500)),
                                  Text('50 workers, Basic features', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'tier2',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Tier 2 - Professional', style: TextStyle(fontWeight: FontWeight.w500)),
                                  Text('200 workers, Advanced features', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'tier3',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Tier 3 - Enterprise', style: TextStyle(fontWeight: FontWeight.w500)),
                                  Text('Unlimited workers, All features', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedClass = value;
                                // Auto-update max workers based on tier
                                if (value == 'tier1') selectedMaxWorkers = 50;
                                else if (value == 'tier2') selectedMaxWorkers = 200;
                                else selectedMaxWorkers = 999;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Max Workers
                      const Text('Max Workers Allowed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(text: selectedMaxWorkers.toString()),
                              onChanged: (value) {
                                final parsed = int.tryParse(value) ?? selectedMaxWorkers;
                                setState(() => selectedMaxWorkers = parsed);
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                suffix: Text(selectedClass == 'tier3' ? '(Unlimited)' : ''),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Status
                      const Text('Subscription Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: Text(selectedActive ? 'Active' : 'Inactive'),
                        subtitle: Text(selectedActive ? 'Business can access all features' : 'Business access restricted'),
                        value: selectedActive,
                        onChanged: (value) => setState(() => selectedActive = value),
                        contentPadding: EdgeInsets.zero,
                        tileColor: selectedActive ? Colors.green[50] : Colors.red[50],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(height: 20),

                      // Features
                      const Text('Enabled Features', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableFeatures.map((feature) {
                            final isSelected = selectedFeatures.contains(feature);
                            return FilterChip(
                              label: Text(feature),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedFeatures.add(feature);
                                  } else {
                                    selectedFeatures.remove(feature);
                                  }
                                });
                              },
                              backgroundColor: context.adminSurface,
                              selectedColor: const Color(0xFF3B82F6),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : context.adminTextPrimary,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          
                          try {
                            final admin = Provider.of<AdminProvider>(
                              context,
                              listen: false,
                            );
                            final ok = await admin.updateBusiness(businessId, {
                              'businessClass': selectedClass,
                              'isActive': selectedActive,
                              'maxWorkers': selectedMaxWorkers,
                              'features': selectedFeatures,
                            });
                            if (!ok) {
                              throw Exception(admin.errorMessage ??
                                  'Unable to update business');
                            }
                            
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('✓ Subscription details updated successfully'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('✗ Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkersList(BuildContext context, Map<String, dynamic> business) {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final businessId = (business['id'] ?? business['businessId'])?.toString() ?? '';
    
    // Get workers - they may not have role='worker', try multiple conditions
    final workers = admin.allUsers.where((u) {
      final uBusinessId = (u['businessId'] ?? '').toString();
      final uRole = (u['role'] ?? '').toString().toLowerCase();
      final uType = (u['userType'] ?? '').toString().toLowerCase();
      
      // Match if businessId matches AND (role is 'worker' OR userType is 'worker' OR role is not 'owner'/'admin')
      return uBusinessId == businessId && 
             (uRole == 'worker' || uType == 'worker' || (uRole != 'owner' && uRole != 'admin' && uRole.isNotEmpty));
    }).toList();

    if (workers.isEmpty) {
      final totalWorkers = (business['totalWorkers'] ?? 0) as int;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              totalWorkers > 0 
                  ? 'Loading workers... ($totalWorkers expected)'
                  : 'No workers assigned to this business.',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Workers: ${workers.length}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(workers.where((w) => (w['hasActiveSubscription'] == true) || (parseTimestamp(w['subscriptionEndDate']).isAfter(DateTime.now()))).length)}/${workers.length} Active',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            itemCount: workers.length,
            itemBuilder: (ctx, i) {
              final w = workers[i];
              final name = (w['name'] ?? w['displayName'] ?? w['email'] ?? 'Worker').toString();
              final email = (w['email'] ?? '').toString();
              final phone = (w['phone'] ?? '').toString();
              final role = (w['role'] ?? w['userType'] ?? 'worker').toString();
              final hasActive = (w['hasActiveSubscription'] == true) || (parseTimestamp(w['subscriptionEndDate']).isAfter(DateTime.now()) == true);
              final joinDate = w['createdAt'] != null ? _formatTimestamp(w['createdAt']) : 'Unknown';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: context.adminBorder),
                  borderRadius: BorderRadius.circular(8),
                  color: context.adminSurface,
                ),
                child: ListTile(
                  dense: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'W',
                      style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(email, style: const TextStyle(fontSize: 11)),
                      if (phone.isNotEmpty)
                        Text(phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Row(
                        children: [
                          Text(
                            'Joined: $joinDate',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: role.toLowerCase() == 'admin' ? Colors.purple[100] : Colors.blue[100],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: role.toLowerCase() == 'admin' ? Colors.purple[800] : Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: hasActive
                            ? null
                            : () async {
                                final adminProv = Provider.of<AdminProvider>(context, listen: false);
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dctx) => AlertDialog(
                                    title: const Text('Grant Yearly Subscription'),
                                    content: Text('Grant a yearly subscription to $name?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Confirm')),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;

                                showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                final ok = await adminProv.activateYearlySubscriptionForWorker(w['id'] ?? w['uid'] ?? w['userId'], businessId);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '✓ Subscription granted to $name' : '✗ Failed to grant subscription')));
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasActive ? Colors.grey : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        child: Text(
                          hasActive ? 'Active' : 'Grant',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      if (hasActive)
                        Text(
                          'Until: ${w['subscriptionEndDate'] != null ? _formatTimestamp(w['subscriptionEndDate']) : '∞'}',
                          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  onTap: () => _showWorkerDetailsDialog(context, w, businessId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showWorkerDetailsDialog(BuildContext context, Map<String, dynamic> worker, String businessId) {
    final name = (worker['name'] ?? worker['displayName'] ?? worker['email'] ?? 'Worker').toString();
    final email = (worker['email'] ?? '').toString();
    final phone = (worker['phone'] ?? '').toString();
    final role = (worker['role'] ?? worker['userType'] ?? 'worker').toString();
    final joinDate = worker['createdAt'] != null ? _formatTimestamp(worker['createdAt']) : 'Unknown';
    final subEndDate = worker['subscriptionEndDate'] != null ? _formatTimestamp(worker['subscriptionEndDate']) : 'N/A';
    final lastActive = worker['lastActive'] != null ? _formatTimestamp(worker['lastActive']) : 'Never';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(context, 'Email', email),
            const SizedBox(height: 8),
            if (phone.isNotEmpty) ...[
              _buildInfoRow(context, 'Phone', phone),
              const SizedBox(height: 8),
            ],
            _buildInfoRow(context, 'Role', role.toUpperCase()),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Joined', joinDate),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Subscription Until', subEndDate),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Last Active', lastActive),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (role.toLowerCase() != 'admin')
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('Remove Worker'),
                    content: Text('Remove $name from this business?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                final adminProv = Provider.of<AdminProvider>(context, listen: false);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );
                final ok = await adminProv.removeWorkerFromBusiness(
                  (worker['id'] ?? worker['uid'] ?? worker['userId']).toString(),
                  businessId,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? '$name removed from business' : 'Failed to remove worker',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _showDailySales(BuildContext context, {DateTime? selectedDate}) {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final businessId = business['id'] ?? business['businessId'];
    final businessName = business['name'] ?? 'Business';
    final phone = (business['phone'] ?? '').toString();
    final dateToFetch = selectedDate ?? DateTime.now();
    final outerContext = context; // Capture outer context for date navigation

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: admin.getDailySalesSummary(businessId, dateToFetch),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError || snap.data == null || snap.data!.containsKey('error')) {
                final err = snap.data?['error'] ?? snap.error?.toString() ?? 'Failed to load sales';
                return SizedBox(
                  height: 220,
                  child: Center(child: Text('Error: $err')),
                );
              }

              final data = snap.data!;
              final totalSales = (data['totalSales'] ?? 0).toDouble();
              final txCount = data['transactionCount'] ?? 0;
              final rawItems = (data['items'] as Map?) ?? {};
              final items = <String, Map<String, double>>{
                for (final entry in rawItems.entries)
                  entry.key.toString(): {
                    'quantity': ((entry.value as Map?)?['quantity'] as num?)?.toDouble() ?? 0.0,
                    'sales': ((entry.value as Map?)?['sales'] as num?)?.toDouble() ?? 0.0,
                  },
              };
              final cashierTotals = <String, double>{
                for (final entry in ((data['cashierTotals'] as Map?) ?? {}).entries)
                  entry.key.toString(): (entry.value as num?)?.toDouble() ?? 0.0,
              };
              final paymentMethodTotals = <String, double>{
                for (final entry in ((data['paymentMethodTotals'] as Map?) ?? {}).entries)
                  entry.key.toString(): (entry.value as num?)?.toDouble() ?? 0.0,
              };
              final transactions = List<Map<String, dynamic>>.from((data['transactions'] ?? []));
              final previousDayTotal = (data['previousDayTotal'] ?? 0).toDouble();

              // Build top items list
              final topItems = items.entries.map((e) {
                return {
                  'name': e.key,
                  'quantity': e.value['quantity'] ?? 0.0,
                  'sales': e.value['sales'] ?? 0.0
                };
              }).toList();
              topItems.sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));

              String buildMessage() {
                final buffer = StringBuffer();
                final dateStr = dateToFetch.day.toString().padLeft(2, '0');
                final monthStr = dateToFetch.month.toString().padLeft(2, '0');
                final yearStr = dateToFetch.year.toString();
                buffer.writeln('Daily Sales Summary for $businessName');
                buffer.writeln('Date: $dateStr/$monthStr/$yearStr');
                buffer.writeln('Total Sales: ₦${totalSales.toStringAsFixed(2)}');
                final grossProfit = (data['grossProfit'] ?? 0).toDouble();
                final grossMarginPct = (data['grossMarginPercent'] ?? 0).toDouble();
                buffer.writeln('Gross Profit: ₦${grossProfit.toStringAsFixed(2)} (Margin: ${grossMarginPct.toStringAsFixed(1)}%)');
                buffer.writeln('Transactions: $txCount');

                // Growth vs previous day
                if (previousDayTotal == 0) {
                  buffer.writeln('Growth: N/A (no sales yesterday)');
                } else {
                  final diff = totalSales - previousDayTotal;
                  final pct = (diff / previousDayTotal) * 100;
                  final sign = pct >= 0 ? '▲' : '▼';
                  buffer.writeln('Growth: $sign ${pct.abs().toStringAsFixed(1)}% vs yesterday (₦${previousDayTotal.toStringAsFixed(2)})');
                }

                buffer.writeln('\nTop Items:');
                for (var i = 0; i < (topItems.length < 5 ? topItems.length : 5); i++) {
                  final it = topItems[i];
                  buffer.writeln('${i + 1}. ${it['name']} x ${it['quantity']} - ₦${(it['sales'] as double).toStringAsFixed(2)}');
                }

                // Top cashiers
                if (cashierTotals.isNotEmpty) {
                  buffer.writeln('\nTop Cashiers:');
                  final topCashiers = cashierTotals.entries.toList();
                  topCashiers.sort((a, b) => b.value.compareTo(a.value));
                  for (var i = 0; i < (topCashiers.length < 5 ? topCashiers.length : 5); i++) {
                    final c = topCashiers[i];
                    buffer.writeln('${i + 1}. ${c.key} - ₦${c.value.toStringAsFixed(2)}');
                  }
                }

                // Payment Method Breakdown
                if (paymentMethodTotals.isNotEmpty) {
                  buffer.writeln('\nPayment Method Breakdown:');
                  final sortedMethods = paymentMethodTotals.entries.toList();
                  sortedMethods.sort((a, b) => b.value.compareTo(a.value));
                  for (var method in sortedMethods) {
                    final percentage = (method.value / totalSales * 100);
                    buffer.writeln('- ${method.key}: ₦${method.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)');
                  }
                }

                // Recent transactions (up to 30, IDs omitted)
                if (transactions.isNotEmpty) {
                  buffer.writeln('\nRecent Transactions (up to 30, IDs omitted):');
                  final recent = transactions.take(30).toList();
                  for (var t in recent) {
                    final cashier = t['cashier'] ?? t['cashierName'] ?? 'Unknown';
                    final total = (t['total'] ?? t['totalAmount'] ?? 0).toDouble();
                    final rawItems = t['items'] as List<dynamic>? ?? [];
                    final itemStr = rawItems.map((it) {
                      final name = it['productName'] ?? it['name'] ?? 'Item';
                      final qty = (it['quantity'] ?? it['qty'] ?? 0);
                      return '$name x$qty';
                    }).join(', ');
                    final dateStr = (t['createdAt'] is String && (t['createdAt'] as String).isNotEmpty)
                        ? DateTime.parse(t['createdAt']).toLocal().toString().split('.').first
                        : '';
                    buffer.writeln('- ₦${total.toStringAsFixed(2)} • ${t['status'] ?? ''} • $dateStr • $cashier • $itemStr');
                  }
                  buffer.writeln('\nNote: Transaction IDs are omitted from this message. A full report (including IDs) can be emailed to the owner.');
                }

                buffer.writeln('\nRegards, Manage Care Admin');
                return buffer.toString();
              }

              // Prepare header KPI card
              final topCashiers = cashierTotals.entries.toList();
              topCashiers.sort((a, b) => b.value.compareTo(a.value));

              return SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Daily Sales', style: Theme.of(context).textTheme.headlineSmall),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // KPI Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Sales', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                const SizedBox(height: 6),
                                Text('₦${totalSales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Gross: ₦${(data['grossProfit'] ?? 0).toStringAsFixed(2)} (${(data['grossMarginPercent'] ?? 0).toStringAsFixed(1)}%)', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Transactions', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                const SizedBox(height: 6),
                                Text('$txCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Growth and top cashiers
                    Text(topCashiers.isNotEmpty ? 'Growth & Top Cashiers' : 'Growth', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(previousDayTotal == 0 ? 'Growth: N/A (no sales yesterday)' : '${((totalSales - previousDayTotal)/ (previousDayTotal == 0 ? 1 : previousDayTotal) * 100).toStringAsFixed(1)}% vs yesterday', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (topCashiers.isNotEmpty)
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (_, i) {
                            final c = topCashiers[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${i + 1}. ${c.key} • ₦${c.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: topCashiers.length < 5 ? topCashiers.length : 5,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Top items
                    const Text('Top Items:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: topItems.length,
                        itemBuilder: (ctx, idx) {
                          final it = topItems[idx];
                          return Container(
                            width: 220,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]! ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text('x${it['quantity']}', style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(height: 6),
                                Text('₦${(it['sales'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Payment Method Breakdown
                    if (paymentMethodTotals.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ...(() {
                            final sorted = paymentMethodTotals.entries.toList();
                            sorted.sort((a, b) => b.value.compareTo(a.value));
                            return sorted.map((method) {
                              final percentage = (method.value / totalSales * 100);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(method.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₦${method.value.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          }()),
                          Container(
                            width: double.infinity,
                            height: 1,
                            color: Colors.grey[200],
                            margin: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                '₦${totalSales.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),

                    // Recent transactions
                    const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (ctx, i) {
                          final t = transactions[i];
                          final cashier = t['cashier'] ?? t['cashierName'] ?? 'Unknown';
                          final total = (t['total'] ?? t['totalAmount'] ?? 0).toDouble();
                          final rawItems = t['items'] as List<dynamic>? ?? [];
                          final itemStr = rawItems.map((it) {
                            final name = it['productName'] ?? it['name'] ?? 'Item';
                            final qty = (it['quantity'] ?? it['qty'] ?? 0);
                            return '$name x$qty';
                          }).join(', ');
                          final dateStr = (t['createdAt'] is String && (t['createdAt'] as String).isNotEmpty)
                              ? DateTime.parse(t['createdAt']).toLocal().toString().split('.').first
                              : '';

                          return ListTile(
                            dense: true,
                            title: Text('₦${total.toStringAsFixed(2)} • $cashier'),
                            subtitle: Text('$dateStr • $itemStr', maxLines: 2, overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action buttons with subtle animation and icon accents
                    StatefulBuilder(builder: (context, setLocalState) {
                      final Map<String, bool> _pressed = {};

                      Widget animatedButton({required Widget child, required VoidCallback onTap, required String key}) {
                        final pressed = _pressed[key] == true;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () async {
                              setLocalState(() => _pressed[key] = true);
                              try {
                                await Future.delayed(const Duration(milliseconds: 100));
                                onTap();
                              } finally {
                                // small delay for animation
                                Future.delayed(const Duration(milliseconds: 180), () {
                                  setLocalState(() => _pressed[key] = false);
                                });
                              }
                            },
                            child: AnimatedScale(
                              scale: pressed ? 0.96 : 1.0,
                              duration: const Duration(milliseconds: 120),
                              child: child,
                            ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            animatedButton(
                              key: 'whatsapp',
                              onTap: () async {
                                final message = buildMessage();
                                final messenger = ScaffoldMessenger.of(context);
                                if (phone.isEmpty) {
                                  messenger.showSnackBar(const SnackBar(content: Text('Owner phone number not available')));
                                  return;
                                }

                                // Clean phone: remove all non-numeric characters
                                var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
                                
                                // If phone doesn't start with country code, add +234 (Nigeria)
                                if (!cleanPhone.startsWith('+') && cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
                                  cleanPhone = '234${cleanPhone.substring(1)}';
                                } else if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
                                  cleanPhone = '234${cleanPhone.substring(1)}';
                                }
                                
                                // Ensure it starts with +
                                if (!cleanPhone.startsWith('+')) {
                                  cleanPhone = '+$cleanPhone';
                                }

                                final uri = Uri.parse('https://api.whatsapp.com/send?phone=${cleanPhone.replaceAll('+', '')}&text=${Uri.encodeComponent(message)}');
                                try {
                                  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  if (!launched) throw 'Could not launch';
                                  messenger.showSnackBar(const SnackBar(content: Text('Opening WhatsApp...')));
                                } catch (e) {
                                  await Clipboard.setData(ClipboardData(text: message));
                                  messenger.showSnackBar(const SnackBar(content: Text('Message copied to clipboard. Paste in WhatsApp.')));
                                }
                              },
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const CircleAvatar(radius: 12, backgroundColor: Color(0xFF25D366), child: Icon(Icons.message, size: 16, color: Colors.white)),
                                label: const Text('WhatsApp'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
                              ),
                            ),

                            animatedButton(
                              key: 'email',
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final svc = WhatsAppService();
                                messenger.showSnackBar(const SnackBar(content: Text('Sending daily report to owner...')));
                                final webhookUrl = (business['dailyReportWebhook'] as String?) ?? (business['settings'] is Map ? (business['settings'] as Map)['dailyReportWebhook'] as String? : null);
                                final ok = await svc.sendRecentTransactions(businessId: businessId, to: phone, limit: 30, webhookUrl: webhookUrl);

                                try {
                                  final reportSvc = ReportService();
                                  final payload = {
                                    'businessId': businessId,
                                    'businessName': business['name'] ?? '',
                                    'date': DateTime.now().toIso8601String(),
                                    'transactions': []
                                  };
                                  final fallbackOk = await reportSvc.triggerForBusiness(businessId: businessId, webhookUrl: webhookUrl, payload: payload);
                                  messenger.showSnackBar(SnackBar(content: Text((ok || fallbackOk) ? 'Daily report sent.' : 'Failed to send daily report')));
                                } catch (e) {
                                  messenger.showSnackBar(SnackBar(content: Text(ok ? 'Daily report sent.' : 'Failed to send daily report')));
                                }
                              },
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const CircleAvatar(radius: 12, backgroundColor: Color(0xFF3B82F6), child: Icon(Icons.send, size: 14, color: Colors.white)),
                                label: const Text('Email'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
                              ),
                            ),

                            animatedButton(
                              key: 'bookings',
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.showSnackBar(const SnackBar(content: Text('Sending pending booking messages...')));
                                try {
                                  final now = DateTime.now();
                                  final snap = await FirebaseFirestore.instance
                                      .collection('businesses')
                                      .doc(businessId)
                                      .collection('appointments')
                                      .where('status', whereIn: ['pending', 'confirmed'])
                                      .where('appointmentTime', isGreaterThan: now)
                                      .get();

                                  int sent = 0;
                                  int failed = 0;
                                  final svc = WhatsAppService();
                                  for (final d in snap.docs) {
                                    final data = d.data();
                                    final phoneRaw = (data['clientPhone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                                    if (phoneRaw.isEmpty) continue;
                                    final when = (data['appointmentTime'] is Timestamp) ? (data['appointmentTime'] as Timestamp).toDate().toLocal().toString().split('.').first : data['appointmentTime'].toString();
                                    final message = 'Hello ${data['clientName'] ?? ''}, reminder: your appointment for ${data['serviceName'] ?? ''} is on $when at ${business['name'] ?? ''}. Reply to confirm or contact us to reschedule.';
                                    try {
                                      final ok = await svc.sendTextToNumbers(businessId: businessId, toNumbers: [phoneRaw], message: message);
                                      if (ok) sent++; else failed++;
                                      await Future.delayed(const Duration(milliseconds: 300));
                                    } catch (_) {
                                      failed++;
                                    }
                                  }
                                  messenger.showSnackBar(SnackBar(content: Text('Pending booking messages sent: $sent, failed: $failed')));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send pending booking messages: $e')));
                                }
                              },
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const CircleAvatar(radius: 12, backgroundColor: Color(0xFF25D366), child: Icon(Icons.calendar_today, size: 14, color: Colors.white)),
                                label: const Text('Send Bookings'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
                              ),
                            ),

                            animatedButton(
                              key: 'report',
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.showSnackBar(const SnackBar(content: Text('Sending daily completed bookings report...')));
                                try {
                                  final today = DateTime.now();
                                  final start = DateTime(today.year, today.month, today.day);
                                  final end = start.add(const Duration(days: 1));
                                  final snap = await FirebaseFirestore.instance
                                      .collection('businesses')
                                      .doc(businessId)
                                      .collection('appointments')
                                      .where('status', isEqualTo: 'completed')
                                      .where('appointmentTime', isGreaterThanOrEqualTo: start)
                                      .where('appointmentTime', isLessThan: end)
                                      .get();

                                  final lines = <String>[];
                                  for (var i = 0; i < snap.docs.length; i++) {
                                    final d = snap.docs[i].data();
                                    final when = (d['appointmentTime'] is Timestamp) ? (d['appointmentTime'] as Timestamp).toDate().toLocal().toString().split('.').first : d['appointmentTime'].toString();
                                    lines.add('${i + 1}. ${d['clientName'] ?? ''} • ${d['serviceName'] ?? ''} • ${d['stylistName'] ?? d['barberName'] ?? ''} • $when • ₦${(d['amountPaid'] ?? 0)}');
                                  }

                                  final header = 'Completed bookings for ${start.toLocal().toIso8601String().split('T').first}: ${snap.docs.length}';
                                  final report = [header, ...lines].join('\n');
                                  final svc = WhatsAppService();
                                  final ok = await svc.sendTextToOwners(businessId: businessId, message: report);
                                  messenger.showSnackBar(SnackBar(content: Text(ok ? 'Report sent to owner(s)' : 'Failed to send report')));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send report: $e')));
                                }
                              },
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const CircleAvatar(radius: 12, backgroundColor: Colors.orange, child: Icon(Icons.receipt_long, size: 14, color: Colors.white)),
                                label: const Text('Send Report'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
                              ),
                            ),

                            animatedButton(
                              key: 'previous_day',
                              onTap: () async {
                                Navigator.pop(outerContext);
                                await Future.delayed(const Duration(milliseconds: 300));
                                final yesterday = DateTime(dateToFetch.year, dateToFetch.month, dateToFetch.day).subtract(const Duration(days: 1));
                                _showDailySales(outerContext, selectedDate: yesterday);
                              },
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const CircleAvatar(radius: 12, backgroundColor: Colors.purple, child: Icon(Icons.history, size: 14, color: Colors.white)),
                                label: const Text('Previous Day'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
                              ),
                            ),

                            animatedButton(
                              key: 'select_date',
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: outerContext,
                                  initialDate: dateToFetch,
                                  firstDate: DateTime(dateToFetch.year - 1),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null && picked != dateToFetch) {
                                  Navigator.pop(outerContext);
                                  await Future.delayed(const Duration(milliseconds: 300));
                                  _showDailySales(outerContext, selectedDate: picked);
                                }
                              },
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const CircleAvatar(radius: 12, backgroundColor: Colors.teal, child: Icon(Icons.calendar_today, size: 14, color: Colors.white)),
                                label: const Text('Select Date'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
                              ),
                            ),

                            animatedButton(
                              key: 'copy',
                              onTap: () async {
                                final message = buildMessage();
                                final messenger = ScaffoldMessenger.of(context);
                                await Clipboard.setData(ClipboardData(text: message));
                                messenger.showSnackBar(const SnackBar(content: Text('Message copied to clipboard')));
                              },
                              child: OutlinedButton(
                                onPressed: null,
                                child: const Text('Copy'),
                              ),
                            ),

                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _deleteBusinessCompletely(
    BuildContext context, Map<String, dynamic> business) async {
  final businessId = (business['id'] ?? business['businessId']).toString();
  final businessName = (business['name'] ?? 'this business').toString();

  final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
          title: const Text('Delete Business'),
          content: Text(
            'This will remove $businessName from normal access immediately and keep it recoverable by admin for 30 days before final cleanup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  if (!confirmed) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final admin = Provider.of<AdminProvider>(context, listen: false);
  final ok = await admin.deleteBusinessCompletely(businessId);

  if (context.mounted) {
    Navigator.pop(context);
    if (ok) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '$businessName deleted. Admin can restore it within 30 days.'
              : 'Failed to delete business',
        ),
      ),
    );
  }
}

Future<void> _restoreDeletedBusiness(
    BuildContext context, Map<String, dynamic> business) async {
  final businessId = (business['id'] ?? business['businessId']).toString();
  final businessName = (business['name'] ?? 'this business').toString();

  final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Business'),
          content: Text(
            'Restore $businessName and re-enable access for linked users?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Restore'),
            ),
          ],
        ),
      ) ??
      false;

  if (!confirmed) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final admin = Provider.of<AdminProvider>(context, listen: false);
  final ok = await admin.restoreDeletedBusiness(businessId);

  if (context.mounted) {
    Navigator.pop(context);
    if (ok) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '$businessName restored successfully' : 'Failed to restore business',
        ),
      ),
    );
  }
}

Widget _buildSection(BuildContext context, String title, List<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: context.adminTextPrimary,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        decoration: context.adminCardDecoration(
          color: context.adminSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...children
                .map((child) => [
                      child,
                      Divider(height: 16, color: context.adminBorder),
                    ])
                .expand((list) => list)
                .toList()
              ..removeLast(),
          ],
        ),
      ),
    ],
  );
}

Widget _buildInfoRow(BuildContext context, String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: context.adminTextSecondary,
          fontSize: 14,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: context.adminTextPrimary,
        ),
      ),
    ],
  );
}

String _formatTimestamp(dynamic value) {
  if (value == null) return '-';
  try {
    if (value is DateTime) {
      return '${value.day}/${value.month}/${value.year}';
    }
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    // Try to parse string timestamp
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) {
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    }
    return value.toString();
  } catch (_) {
    return value.toString();
  }
}

Widget _buildFeatureRow(String feature) {
  return Row(
    children: [
      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
      const SizedBox(width: 12),
      Text(
        feature,
        style: const TextStyle(fontSize: 14),
      ),
    ],
  );
}

void _editBusiness(BuildContext context, Map<String, dynamic> business) {
  final nameController = TextEditingController(text: business['name'] ?? '');
  final emailController = TextEditingController(text: business['email'] ?? '');
  final phoneController = TextEditingController(text: business['phone'] ?? '');
  final ownerNameController =
      TextEditingController(text: business['ownerName'] ?? '');

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) {
        String selectedClass = (business['businessClass'] ?? 'tier1').toString();
        return AlertDialog(
          title: const Text('Edit Business'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ownerNameController,
                  decoration: const InputDecoration(labelText: 'Owner Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedClass,
                  decoration: const InputDecoration(labelText: 'Business Class'),
                  items: const [
                    DropdownMenuItem(value: 'tier1', child: Text('Tier1 (Basic only)')),
                    DropdownMenuItem(value: 'tier2', child: Text('Tier2 (Basic & Pro)')),
                    DropdownMenuItem(value: 'tier3', child: Text('Tier3 (Basic & Pro)')),
                  ],
                  onChanged: (v) => setStateDialog(() => selectedClass = v ?? 'tier1'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final businessId = business['id'] ?? business['businessId'];
                  final admin = Provider.of<AdminProvider>(
                    context,
                    listen: false,
                  );
                  final ok = await admin.updateBusiness(
                    businessId.toString(),
                    {
                      'name': nameController.text,
                      'ownerName': ownerNameController.text,
                      'email': emailController.text,
                      'phone': phoneController.text,
                      'businessClass': selectedClass,
                    },
                  );
                  if (!ok) {
                    throw Exception(
                        admin.errorMessage ?? 'Unable to update business');
                  }

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Business updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating business: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}

void _toggleStatus(BuildContext context, dynamic business) {
  final currentStatus = business['isActive'] ?? true;
  final newStatus = !currentStatus;
  final action = newStatus ? 'activate' : 'deactivate';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${action.capitalize()} Business'),
      content: Text(
        'Are you sure you want to $action ${business['name'] ?? 'this business'}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final businessId = business['id'] ?? business['businessId'];
              final admin = Provider.of<AdminProvider>(
                context,
                listen: false,
              );
              final ok = await admin.updateBusiness(
                businessId.toString(),
                {'isActive': newStatus},
              );
              if (!ok) {
                throw Exception(
                    admin.errorMessage ?? 'Unable to update business status');
              }

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Business ${action}d successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating business status: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: newStatus ? Colors.green : Colors.red,
          ),
          child: Text(action.capitalize()),
        ),
      ],
    ),
  );
}

