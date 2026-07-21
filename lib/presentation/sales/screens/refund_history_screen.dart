import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';

class RefundHistoryScreen extends StatefulWidget {
  const RefundHistoryScreen({super.key});

  @override
  State<RefundHistoryScreen> createState() => _RefundHistoryScreenState();
}

class _RefundHistoryScreenState extends State<RefundHistoryScreen> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');
  DateTimeRange? _dateRange;
  String _selectedWorker = 'all';

  String _businessId(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    final user = context.watch<AuthProvider>().currentUser;
    return business?.id ?? user?.primaryBusinessId ?? '';
  }

  Future<List<Map<String, dynamic>>> _loadRefunds(String businessId) async {
    if (businessId.isEmpty) return [];

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('returns')
        .orderBy('createdAt', descending: true);

    final range = _dateRange;
    if (range != null) {
      query = query
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_dayStart(range.start)))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(_dayEnd(range.end)));
    }

    final snapshot = await query.limit(300).get();
    final refunds = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    refunds.sort((a, b) =>
        _toDate(b['createdAt']).compareTo(_toDate(a['createdAt'])));
    return refunds;
  }

  bool _matchesWorker(Map<String, dynamic> refund) {
    if (_selectedWorker == 'all') return true;
    final candidates = [
      refund['enteredById'],
      refund['enteredByName'],
      refund['processedById'],
      refund['processedBy'],
      refund['soldById'],
      refund['soldByName'],
      refund['soldBy'],
      refund['workerId'],
      refund['workerName'],
      refund['cashierName'],
    ].map((value) => value?.toString().trim()).whereType<String>();
    return candidates.any((value) => value == _selectedWorker);
  }

  DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _dayEnd(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  String _text(dynamic value, {String fallback = 'Unknown'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _workerKey(Map<String, dynamic> refund) {
    return _text(
      refund['enteredById'] ??
          refund['processedById'] ??
          refund['soldById'] ??
          refund['soldByName'] ??
          refund['enteredByName'] ??
          refund['processedBy'],
      fallback: 'Unknown',
    );
  }

  String _workerLabel(Map<String, dynamic> refund) {
    return _text(
      refund['soldByName'] ??
          refund['workerName'] ??
          refund['cashierName'] ??
          refund['enteredByName'] ??
          refund['processedBy'] ??
          refund['soldBy'],
      fallback: 'Unknown',
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final businessId = _businessId(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Refund History'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: const Icon(Icons.date_range_rounded),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadRefunds(businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Could not load refund history: ${snapshot.error}'));
          }

          final allDateRefunds = snapshot.data ?? const <Map<String, dynamic>>[];
          final workerOptions = <String, String>{'all': 'All workers'};
          for (final refund in allDateRefunds) {
            workerOptions[_workerKey(refund)] = _workerLabel(refund);
          }
          final refunds = allDateRefunds.where(_matchesWorker).toList();

          return Column(
            children: [
              _FilterBar(
                dateLabel: _dateRange == null
                    ? 'All dates'
                    : '${DateFormat.yMMMd().format(_dateRange!.start)} - ${DateFormat.yMMMd().format(_dateRange!.end)}',
                selectedWorker: _selectedWorker,
                workerOptions: workerOptions,
                onPickDate: _pickDateRange,
                onClearDate: _dateRange == null ? null : () => setState(() => _dateRange = null),
                onWorkerChanged: (value) {
                  if (value != null) setState(() => _selectedWorker = value);
                },
              ),
              Expanded(
                child: refunds.isEmpty
                    ? const _EmptyRefundHistory()
                    : RefreshIndicator(
                        onRefresh: () async => setState(() {}),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: refunds.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _RefundCard(
                            refund: refunds[index],
                            currencyFormat: _currencyFormat,
                            dateFormat: _dateFormat,
                            toDate: _toDate,
                            text: _text,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String dateLabel;
  final String selectedWorker;
  final Map<String, String> workerOptions;
  final VoidCallback onPickDate;
  final VoidCallback? onClearDate;
  final ValueChanged<String?> onWorkerChanged;

  const _FilterBar({
    required this.dateLabel,
    required this.selectedWorker,
    required this.workerOptions,
    required this.onPickDate,
    required this.onClearDate,
    required this.onWorkerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              avatar: Icon(Icons.date_range_rounded, size: 18, color: colorScheme.onPrimary),
              label: Text(dateLabel, style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onPrimary)),
              backgroundColor: colorScheme.primary,
              onPressed: onPickDate,
            ),
            if (onClearDate != null)
              IconButton(
                tooltip: 'Clear date filter',
                icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
                onPressed: onClearDate,
              ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                value: workerOptions.containsKey(selectedWorker) ? selectedWorker : 'all',
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.surfaceVariant,
                  labelText: 'Worker',
                  prefixIcon: Icon(Icons.badge_rounded, color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                ),
                items: workerOptions.entries
                    .map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: onWorkerChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefundCard extends StatelessWidget {
  final Map<String, dynamic> refund;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final DateTime Function(dynamic value) toDate;
  final String Function(dynamic value, {String fallback}) text;

  const _RefundCard({
    required this.refund,
    required this.currencyFormat,
    required this.dateFormat,
    required this.toDate,
    required this.text,
  });

  String _soldByLabel() {
    return text(
      refund['soldByName'] ??
          refund['workerName'] ??
          refund['cashierName'] ??
          refund['soldBy'] ??
          refund['enteredByName'] ??
          refund['processedBy'],
      fallback: 'Unknown',
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = ((refund['refundAmount'] ?? 0) as num).toDouble();
    final items = (refund['itemsReturned'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => '${text(item['productName'] ?? item['productId'])} x${item['quantity'] ?? 0}')
        .join(', ');

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.25)),
      ),
      color: colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.errorContainer,
                  child: Icon(
                    Icons.keyboard_return_rounded,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currencyFormat.format(amount),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(toDate(refund['createdAt'] ?? refund['processedAt'])),
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoLine(label: 'Reason', value: text(refund['reason'], fallback: 'No reason recorded')),
            _InfoLine(label: 'Entered by', value: text(refund['enteredByName'] ?? refund['processedBy'])),
            _InfoLine(label: 'Sold by', value: _soldByLabel()),
            _InfoLine(label: 'Sale', value: text(refund['saleReference'] ?? refund['saleId'])),
            _InfoLine(label: 'Method', value: text(refund['refundMethod'])),
            if (items.isNotEmpty) _InfoLine(label: 'Items', value: items),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EmptyRefundHistory extends StatelessWidget {
  const _EmptyRefundHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('No refunds found'),
          const SizedBox(height: 4),
          Text('Try another date or worker filter.',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
