import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/email_service.dart';
import '../../../../services/managecare_api_client.dart';

class PetroleumBankDepositScreen extends StatefulWidget {
  const PetroleumBankDepositScreen({super.key});

  @override
  State<PetroleumBankDepositScreen> createState() =>
      _PetroleumBankDepositScreenState();
}

class _PetroleumBankDepositScreenState
    extends State<PetroleumBankDepositScreen> {
  final _depositorController = TextEditingController();
  final _amountController = TextEditingController();
  final _depositedCashController = TextEditingController();
  final _balanceCashController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  DateTime _depositDate = DateTime.now();
  TimeOfDay _depositTime = TimeOfDay.now();
  String? _receiptUrl;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  List<Map<String, dynamic>> _deposits = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDeposits());
  }

  @override
  void dispose() {
    _depositorController.dispose();
    _amountController.dispose();
    _depositedCashController.dispose();
    _balanceCashController.dispose();
    _bankController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  double _readAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0.0;
  }

  String _businessId() =>
      context.read<BusinessProvider>().currentBusiness?.id ?? '';

  bool _hasPetroleumCashAccess(dynamic user) {
    final role = WorkerPermissions.normalizeRole(user?.role ?? '');
    return user?.isOwner == true ||
        role == 'owner' ||
        role == 'admin' ||
        role == 'sub_admin' ||
        role == 'manager' ||
        role == 'fuel_manager';
  }

  Future<void> _loadDeposits() async {
    if (!_hasPetroleumCashAccess(context.read<AuthProvider>().currentUser)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final businessId = _businessId();
    if (businessId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final response = await ManagecareApiClient.instance.get(
        '/api/pumps/$businessId/bank-deposits',
        query: {'limit': '100'},
      );
      final rows =
          ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _deposits = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load deposits: $e')),
      );
    }
  }

  Future<void> _pickReceipt() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      final url =
          await EmailService().uploadBytes(await picked.readAsBytes(), picked.name);
      if (!mounted) return;
      setState(() => _receiptUrl = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveDeposit() async {
    final businessId = _businessId();
    final amount = _readAmount(_amountController.text);
    if (businessId.isEmpty ||
        _depositorController.text.trim().isEmpty ||
        _bankController.text.trim().isEmpty ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter depositor, amount and bank')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = context.read<AuthProvider>().currentUser;
      await ManagecareApiClient.instance.post(
        '/api/pumps/$businessId/bank-deposits',
        body: {
          'depositor_name': _depositorController.text.trim(),
          'deposit_date': DateFormat('yyyy-MM-dd').format(_depositDate),
          'deposit_time':
              '${_depositTime.hour.toString().padLeft(2, '0')}:${_depositTime.minute.toString().padLeft(2, '0')}',
          'amount': amount,
          'deposited_cash_entry': _readAmount(_depositedCashController.text) > 0
              ? _readAmount(_depositedCashController.text)
              : amount,
          'balance_cash_at_hand': _readAmount(_balanceCashController.text),
          'bank_name': _bankController.text.trim(),
          'account_number': _accountNumberController.text.trim(),
          'account_name': _accountNameController.text.trim(),
          'receipt_url': _receiptUrl,
          'recorded_by': user?.id,
          'recorded_by_name': user?.fullName ?? user?.email,
        },
      );
      _depositorController.clear();
      _amountController.clear();
      _depositedCashController.clear();
      _balanceCashController.clear();
      _bankController.clear();
      _accountNumberController.clear();
      _accountNameController.clear();
      _receiptUrl = null;
      await _loadDeposits();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank deposit recorded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save deposit: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    if (!_hasPetroleumCashAccess(context.watch<AuthProvider>().currentUser)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bank Deposits')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Only managers and admins can access bank deposits.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bank Deposits')),
      body: RefreshIndicator(
        onRefresh: _loadDeposits,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _depositorController,
              decoration: const InputDecoration(
                labelText: 'Depositor name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [AmountInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Amount deposited',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _depositedCashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [AmountInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Deposited cash entry',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balanceCashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [AmountInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Balance cash at hand',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _depositDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setState(() => _depositDate = picked);
                      }
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(DateFormat.yMMMd().format(_depositDate)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _depositTime,
                      );
                      if (picked != null) {
                        setState(() => _depositTime = picked);
                      }
                    },
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(_depositTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bankController,
              decoration: const InputDecoration(
                labelText: 'Bank deposited',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountNumberController,
              decoration: const InputDecoration(
                labelText: 'Account number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountNameController,
              decoration: const InputDecoration(
                labelText: 'Account name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickReceipt,
              icon: Icon(_receiptUrl == null
                  ? Icons.upload_file_outlined
                  : Icons.check_circle_outline),
              label: Text(_uploading
                  ? 'Uploading...'
                  : _receiptUrl == null
                      ? 'Upload receipt'
                      : 'Receipt uploaded'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveDeposit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Record Deposit'),
            ),
            const SizedBox(height: 24),
            Text(
              'Deposit History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_deposits.isEmpty)
              const Text('No bank deposits recorded yet.')
            else
              ..._deposits.map((deposit) {
                final date = deposit['deposit_date']?.toString() ?? '';
                final time = deposit['deposit_time']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_outlined),
                    title: Text(currency.format(_readAmount(deposit['amount']))),
                    subtitle: Text(
                      '${deposit['bank_name'] ?? ''} • ${deposit['depositor_name'] ?? ''}\n'
                      '$date $time • Balance: ${currency.format(_readAmount(deposit['balance_cash_at_hand']))}',
                    ),
                    isThreeLine: true,
                    trailing: deposit['receipt_url']?.toString().isNotEmpty ==
                            true
                        ? const Icon(Icons.receipt_long_outlined)
                        : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
