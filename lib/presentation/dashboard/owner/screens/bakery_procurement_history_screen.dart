import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../data/repositories/procurement_repository.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/report_export_service.dart';

class BakeryProcurementHistoryScreen extends StatefulWidget {
  const BakeryProcurementHistoryScreen({Key? key}) : super(key: key);

  @override
  State<BakeryProcurementHistoryScreen> createState() => _BakeryProcurementHistoryScreenState();
}

class _BakeryProcurementHistoryScreenState extends State<BakeryProcurementHistoryScreen> {
  final _searchController = TextEditingController();
  DateTimeRange? _range;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _safeData(DocumentSnapshot doc) {
    final d = doc.data();
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<List<QueryDocumentSnapshot>> _filteredDocs(String businessId) async {
    final snap = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('procurements')
        .where('sourceType', isEqualTo: 'bakery')
        .get();

    final docs = snap.docs.where((d) {
      final data = _safeData(d);
      final searchText = _searchController.text.toLowerCase();
      final createdAt = parseTimestamp(data['createdAt'] ?? DateTime.now());
      final dateOk = _range == null || (!createdAt.isBefore(_range!.start) && !createdAt.isAfter(_range!.end));

      final queryFields = [
        d.id.toLowerCase(),
        (data['supplierName'] ?? '').toString().toLowerCase(),
        (data['bakerName'] ?? '').toString().toLowerCase(),
        (data['salesRepName'] ?? '').toString().toLowerCase(),
        (data['invoiceRef'] ?? '').toString().toLowerCase(),
      ];
      final searchOk = searchText.isEmpty || queryFields.any((value) => value.contains(searchText));
      return dateOk && searchOk;
    }).toList();

    docs.sort((a, b) {
      final aCreatedAt = parseTimestamp(_safeData(a)['createdAt'] ?? DateTime.now());
      final bCreatedAt = parseTimestamp(_safeData(b)['createdAt'] ?? DateTime.now());
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return docs;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (range != null) {
      setState(() {
        _range = range;
      });
    }
  }

  Future<void> _exportVisibleAsCsv(String businessId) async {
    final docs = await _filteredDocs(businessId);
    final csv = ProcurementRepository().procurementsToCsv(docs);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bakery procurements CSV copied to clipboard')));
  }

  Future<void> _downloadVisibleCsv(String businessId) async {
    final docs = await _filteredDocs(businessId);
    final csv = ProcurementRepository().procurementsToCsv(docs);
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/bakery_procurements_${DateTime.now().millisecondsSinceEpoch}.csv';
    await File(filePath).writeAsString(csv);
    if (!mounted) return;
    await Share.shareXFiles([XFile(filePath)], text: 'Bakery Procurements CSV');
  }

  Future<void> _exportVisibleAsPdf(String businessId) async {
    final docs = await _filteredDocs(businessId);
    final procurements = docs.map((d) {
      final data = _safeData(d);
      return {
        'id': d.id,
        'createdAt': parseTimestamp(data['createdAt'] ?? DateTime.now()),
        'supplierName': data['supplierName']?.toString() ?? '',
        'invoiceRef': data['invoiceRef']?.toString() ?? '',
        'totalCost': (data['totalCost'] as num?)?.toDouble() ?? 0.0,
        'totalQuantity': (data['totalQuantity'] as num?)?.toInt() ?? 0,
        'bakerName': data['bakerName']?.toString() ?? '',
        'salesRepName': data['salesRepName']?.toString() ?? '',
        'items': (data['items'] as List?) ?? [],
      };
    }).toList();

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/bakery_procurements_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final businessName = context.read<BusinessProvider>().currentBusiness?.name ?? 'Bakery';
    final ok = await ReportExportService().exportProcurementsPdf(
      filePath: filePath,
      businessName: businessName,
      procurements: procurements,
    );
    if (!mounted) return;
    if (ok) {
      await Share.shareXFiles([XFile(filePath)], text: 'Bakery Procurements Report');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bakery procurements PDF exported')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate bakery report PDF')));
    }
  }

