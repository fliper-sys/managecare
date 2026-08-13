import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/datetime_utils.dart';
import '../../data/repositories/admin_repository.dart';
import '../admin_theme.dart';

class AdminExpensesPage extends StatefulWidget {
  const AdminExpensesPage({super.key});

  @override
  State<AdminExpensesPage> createState() => _AdminExpensesPageState();
}

class _AdminExpensesPageState extends State<AdminExpensesPage> {
  final _adminRepository = AdminRepository();
  final _storage = FirebaseStorage.instance;
  DateTimeRange? _range;
  late Future<List<Map<String, dynamic>>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _expensesFuture = _loadExpenses();
  }

  Future<List<Map<String, dynamic>>> _loadExpenses() {
    return _adminRepository.fetchCompanyExpenses(
      startDate: _range?.start,
      endDate: _range?.end,
    );
  }

  void _refreshExpenses() {
    setState(() {
      _expensesFuture = _loadExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Expenses',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: context.adminTextPrimary,
                          ),
                        ),
                        Text(
                          'Register costs and attach receipts when available',
                          style: TextStyle(color: context.adminTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded),
                    tooltip: 'Filter date',
                  ),
                  FilledButton.icon(
                    onPressed: _showAddExpenseDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Expense'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _expensesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load expenses',
                        style: TextStyle(color: context.adminTextSecondary),
                      ),
                    );
                  }
                  final expenses = snapshot.data ?? const [];
                  final total = expenses.fold<double>(
                    0,
                    (sum, expense) => sum + _readDouble(expense['amount']),
                  );

                  if (expenses.isEmpty) {
                    return Center(
                      child: Text(
                        'No expenses recorded',
                        style: TextStyle(color: context.adminTextSecondary),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      _summaryCard(total, expenses.length),
                      const SizedBox(height: 14),
                      ...expenses.map((expense) =>
                          _expenseCard(expense['id'].toString(), expense)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(double total, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          context.adminCardDecoration(borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: Color(0xFF0EA5E9)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count expense records',
              style: TextStyle(color: context.adminTextPrimary),
            ),
          ),
          Text(
            'NGN ${total.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Color(0xFF0EA5E9),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseCard(String id, Map<String, dynamic> data) {
    final date =
        data['expenseDate'] == null ? null : parseTimestamp(data['expenseDate']);
    final receiptUrl = (data['receiptUrl'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration:
          context.adminCardDecoration(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (data['title'] ?? 'Expense').toString(),
                  style: TextStyle(
                    color: context.adminTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'NGN ${_readDouble(data['amount']).toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if ((data['category'] ?? '').toString().isNotEmpty)
                data['category'],
              if (date != null) DateFormat('dd MMM yyyy').format(date),
            ].join(' - '),
            style: TextStyle(color: context.adminTextSecondary),
          ),
          if ((data['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              data['description'].toString(),
              style: TextStyle(color: context.adminTextSecondary),
            ),
          ],
          if (receiptUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(receiptUrl)),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Open Receipt'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _expensesFuture = _loadExpenses();
      });
    }
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  Future<void> _showAddExpenseDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    PlatformFile? pickedReceipt;
    Uint8List? receiptBytes;
    DateTime expenseDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Register Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(DateFormat('dd MMM yyyy').format(expenseDate)),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDate: expenseDate,
                          );
                          if (picked != null) {
                            setDialogState(() => expenseDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event_rounded),
                        label: const Text('Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        withData: true,
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                      );
                      if (result == null || result.files.isEmpty) return;
                      setDialogState(() {
                        pickedReceipt = result.files.first;
                        receiptBytes = result.files.first.bytes;
                      });
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      pickedReceipt == null
                          ? 'Upload Receipt Optional'
                          : pickedReceipt!.name,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim());
                  if (titleController.text.trim().isEmpty || amount == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter title and amount')),
                    );
                    return;
                  }

                  String receiptUrl = '';
                  if (pickedReceipt != null && receiptBytes != null) {
                    final path =
                        'company_expenses/${DateTime.now().millisecondsSinceEpoch}_${pickedReceipt!.name}';
                    final ref = _storage.ref(path);
                    await ref.putData(receiptBytes!);
                    receiptUrl = await ref.getDownloadURL();
                  }

                  await _adminRepository.createCompanyExpense({
                    'title': titleController.text.trim(),
                    'amount': amount,
                    'category': categoryController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'expenseDate': expenseDate.toIso8601String(),
                    'receiptUrl': receiptUrl,
                  });
                  if (!mounted) return;
                  _refreshExpenses();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
