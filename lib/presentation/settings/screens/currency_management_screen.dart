import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../data/models/currency_model.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/custom_app_bar.dart';

class CurrencyManagementScreen extends StatefulWidget {
  const CurrencyManagementScreen({super.key});

  @override
  State<CurrencyManagementScreen> createState() =>
      _CurrencyManagementScreenState();
}

class _CurrencyManagementScreenState extends State<CurrencyManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Currency Management',
        showBackButton: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCurrencyDialog(context),
        tooltip: 'Add Currency',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Currencies'),
              Tab(text: 'Exchange Rates'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCurrenciesTab(context),
                _buildExchangeRatesTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrenciesTab(BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (context, provider, _) {
        if (provider.currencies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.currency_exchange,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Currencies',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add currencies to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[400],
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: provider.currencies.length,
          itemBuilder: (context, index) {
            final currency = provider.currencies[index];
            final isDefault = currency.isDefault;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDefault
                      ? Colors.green.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${currency.code} - ${currency.name}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Symbol: ${currency.symbol}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Default',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Decimal Places: ${currency.decimalPlaces}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (!isDefault)
                          ElevatedButton.icon(
                            onPressed: () =>
                                provider.setDefaultCurrency(currency.code),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Make Default'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExchangeRatesTab(BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (context, provider, _) {
        if (provider.rates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Exchange Rates',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddRateDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Rate'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: provider.rates.length,
          itemBuilder: (context, index) {
            final rate = provider.rates[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rate.isExpired
                      ? Colors.red.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${rate.baseCurrency} → ${rate.targetCurrency}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rate: ${rate.rate.toStringAsFixed(4)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                        if (rate.isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Expired',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expires: ${_formatDate(rate.expiryDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (rate.isExpired)
                          ElevatedButton.icon(
                            onPressed: () =>
                                _showAddRateDialog(context, rate: rate),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Update'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCurrencyDialog(BuildContext context) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final symbolController = TextEditingController();
    final decimalController = TextEditingController(text: '2');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Currency'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Currency Code (e.g., USD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Currency Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: symbolController,
                decoration: const InputDecoration(
                  labelText: 'Symbol',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: decimalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Decimal Places',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = context.read<CurrencyProvider>();
              final success = await provider.addCurrency(
                code: codeController.text,
                name: nameController.text,
                symbol: symbolController.text,
                decimalPlaces: int.tryParse(decimalController.text) ?? 2,
              );

              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Currency added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddRateDialog(BuildContext context, {CurrencyRate? rate}) {
    final provider = context.read<CurrencyProvider>();
    final baseController =
        TextEditingController(text: rate?.baseCurrency ?? '');
    final targetController =
        TextEditingController(text: rate?.targetCurrency ?? '');
    final rateController =
        TextEditingController(text: rate?.rate.toString() ?? '');
    final daysController = TextEditingController(text: '365');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(rate != null ? 'Update Exchange Rate' : 'Add Exchange Rate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue:
                    baseController.text.isNotEmpty ? baseController.text : null,
                items: provider.currencies
                    .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.code),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    baseController.text = value;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'From Currency',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: targetController.text.isNotEmpty
                    ? targetController.text
                    : null,
                items: provider.currencies
                    .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.code),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    targetController.text = value;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'To Currency',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Exchange Rate',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valid for (days)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await provider.addExchangeRate(
                baseCurrency: baseController.text,
                targetCurrency: targetController.text,
                rate: double.tryParse(rateController.text) ?? 1.0,
                expiryDate: DateTime.now().add(
                    Duration(days: int.tryParse(daysController.text) ?? 365)),
              );

              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exchange rate added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: Text(rate != null ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