  String _summaryText(Map<String, dynamic> data, int itemCount) {
    final supplier = data['supplierName'] ?? 'Unknown supplier';
    final baker = data['bakerName'] ?? 'Unknown baker';
    final salesRep = data['salesRepName'] ?? 'Unknown rep';
    return '$itemCount item(s) • $supplier • Baker: $baker • Rep: $salesRep';
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.watch<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      return const Scaffold(body: Center(child: Text('No business selected')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bakery Procurements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _pickDateRange,
            tooltip: 'Filter by date',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'copy_csv') return _exportVisibleAsCsv(businessId);
              if (value == 'download_csv') return _downloadVisibleCsv(businessId);
              if (value == 'export_pdf') return _exportVisibleAsPdf(businessId);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy_csv', child: Text('Copy CSV')),
              PopupMenuItem(value: 'download_csv', child: Text('Download CSV')),
              PopupMenuItem(value: 'export_pdf', child: Text('Export PDF')),
            ],
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Column(
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
                      hintText: 'Search by procurement id, supplier, baker or sales rep',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _pickDateRange,
                  child: Text(
                    _range == null
                        ? 'Date'
                        : '${DateFormat.yMMMd().format(_range!.start)} → ${DateFormat.yMMMd().format(_range!.end)}',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(businessId)
                  .collection('procurements')
                  .where('sourceType', isEqualTo: 'bakery')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading bakery procurements'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.where((d) {
                  final data = _safeData(d);
                  final searchText = _searchController.text.toLowerCase();
                  final createdAt = parseTimestamp(data['createdAt'] ?? DateTime.now());
                  final dateOk = _range == null || (!createdAt.isBefore(_range!.start) && !createdAt.isAfter(_range!.end));
                  final queryFields = [
                    d.id.toLowerCase(),
                    (data['supplierName'] ?? '').toString().toLowerCase(),
                    (data['bakerName'] ?? '').toString().toLowerCase(),
                    (data['salesRepName'] ?? '').toString().toLowerCase(),
                    (data['invoiceRef'] ?? '').toString().toLowerCase(),
                  ];
                  final searchOk = searchText.isEmpty || queryFields.any((value) => value.contains(searchText));
                  return dateOk && searchOk;
                }).toList();

                docs.sort((a, b) {
                  final aCreatedAt = parseTimestamp(_safeData(a)['createdAt'] ?? DateTime.now());
                  final bCreatedAt = parseTimestamp(_safeData(b)['createdAt'] ?? DateTime.now());
                  return bCreatedAt.compareTo(aCreatedAt);
                });

                if (docs.isEmpty) {
                  return Center(child: Text('No bakery procurements found', style: AppTextStyles.subtitle1));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = _safeData(doc);
                    final createdAt = parseTimestamp(data['createdAt'] ?? DateTime.now());
                    final totalCost = (data['totalCost'] as num?)?.toDouble() ?? 0.0;
                    final itemCount = (data['items'] as List?)?.length ?? 0;
                    final summary = _summaryText(data, itemCount);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        title: Text('Procurement ${doc.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat.yMMMd().format(createdAt)),
                            const SizedBox(height: 4),
                            Text(summary, style: AppTextStyles.caption),
                          ],
                        ),
                        trailing: Text('₦${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () => _showProcurementDetails(context, doc),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showProcurementDetails(BuildContext context, QueryDocumentSnapshot doc) {
    final data = _safeData(doc);
    final createdAt = parseTimestamp(data['createdAt'] ?? DateTime.now());
    final items = (data['items'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Procurement ${doc.id}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${DateFormat.yMMMd().format(createdAt)}'),
                const SizedBox(height: 8),
                Text('Supplier: ${data['supplierName'] ?? 'N/A'}'),
                Text('Invoice: ${data['invoiceRef'] ?? 'N/A'}'),
                Text('Baker: ${data['bakerName'] ?? 'N/A'}'),
                Text('Sales Rep: ${data['salesRepName'] ?? 'N/A'}'),
                const SizedBox(height: 12),
                const Text('Items', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final m = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
                  final unit = (m['unit'] ?? '').toString();
                  final purchaseUnit = (m['purchaseUnit'] ?? '').toString();
                  final bagWeightKg = (m['bagWeightKg'] as num?)?.toDouble() ?? 0.0;
                  final perKg = purchaseUnit.toLowerCase() == 'bag' && bagWeightKg > 0
                      ? (m['purchaseUnitCost'] as num?)?.toDouble() ?? 0.0 / bagWeightKg
                      : (m['purchaseUnitCost'] as num?)?.toDouble() ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['name'] ?? 'Unnamed item', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Qty: ${m['quantity'] ?? 0} $unit • Cost: ₦${((m['cost'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                        const SizedBox(height: 2),
                        Text('Purchase: $purchaseUnit • Unit cost: ₦${((m['purchaseUnitCost'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} • Per kg: ₦${perKg.toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
