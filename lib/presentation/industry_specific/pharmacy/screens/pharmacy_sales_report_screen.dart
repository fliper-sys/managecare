import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';

class PharmacySalesReportScreen extends StatefulWidget {
  const PharmacySalesReportScreen({super.key});

  @override
  State<PharmacySalesReportScreen> createState() => _PharmacySalesReportScreenState();
}

class _PharmacySalesReportScreenState extends State<PharmacySalesReportScreen> {
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
  bool _loading = false;
  double _total = 0.0;
  int _count = 0;

  Future<void> _generate() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) return;

    setState(() {
      _loading = true;
      _total = 0.0;
      _count = 0;
    });

    final ref = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_range.start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_range.end));

    final snap = await ref.get();
    double total = 0.0;
    int count = 0;
    for (final d in snap.docs) {
      try {
        final data = d.data() as Map<String, dynamic>? ?? {};
        final t = (data['total'] as num?)?.toDouble() ?? (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
        total += t;
        count += 1;
      } catch (e) {
        // Skip malformed documents but log to help debugging
        print('[PharmacySalesReport] Skipping doc ${d.id} due to error: $e');
      }
    }

    setState(() {
      _loading = false;
      _total = total;
      _count = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Report'), backgroundColor: AppColors.pharmacy),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Range: ${_range.start.toLocal().toString().split(' ')[0]} — ${_range.end.toLocal().toString().split(' ')[0]}')),
                TextButton(
                  onPressed: () async {
                    final selected = await showDateRangePicker(
                        context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDateRange: _range);
                    if (selected != null) setState(() => _range = selected);
                  },
                  child: const Text('Change'),
                )
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.pharmacy),
              onPressed: _generate,
              child: const Text('Generate Report'),
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Sales: ₦${_total.toStringAsFixed(2)}', style: AppTextStyles.heading4),
                  const SizedBox(height: 8),
                  Text('Transactions: $_count', style: AppTextStyles.body2),
                ],
              )
          ],
        ),
      ),
    );
  }
}
