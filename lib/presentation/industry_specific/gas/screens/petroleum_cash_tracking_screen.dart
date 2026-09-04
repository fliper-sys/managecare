import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/managecare_api_client.dart';

class PetroleumCashTrackingScreen extends StatefulWidget {
  const PetroleumCashTrackingScreen({super.key});

  @override
  State<PetroleumCashTrackingScreen> createState() =>
      _PetroleumCashTrackingScreenState();
}

class _PetroleumCashTrackingScreenState
    extends State<PetroleumCashTrackingScreen> {
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _cashEntries = [];
  List<Map<String, dynamic>> _bankDeposits = [];
  List<Map<String, dynamic>> _adminSubmissions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0.0;
  }

  Future<void> _recordAdminSubmission() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    final receiverController = TextEditingController();
    final amountController = TextEditingController();
    final balanceController = TextEditingController(
      text: _amount(_summary['balance_cash_at_hand']).toStringAsFixed(2),
    );
    final noteController = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Cash Given To Admin'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: receiverController,
                      decoration: const InputDecoration(
                        labelText: 'Admin receiver name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [AmountInputFormatter()],
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [AmountInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Balance cash at hand',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Note'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      final amount = _amount(amountController.text);
      if (receiverController.text.trim().isEmpty || amount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter receiver and amount')),
        );
        return;
      }
      final user = context.read<AuthProvider>().currentUser;
      await ManagecareApiClient.instance.post(
        '/api/pumps/$businessId/admin-cash-submissions',
        body: {
          'receiver_name': receiverController.text.trim(),
          'amount': amount,
          'balance_cash_at_hand': _amount(balanceController.text),
          'note': noteController.text.trim(),
          'submitted_by': user?.id,
          'submitted_by_name': user?.fullName ?? user?.email,
        },
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin cash submission recorded')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record submission: $error')),
      );
    } finally {
      receiverController.dispose();
      amountController.dispose();
      balanceController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _load() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final summary = await ManagecareApiClient.instance
          .get('/api/pumps/$businessId/cash-summary');
      final cash = await ManagecareApiClient.instance.get(
        '/api/pumps/$businessId/cash-entries',
        query: {'limit': '100'},
      );
      final deposits = await ManagecareApiClient.instance.get(
        '/api/pumps/$businessId/bank-deposits',
        query: {'limit': '100'},
      );
      final admin = await ManagecareApiClient.instance.get(
        '/api/pumps/$businessId/admin-cash-submissions',
        query: {'limit': '100'},
      );
      if (!mounted) return;
      setState(() {
        _summary = Map<String, dynamic>.from(summary as Map);
        _cashEntries =
            ((cash['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        _bankDeposits =
            ((deposits['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        _adminSubmissions =
            ((admin['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load cash report: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Petroleum Cash Tracking'),
        actions: [
          IconButton(
            tooltip: 'Cash given to admin',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: _recordAdminSubmission,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryTile(
                        label: 'Pump Cash',
                        value: currency.format(_amount(_summary['cash_income'])),
                      ),
                      _SummaryTile(
                        label: 'POS/Transfer',
                        value: currency.format(_amount(_summary['pos_income'])),
                      ),
                      _SummaryTile(
                        label: 'Bank Deposits',
                        value: currency
                            .format(_amount(_summary['total_bank_deposits'])),
                      ),
                      _SummaryTile(
                        label: 'Admin Cash',
                        value: currency.format(
                          _amount(_summary['total_admin_submissions']),
                        ),
                      ),
                      _SummaryTile(
                        label: 'Cash At Hand',
                        value: currency
                            .format(_amount(_summary['balance_cash_at_hand'])),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Approved Pump Cash Income'),
                  ..._cashEntries.map(
                    (entry) => ListTile(
                      leading: const Icon(Icons.local_gas_station_outlined),
                      title: Text(currency.format(_amount(entry['total_amount']))),
                      subtitle: Text(
                        'Pump ${entry['pump_number'] ?? ''} • ${entry['worker_name'] ?? 'N/A'}\n'
                        'Cash: ${currency.format(_amount(entry['cash_amount']))} • POS: ${currency.format(_amount(entry['pos_amount']))}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle('Bank Deposits'),
                  ..._bankDeposits.map(
                    (deposit) => ListTile(
                      leading: const Icon(Icons.account_balance_outlined),
                      title: Text(currency.format(_amount(deposit['amount']))),
                      subtitle: Text(
                        '${deposit['bank_name'] ?? ''} • ${deposit['depositor_name'] ?? ''}\n'
                        'Balance: ${currency.format(_amount(deposit['balance_cash_at_hand']))}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle('Cash Given To Admin'),
                  ..._adminSubmissions.map(
                    (entry) => ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(currency.format(_amount(entry['amount']))),
                      subtitle: Text(
                        '${entry['receiver_name'] ?? ''} • ${entry['submitted_by_name'] ?? 'N/A'}\n'
                        'Balance: ${currency.format(_amount(entry['balance_cash_at_hand']))}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
