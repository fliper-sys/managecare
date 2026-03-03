import 'package:flutter/material.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/business_provider.dart';
import '../../../core/theme/colors.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<Map<String, dynamic>> _payrollRecords = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPayroll();
  }

  Future<void> _loadPayroll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;

      if (business == null) {
        setState(() {
          _error = 'Business not found';
          _isLoading = false;
        });
        return;
      }

      // Get payroll for all workers in this business
      final snapshot = await FirebaseFirestore.instance
          .collection('payroll')
          .where('businessId', isEqualTo: business.id)
          .orderBy('payDate', descending: true)
          .limit(20)
          .get();

      final records =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      setState(() {
        _payrollRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load payroll: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPayroll,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _payrollRecords.isEmpty
                  ? const Center(child: Text('No payroll records found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payrollRecords.length,
                      itemBuilder: (context, index) {
                        final record = _payrollRecords[index];
                        final workerName =
                            record['workerName'] as String? ?? 'Worker';
                        final grossAmount =
                            (record['grossAmount'] as num? ?? 0).toDouble();
                        final deductions =
                            (record['deductions'] as num? ?? 0).toDouble();
                        final netAmount =
                            (record['netAmount'] as num? ?? 0).toDouble();
                        final payDate = parseTimestamp(record['payDate']);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      workerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${payDate.day}/${payDate.month}/${payDate.year}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ListTile(
                                  title: const Text('Gross Salary'),
                                  trailing: Text(
                                    '₦${grossAmount.toStringAsFixed(2)}',
                                  ),
                                ),
                                ListTile(
                                  title: const Text('Deductions'),
                                  trailing: Text(
                                    '-₦${deductions.toStringAsFixed(2)}',
                                  ),
                                ),
                                const Divider(),
                                ListTile(
                                  title: const Text('Net Pay'),
                                  trailing: Text(
                                    '₦${netAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

