import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';

String petroleumBadgeAllocationSummary(
  List<Map<String, dynamic>> badges,
  dynamic rawAllocations,
) {
  if (rawAllocations is! List || rawAllocations.isEmpty) return '';
  final labels = <String>[];
  for (final raw in rawAllocations) {
    if (raw is! Map) continue;
    final allocation = Map<String, dynamic>.from(raw);
    final id = (allocation['badge_id'] ??
            allocation['badgeId'] ??
            allocation['badge_batch_id'] ??
            '')
        .toString();
    final badge = badges.where((item) =>
        (item['id'] ?? item['badge_id'] ?? item['badgeId'] ?? '').toString() ==
        id);
    final record = badge.isEmpty ? null : badge.first;
    final code = (record?['badge_code'] ??
            record?['badgeCode'] ??
            record?['badge_number'] ??
            record?['badgeNumber'] ??
            id)
        .toString();
    final quantity = allocation['quantity'];
    labels.add('$code${quantity == null ? '' : ' · $quantity'}');
  }
  return labels.join(', ');
}

class PetroleumBadgeContextBar extends StatefulWidget {
  const PetroleumBadgeContextBar({super.key});

  @override
  State<PetroleumBadgeContextBar> createState() =>
      _PetroleumBadgeContextBarState();
}

class _PetroleumBadgeContextBarState extends State<PetroleumBadgeContextBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      if (businessId != null && businessId.isNotEmpty) {
        context.read<RetailProvider>().initialize(businessId);
        context.read<RetailProvider>().loadPetroleumBadges();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final businessType = context
            .watch<BusinessProvider>()
            .currentBusiness
            ?.businessType
            .toLowerCase() ??
        '';
    if (!(businessType.contains('petroleum') ||
        businessType.contains('petrol'))) {
      return const SizedBox.shrink();
    }
    final retail = context.watch<RetailProvider>();
    final selectedNumber = retail.selectedPetroleumBadgeNumber;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: retail.selectedPetroleumBadgeId,
                  hint: const Text('All badges'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All badges'),
                    ),
                    ...retail.petroleumBadges.map((badge) {
                      final id = (badge['id'] ??
                              badge['badge_id'] ??
                              badge['badgeId'] ??
                              '')
                          .toString();
                      final number = (badge['badge_number'] ??
                              badge['badgeNumber'] ??
                              badge['badge_code'] ??
                              badge['badgeCode'] ??
                              badge['number'] ??
                              badge['name'] ??
                              id)
                          .toString();
                      return DropdownMenuItem<String?>(
                        value: id,
                        child: Text('Badge $number',
                            overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (id) => retail.selectPetroleumBadge(id),
                ),
              ),
            ),
            if (retail.isLoadingPetroleumBadges)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton(
              tooltip: 'Badge accountability',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PetroleumBadgeAccountabilityScreen(),
                ),
              ),
            ),
            if (selectedNumber != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('Badge $selectedNumber',
                    style: Theme.of(context).textTheme.labelSmall),
              ),
          ],
        ),
      ),
    );
  }
}

class PetroleumBadgeAccountabilityScreen extends StatefulWidget {
  const PetroleumBadgeAccountabilityScreen({super.key});

  @override
  State<PetroleumBadgeAccountabilityScreen> createState() =>
      _PetroleumBadgeAccountabilityScreenState();
}

