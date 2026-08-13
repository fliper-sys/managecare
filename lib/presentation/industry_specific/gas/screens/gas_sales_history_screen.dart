import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/amount_formatter.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../../../../services/receipt_manager.dart';
import '../utils/pump_row_mapper.dart';

class GasSalesHistoryScreen extends StatefulWidget {
  const GasSalesHistoryScreen({super.key});

  @override
  State<GasSalesHistoryScreen> createState() => _GasSalesHistoryScreenState();
}

class _GasSalesHistoryScreenState extends State<GasSalesHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _sales = [];
  double _totalAmount = 0.0;
  double _totalVolume = 0.0;
  int _transactions = 0;

  DateTime? _startDate;
  DateTime? _endDate;
  StreamSubscription<Map<String, dynamic>>? _metricsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _historySubscription;

  DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static const _pollInterval = Duration(seconds: 15);

  Stream<List<Map<String, dynamic>>> _dailyUploadsStream(
      String businessId) async* {
    while (true) {
      try {
        final response = await ManagecareApiClient.instance.get(
          '/api/pumps/$businessId/uploads',
          query: {'limit': '100'},
        );
        final rows =
            ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpUploadRowToJson).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  Stream<List<Map<String, dynamic>>> _miniMartSalesStream(
      String businessId) async* {
    while (true) {
      try {
        final sales =
            await context.read<RetailProvider>().getSalesHistory(limit: 150);
        yield sales.where((sale) => !_isFuelSale(sale)).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _metricsSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData({
    DateTime? start,
    DateTime? end,
    int limit = 100,
  }) async {
    setState(() => _loading = true);
    final retail = context.read<RetailProvider>();
    final metrics = await retail.getFuelMetrics(start: start, end: end);
    final history =
        await retail.getFuelSalesHistory(start: start, end: end, limit: limit);

    setState(() {
      _totalAmount = metrics['totalAmount'] ?? 0.0;
      _totalVolume = metrics['totalVolume'] ?? 0.0;
      _transactions = metrics['transactions'] ?? 0;
      _sales = history;
      _loading = false;
    });

    _metricsSubscription?.cancel();
    _historySubscription?.cancel();
    _metricsSubscription =
        retail.watchFuelMetrics(start: start, end: end).listen((metrics) {
      if (!mounted) return;
      setState(() {
        _totalAmount = metrics['totalAmount'] ?? 0.0;
        _totalVolume = metrics['totalVolume'] ?? 0.0;
        _transactions = metrics['transactions'] ?? 0;
        _loading = false;
      });
    });
    _historySubscription = retail
        .watchFuelSalesHistory(start: start, end: end, limit: limit)
        .listen((history) {
      if (!mounted) return;
      setState(() {
        _sales = history;
        _loading = false;
      });
    });
  }

  Future<void> _handleReceiptAction(
    BuildContext context,
    String action,
    String saleId,
  ) async {
    if (saleId.trim().isEmpty) return;

    if (action == 'view') {
      await Navigator.pushNamed(
        context,
        Routes.salesReceipt,
        arguments: saleId,
      );
      return;
    }

    final sale = await context.read<RetailProvider>().getSaleById(saleId);
    if (!context.mounted) return;
    if (sale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load this receipt yet'),
        ),
      );
      return;
    }

    await ReceiptManager.handlePostSale(
      context,
      sale,
      invoiceGeneratedBeforeCheckout: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Sales History')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(
                          () => _startDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          ),
                        );
                      }
                    },
                    child: Text(
                      _startDate == null
                          ? 'Start date'
                          : DateFormat.yMd().format(_startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(
                          () => _endDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            23,
                            59,
                            59,
                          ),
                        );
                      }
                    },
                    child: Text(
                      _endDate == null
                          ? 'End date'
                          : DateFormat.yMd().format(_endDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _loadData(start: _startDate, end: _endDate),
                  child: const Text('Load'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _loadData(limit: 500);
                  },
                  child: const Text('Load All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metricCard('Revenue', 'NGN ${_totalAmount.toStringAsFixed(2)}'),
                const SizedBox(width: 8),
                _metricCard('Volume', '${_totalVolume.toStringAsFixed(3)} L'),
                const SizedBox(width: 8),
                _metricCard('Txns', '$_transactions'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: 'Pump Sales'),
                        Tab(text: 'Mini Mart Sales'),
                        Tab(text: 'Daily Uploads'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildPumpSalesList(),
                          _buildMiniMartSalesList(),
                          _buildDailyUploadsList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isFuelSale(Map<String, dynamic> data) {
    bool isFuelText(String value) {
      final text = value.trim().toLowerCase();
      return text.contains('fuel') ||
          text == 'gas' ||
          text.contains('cooking gas') ||
          text.contains('petrol') ||
          text.contains('petroleum') ||
          text.contains('diesel') ||
          text.contains('deseal') ||
          text.contains('kerosene') ||
          text.contains('pump');
    }

    if (isFuelText(data['category']?.toString() ?? '') ||
        isFuelText(data['order_type']?.toString() ?? '') ||
        isFuelText(data['saleType']?.toString() ?? '')) {
      return true;
    }

    final items = data['items'];
    if (items is! List) return false;
    return items.any((item) {
      if (item is! Map) return false;
      return isFuelText(item['category']?.toString() ?? '') ||
          isFuelText(item['productName']?.toString() ?? '') ||
          isFuelText(item['name']?.toString() ?? '');
    });
  }

  Widget _buildPumpSalesList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_sales.isEmpty) return const Center(child: Text('No fuel sales yet'));
    return ListView.separated(
      itemCount: _sales.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final sale = _sales[index];
        final created = _readDate(sale['createdAt']);
        final dateText = created != null
            ? DateFormat.yMd().add_jm().format(created)
            : (sale['createdAtRaw']?.toString() ?? '');
        final saleId = sale['id']?.toString() ?? '';
        final totalAmount = _readDouble(sale['totalAmount']);
        final fuelVolume = _readDouble(sale['fuelVolume']);

        return ListTile(
          onTap: saleId.isEmpty
              ? null
              : () => Navigator.pushNamed(
                    context,
                    Routes.salesReceipt,
                    arguments: saleId,
                  ),
          leading: saleId.isEmpty
              ? const CircleAvatar(child: Icon(Icons.local_gas_station))
              : PopupMenuButton<String>(
                  onSelected: (value) => _handleReceiptAction(
                    context,
                    value,
                    saleId,
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Text('View Receipt'),
                    ),
                    PopupMenuItem(
                      value: 'reprint',
                      child: Text('Reprint Receipt'),
                    ),
                  ],
                  child: const CircleAvatar(child: Icon(Icons.receipt_long)),
                ),
          title: Text(saleId.isEmpty ? 'Fuel sale' : 'Sale - $saleId'),
          subtitle: Text(dateText),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'NGN ${totalAmount.toStringAsFixed(2)}',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${fuelVolume.toStringAsFixed(3)} L',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniMartSalesList() {
    final businessId = context.watch<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) {
      return const Center(child: Text('No business selected'));
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _miniMartSalesStream(businessId),
      builder: (context, snapshot) {
        final sales = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting &&
            sales.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (sales.isEmpty) {
          return const Center(child: Text('No minimart sales yet'));
        }
        return ListView.separated(
          itemCount: sales.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final data = sales[index];
            final id = (data['id'] ?? '').toString();
            final createdAt =
                _readDate(data['createdAt']) ?? _readDate(data['timestamp']);
            final amount = _readDouble(
              data['totalAmount'] ?? data['total'] ?? data['amount'],
            );
            final itemCount = data['items'] is List
                ? (data['items'] as List).length
                : ((data['quantity'] as num?)?.toInt() ?? 0);

            return ListTile(
              onTap: () => Navigator.pushNamed(
                context,
                Routes.salesReceipt,
                arguments: id,
              ),
              leading: PopupMenuButton<String>(
                onSelected: (value) => _handleReceiptAction(
                  context,
                  value,
                  id,
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'view',
                    child: Text('View Receipt'),
                  ),
                  PopupMenuItem(
                    value: 'reprint',
                    child: Text('Reprint Receipt'),
                  ),
                ],
                child: const CircleAvatar(child: Icon(Icons.storefront)),
              ),
              title: Text('Mini mart sale - $id'),
              subtitle: Text(
                '${createdAt == null ? '' : DateFormat.yMd().add_jm().format(createdAt)}\n'
                'Items: $itemCount',
              ),
              isThreeLine: true,
              trailing: Text(
                'NGN ${amount.toStringAsFixed(2)}',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDailyUploadsList() {
    final businessId = context.watch<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) {
      return const Center(child: Text('No business selected'));
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dailyUploadsStream(businessId),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting &&
            docs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) {
          return const Center(child: Text('No daily uploads yet'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final data = docs[index];
            final uploadedAt =
                _readDate(data['uploadedAt']) ?? _readDate(data['createdAt']);
            final soldVolume = _readDouble(data['soldVolume']);
            final expectedAmount = _readDouble(data['expectedAmount']);
            final digitalVolume = data['digitalVolume'] == null
                ? null
                : _readDouble(data['digitalVolume']);
            final analogClosingVolume = data['analogClosingVolume'] == null
                ? null
                : _readDouble(data['analogClosingVolume']);
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.cloud_upload)),
              title: Text(
                'Pump ${data['pumpNumber'] ?? ''} - ${data['productName'] ?? ''}',
              ),
              subtitle: Text(
                '${uploadedAt == null ? '' : DateFormat.yMd().add_jm().format(uploadedAt)}\n'
                'Operator: ${data['workerName'] ?? 'N/A'}'
                '${digitalVolume == null ? '' : '\nDigital: ${formatAmount(digitalVolume, decimalDigits: 3)} L'}'
                '${analogClosingVolume == null ? '' : ' · Analog: ${formatAmount(analogClosingVolume, decimalDigits: 3)} L'}',
              ),
              isThreeLine: true,
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${formatAmount(soldVolume, decimalDigits: 3)} L',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'NGN ${formatAmount(expectedAmount, decimalDigits: 2)}',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _metricCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.heading5),
          ],
        ),
      ),
    );
  }
}
