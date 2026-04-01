import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/business_provider.dart';
import 'package:provider/provider.dart';
import '../../../../data/repositories/procurement_repository.dart';
import 'package:flutter/services.dart';

import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../services/report_export_service.dart';
import '../../../../core/utils/inventory_utils.dart';

class ProcurementHistoryScreen extends StatefulWidget {
  const ProcurementHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ProcurementHistoryScreen> createState() => _ProcurementHistoryScreenState();
}

class _ProcurementHistoryScreenState extends State<ProcurementHistoryScreen> {
  final _dateFmt = DateFormat('yyyy-MM-dd');
  DateTimeRange? _range;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _exportVisibleAsCsv(String? businessId) async {
    if (businessId == null) return;
    final snap = await FirebaseFirestore.instance.collection('businesses').doc(businessId).collection('procurements').orderBy('createdAt', descending: true).get();
    final docs = snap.docs.where((d) {
      final searchText = _searchController.text.toLowerCase();
      final createdAt = parseTimestamp(d['createdAt'] ?? DateTime.now());
      final dateOk = _range == null || (createdAt == null || (!createdAt.isBefore(_range!.start) && !createdAt.isAfter(_range!.end)));
      final items = (d['items'] as List?)?.cast<dynamic>() ?? [];
      final itemsMatch = items.any((it) => (it['name'] ?? '').toString().toLowerCase().contains(searchText));
      final idMatch = d.id.toLowerCase().contains(searchText);
      return dateOk && (searchText.isEmpty || itemsMatch || idMatch);
    }).toList();

    // Use repository to format CSV consistently
    final csv = ProcurementRepository().procurementsToCsv(docs);

    // Copy to clipboard and show a small dialog offering the CSV text
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Exported CSV'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: Text(csv)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        ),
      );
    }
  }

  Future<void> _downloadVisibleCsv(String? businessId) async {
    if (businessId == null) return;
    final snap = await FirebaseFirestore.instance.collection('businesses').doc(businessId).collection('procurements').orderBy('createdAt', descending: true).get();
    final docs = snap.docs.toList();

    // Convert docs to simpler maps for PDF export
    final data = docs.map((d) => {
    'id': d.id,
    'createdAt': parseTimestamp(d['createdAt'] ?? DateTime.now()),
      'supplierName': (d['supplierName'] ?? '') as String,
      'invoiceRef': (d['invoiceRef'] ?? '') as String,
      'totalCost': (d['totalCost'] as num?)?.toDouble() ?? 0.0,
      'totalQuantity': (d['totalQuantity'] as num?) ?? 0,
      'items': (d['items'] as List?) ?? [],
    }).toList();

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/procurements_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final businessName = context.read<BusinessProvider>().currentBusiness?.name ?? '';
    final ok = await ReportExportService().exportProcurementsPdf(filePath: filePath, businessName: businessName, procurements: data);
    if (ok) {
      await Share.shareXFiles([XFile(filePath)], text: 'Procurements Report');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF exported and share dialog opened')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate PDF')));
    }
  }

  Future<void> _exportVisibleAsPdf(String? businessId) async {
    if (businessId == null) return;
    final snap = await FirebaseFirestore.instance.collection('businesses').doc(businessId).collection('procurements').orderBy('createdAt', descending: true).get();
    final docs = snap.docs.where((d) {
      final searchText = _searchController.text.toLowerCase();
      final createdAt = parseTimestamp(d['createdAt'] ?? DateTime.now());
      final dateOk = _range == null || (!createdAt.isBefore(_range!.start) && !createdAt.isAfter(_range!.end));
      final items = (d['items'] as List?)?.cast<dynamic>() ?? [];
      final itemsMatch = items.any((it) => (it['name'] ?? '').toString().toLowerCase().contains(searchText));
      final idMatch = d.id.toLowerCase().contains(searchText);
      return dateOk && (searchText.isEmpty || itemsMatch || idMatch);
    }).toList();

    // Convert docs to simpler maps for PDF export
    final data = docs.map((d) => {
      'id': d.id,
      'createdAt': parseTimestamp(d['createdAt'] ?? DateTime.now()),
      'supplierName': (d['supplierName'] ?? '') as String,
      'invoiceRef': (d['invoiceRef'] ?? '') as String,
      'totalCost': (d['totalCost'] as num?)?.toDouble() ?? 0.0,
      'totalQuantity': (d['totalQuantity'] as num?) ?? 0,
      'items': (d['items'] as List?) ?? [],
    }).toList();

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/procurements_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final businessName = context.read<BusinessProvider>().currentBusiness?.name ?? '';
    final ok = await ReportExportService().exportProcurementsPdf(filePath: filePath, businessName: businessName, procurements: data);
    if (ok) {
      await Share.shareXFiles([XFile(filePath)], text: 'Procurements Report');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF exported and share dialog opened')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate PDF')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessProv = context.read<BusinessProvider>();
    final businessId = businessProv.currentBusiness?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Procurements History'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'copy_csv') return _exportVisibleAsCsv(businessId);
              if (v == 'download_csv') return _downloadVisibleCsv(businessId);
              if (v == 'export_pdf') return _exportVisibleAsPdf(businessId);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'copy_csv', child: Text('Copy CSV')), 
              const PopupMenuItem(value: 'download_csv', child: Text('Download CSV')),
              const PopupMenuItem(value: 'export_pdf', child: Text('Export PDF')),
            ],
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: businessId == null
          ? const Center(child: Text('No business selected'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search by product name or procurement id...',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _pickDateRange,
                        child: Text(_range == null ? 'Date' : '${_dateFmt.format(_range!.start)} → ${_dateFmt.format(_range!.end)}'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: ProcurementRepository().procurementsStream(businessId: businessId),
                    builder: (context, snap) {
                      if (snap.hasError) return const Center(child: Text('Error loading procurements'));
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snap.data!.docs;

                      // Apply search and date filters locally for simplicity
                      final filtered = docs.where((d) {
                        final id = d.id.toLowerCase();
                        final items = (d['items'] as List?)?.cast<dynamic>() ?? [];
                        final itemsMatch = items.any((it) => (it['name'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase()));
                        final searchText = _searchController.text.toLowerCase();
                        final createdAt = parseTimestamp(d['createdAt'] ?? DateTime.now());

                        final dateOk = _range == null || (!createdAt.isBefore(_range!.start) && !createdAt.isAfter(_range!.end));
                        final searchOk = searchText.isEmpty || id.contains(searchText) || itemsMatch;
                        return dateOk && searchOk;
                      }).toList();

                      // Group by day
                      final grouped = <String, List<QueryDocumentSnapshot>>{};
                      for (final d in filtered) {
                        final createdAt = parseTimestamp(d['createdAt'] ?? DateTime.now());
                        final day = DateFormat.yMMMd().format(createdAt);
                        grouped.putIfAbsent(day, () => []).add(d);
                      }

                      if (filtered.isEmpty) {
                        return Center(child: Text('No procurements found', style: AppTextStyles.subtitle1));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: grouped.keys.length,
                        itemBuilder: (context, idx) {
                          final day = grouped.keys.elementAt(idx);
                          final list = grouped[day]!..sort((a, b) {
                            final aDt = parseTimestamp(a['createdAt'] ?? DateTime.now());
                            final bDt = parseTimestamp(b['createdAt'] ?? DateTime.now());
                            return bDt.compareTo(aDt);
                          });
                          double dayTotal = 0.0;
                          num dayQty = 0;
                          for (final d in list) {
                            dayTotal += (d['totalCost'] as num?)?.toDouble() ?? 0.0;
                            dayQty += (d['totalQuantity'] as num?) ?? 0;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day, style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Total: ₦${dayTotal.toStringAsFixed(2)} • Units: ${formatInventoryQuantity(dayQty)}', style: AppTextStyles.caption),
                              const SizedBox(height: 8),
                              ...list.map((d) {
                                final createdAt = parseTimestamp(d['createdAt'] ?? DateTime.now());
                                return Card(
                                  child: ExpansionTile(
                                    title: Text('Procurement ${d.id}'),
                                    subtitle: Text('${DateFormat.yMMMd().add_jm().format(createdAt)} • ₦${(d['totalCost'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}'),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Builder(
                                              builder: (_) {
                                                final _supplierName = ( '') ;
                                                final _invoiceRef = ( '') ;                                              
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (_supplierName.toString().isNotEmpty) ...[
                                                      Text('Supplier', style: AppTextStyles.caption),
                                                      Text(_supplierName.toString(), style: AppTextStyles.body1),
                                                      const SizedBox(height: 8),
                                                    ],
                                                    if (_invoiceRef.toString().isNotEmpty) ...[
                                                      Text('Invoice / Reference', style: AppTextStyles.caption),
                                                      Text(_invoiceRef.toString(), style: AppTextStyles.body1),
                                                      const SizedBox(height: 8),
                                                    ],
                                                    Text('Items', style: AppTextStyles.caption),
                                                    const SizedBox(height: 8),
                                                    ...(d['items'] as List? ?? []).map((it) {
                                                      return ListTile(
                                                        dense: true,
                                                        title: Text(it['name'] ?? 'Unnamed'),
                                                        subtitle: Text('Qty: ${it['quantity']} • Cost: ₦${(it['cost'] ?? 0).toStringAsFixed(2)}'),
                                                        trailing: Text('₦${(it['total'] ?? 0).toStringAsFixed(2)}'),
                                                      );
                                                    }).toList(),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
    );
  }
}