class _PetroleumBadgeAccountabilityScreenState
    extends State<PetroleumBadgeAccountabilityScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final retail = context.read<RetailProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      if (businessId == null || businessId.isEmpty) {
        throw StateError('No business selected');
      }
      await retail.initialize(businessId);
      final result = await retail.loadPetroleumAccountability();
      if (!mounted) return;
      setState(() {
        _data = result['data'] is Map
            ? Map<String, dynamic>.from(result['data'] as Map)
            : result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _allocateDeposit(Map<String, dynamic> row) async {
    final retail = context.read<RetailProvider>();
    final depositId = (row['id'] ?? '').toString();
    if (depositId.isEmpty || retail.selectedPetroleumBadgeId == null) return;
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            'Allocate to badge ${retail.selectedPetroleumBadgeNumber ?? ''}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Deposit amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _number(controller.text)),
            child: const Text('Allocate'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0) return;
    try {
      await retail.allocatePetroleumDeposit(
          depositId: depositId, amount: amount);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deposit allocation recorded')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not allocate deposit: $error')),
        );
      }
    }
  }

  Future<void> _recordDip(Map<String, dynamic> row) async {
    final productId =
        (row['product_id'] ?? row['productId'] ?? row['id'] ?? '').toString();
    if (productId.isEmpty) return;
    final controller = TextEditingController(
      text: (row['actual_quantity'] ?? row['actualQuantity'] ?? '').toString(),
    );
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            'Tank dip · ${row['product_name'] ?? row['productName'] ?? 'Product'}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'Actual physical quantity'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _number(controller.text)),
            child: const Text('Save dip'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null || quantity < 0) return;
    try {
      await context.read<RetailProvider>().submitPetroleumTankDip(
            productId: productId,
            actualQuantity: quantity,
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tank dip recorded')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record tank dip: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final retail = context.watch<RetailProvider>();
    final badgeLabel = retail.selectedPetroleumBadgeNumber == null
        ? 'All badges'
        : 'Badge ${retail.selectedPetroleumBadgeNumber}';
    final products =
        _rows(_data['products'] ?? _data['reconciliation'] ?? _data['items']);
    final expectedBalance = _number(_data['badge_expected_balance'] ??
        _data['badgeExpectedBalance'] ??
        _data['expected_balance'] ??
        _data['expectedBalance']);
    final payments = _rows(_data['payment_methods'] ??
        _data['paymentMethods'] ??
        _data['payments']);
    final deposits = _rows(
        _data['bank_deposits'] ?? _data['bankDeposits'] ?? _data['deposits']);
    return Scaffold(
      appBar: AppBar(
        title: Text('$badgeLabel accountability'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          leading:
                              const Icon(Icons.account_balance_wallet_outlined),
                          title: const Text('Badge expected balance'),
                          trailing: Text(expectedBalance.toStringAsFixed(2),
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Tank expected vs actual by product',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (products.isEmpty)
                        const ListTile(
                            title: Text(
                                'No product reconciliation data returned')),
                      ...products.map((row) {
                        final name = (row['product_name'] ??
                                row['productName'] ??
                                row['name'] ??
                                'Product')
                            .toString();
                        final expected = _number(row['expected_quantity'] ??
                            row['expectedQuantity'] ??
                            row['expected_balance'] ??
                            row['expectedBalance'] ??
                            row['expected']);
                        final actual = _number(row['actual_quantity'] ??
                            row['actualQuantity'] ??
                            row['actual']);
                        final variance = _number(row['variance'] ??
                            row['physical_variance'] ??
                            row['physicalVariance'] ??
                            (actual - expected));
                        return Card(
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text(
                                'Expected ${expected.toStringAsFixed(2)} · Actual ${actual.toStringAsFixed(2)} · Variance ${variance.toStringAsFixed(2)}'),
                            trailing: IconButton(
                                tooltip: 'Record tank dip',
                                icon: const Icon(Icons.edit_note),
                                onPressed: () => _recordDip(row)),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Text('Payment methods',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (payments.isEmpty)
                        const ListTile(
                            title: Text('No payment summary returned')),
                      ...payments.map((row) => ListTile(
                            leading: const Icon(Icons.payments_outlined),
                            title: Text((row['method'] ??
                                    row['payment_method'] ??
                                    row['paymentMethod'] ??
                                    row['name'] ??
                                    'Payment')
                                .toString()),
                            trailing: Text(_number(row['amount'] ??
                                    row['total'] ??
                                    row['amount_total'])
                                .toStringAsFixed(2)),
                          )),
                      const SizedBox(height: 12),
                      Text('Bank deposits',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (deposits.isEmpty)
                        const ListTile(
                            title: Text('No bank deposit summary returned')),
                      ...deposits.map((row) => ListTile(
                            leading: const Icon(Icons.account_balance_outlined),
                            title: Text((row['bank_name'] ??
                                    row['bankName'] ??
                                    row['bank'] ??
                                    row['reference'] ??
                                    'Deposit')
                                .toString()),
                            subtitle: Text((row['deposit_date'] ??
                                    row['depositDate'] ??
                                    row['date'] ??
                                    '')
                                .toString()),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_number(row['allocated_amount'] ??
                                        row['amount'] ??
                                        row['total'] ??
                                        row['deposit_amount'])
                                    .toStringAsFixed(2)),
                                if (retail.selectedPetroleumBadgeId != null)
                                  IconButton(
                                    tooltip:
                                        'Allocate deposit to selected badge',
                                    icon: const Icon(Icons.call_split),
                                    onPressed: () => _allocateDeposit(row),
                                  ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
    );
  }
}
