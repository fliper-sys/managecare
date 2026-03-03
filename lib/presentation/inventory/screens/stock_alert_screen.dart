import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/repositories/alert_repository_impl.dart';
import '../../../providers/business_provider.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';

class StockAlertScreen extends StatefulWidget {
  const StockAlertScreen({super.key});

  @override
  State<StockAlertScreen> createState() => _StockAlertScreenState();
}

class _StockAlertScreenState extends State<StockAlertScreen> {
  late AlertRepositoryImpl _repository;
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = AlertRepositoryImpl(firestore: FirebaseFirestore.instance);
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
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

      final alerts =
          await _repository.getAlerts(business.id, type: 'stock_alert');

      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load alerts: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Alerts'),
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
                        onPressed: _loadAlerts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _alerts.isEmpty
                  ? const Center(child: Text('No stock alerts'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      itemBuilder: (context, index) {
                        final alert = _alerts[index];
                        final productName =
                            alert['productName'] as String? ?? 'Product';
                        final currentStock = alert['currentStock'] as int? ?? 0;
                        final minStock = alert['minStock'] as int? ?? 5;
                        final productId = alert['productId'] as String? ?? '';

                        return Card(
                          child: ListTile(
                            leading:
                                const Icon(Icons.warning, color: Colors.orange),
                            title: Text(productName),
                            subtitle: Text(
                              'Stock: $currentStock units (Min: $minStock)',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                Routes.inventoryEdit,
                                arguments: {'productId': productId},
                              ),
                              child: const Text('Restock'),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

