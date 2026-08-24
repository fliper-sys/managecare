import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/theme/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/repositories/sales_repository_impl.dart';

class PharmacyPOSScreen extends StatefulWidget {
  const PharmacyPOSScreen({super.key});

  @override
  State<PharmacyPOSScreen> createState() => _PharmacyPOSScreenState();
}

class _PharmacyPOSScreenState extends State<PharmacyPOSScreen> {
  final List<Map<String, dynamic>> _cartItems = [];
  String _searchQuery = '';
  List<Drug>? _searchResults;

  double get _totalAmount =>
      _cartItems.fold(0.0, (sum, item) => sum + (item['totalPrice'] as double));

  void _performRemoteSearch(String q) async {
    final provider = context.read<PharmacyProvider>();
    final business = context.read<BusinessProvider>().currentBusiness;
    if (q.trim().length >= 2 && provider.hasRemote && business != null) {
      final results = await provider.searchDrugsRemote(q, businessId: business.id);
      setState(() => _searchResults = results);
    } else {
      setState(() => _searchResults = null);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PharmacyProvider>();
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business != null) {
        provider.loadFromRepository(businessId: business.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy POS'),
        backgroundColor: AppColors.pharmacy,
        elevation: 0,
      ),
      body: Consumer<PharmacyProvider>(
        builder: (context, provider, child) {
          var drugs = provider.drugs;

          // Filter by search (prefer remote search results)
          if (_searchQuery.isNotEmpty) {
            if (_searchResults != null) {
              drugs = _searchResults!;
            } else {
              drugs = provider.searchDrugs(_searchQuery);
            }
          }

          // Filter available drugs (with stock)
          drugs = drugs.where((d) => d.stock > 0).toList();

          return Row(
            children: [
              // Left: Drug selection
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _performRemoteSearch(value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search drugs...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: drugs.isEmpty
                          ? Center(
                              child: Text('No available drugs',
                                  style: TextStyle(color: Colors.grey[600])),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              itemCount: drugs.length,
                              itemBuilder: (context, index) {
                                final drug = drugs[index];

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    title: Text(drug.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '₦${drug.price.toStringAsFixed(2)}'),
                                        Text('Stock: ${drug.stock}'),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.add_circle),
                                      color: Colors.green,
                                      onPressed: () => _addToCart(drug),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              // Right: Cart
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Cart header
                    Container(
                      color: Colors.grey[100],
                      padding: const EdgeInsets.all(12),
                      child: const Text('Cart',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    // Cart items
                    Expanded(
                      child: _cartItems.isEmpty
                          ? Center(
                              child: Text('Empty',
                                  style: TextStyle(color: Colors.grey[600])),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _cartItems.length,
                              itemBuilder: (context, index) {
                                final item = _cartItems[index];

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'] as String,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () =>
                                                      _decreaseQty(index),
                                                  icon: const Icon(Icons.remove,
                                                      size: 16),
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                ),
                                                Text('${item['qty']}',
                                                    style: const TextStyle(
                                                        fontSize: 12)),
                                                IconButton(
                                                  onPressed: () =>
                                                      _increaseQty(index),
                                                  icon: const Icon(Icons.add,
                                                      size: 16),
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _removeFromCart(index),
                                              icon: const Icon(Icons.delete,
                                                  size: 16),
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '₦${(item['totalPrice'] as double).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Colors.green),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    // Total and checkout
                    Container(
                      color: Colors.grey[100],
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                '₦${_totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Checkout'),
                            onPressed: _cartItems.isEmpty
                                ? null
                                : () => _completeTransaction(context),
                          ),
                          const SizedBox(height: 4),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: const Text('Clear Cart'),
                            onPressed: () => setState(() => _cartItems.clear()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addToCart(Drug drug) {
    setState(() {
      final existingIndex =
          _cartItems.indexWhere((item) => item['drugId'] == drug.id);

      if (existingIndex >= 0) {
        _cartItems[existingIndex]['qty']++;
        _cartItems[existingIndex]['totalPrice'] =
            _cartItems[existingIndex]['qty'] * drug.price;
      } else {
        _cartItems.add({
          'drugId': drug.id,
          'name': drug.name,
          'price': drug.price,
          'qty': 1,
          'totalPrice': drug.price,
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${drug.name} added to cart')),
    );
  }

  void _increaseQty(int index) {
    setState(() {
      _cartItems[index]['qty']++;
      _cartItems[index]['totalPrice'] =
          _cartItems[index]['qty'] * _cartItems[index]['price'];
    });
  }

  void _decreaseQty(int index) {
    setState(() {
      if (_cartItems[index]['qty'] > 1) {
        _cartItems[index]['qty']--;
        _cartItems[index]['totalPrice'] =
            _cartItems[index]['qty'] * _cartItems[index]['price'];
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
  }

  void _completeTransaction(BuildContext context) {
    final provider = context.read<PharmacyProvider>();
    final business = context.read<BusinessProvider>().currentBusiness;

    // Create a prescription for this sale
    final patientId = 'POS-${DateTime.now().millisecondsSinceEpoch}';
    final items = _cartItems
        .map((item) => {
              'drugId': item['drugId'] as String,
              'qty': item['qty'] as int,
            })
        .toList();

    final capturedAmount = _totalAmount;
    final capturedItems = _cartItems.length;

    provider
        .addPrescription(patientId, items,
            persist: true, businessId: business?.id, userId: 'pos')
        .then((prescription) async {
      // Immediately dispense the prescription
      await provider.dispensePrescription(prescription.id,
          persist: true, businessId: business?.id, userId: 'pos');

      // Record sale in Sales repository
      try {
        final saleData = {
          'businessId': business?.id ?? '',
          'workerId': 'pos',
          'status': 'completed',
          'items': _cartItems
              .map((it) => {
                    'itemId': it['drugId'],
                    'name': it['name'],
                    'qty': it['qty'],
                    'unitPrice': it['price'],
                    'total': it['totalPrice']
                  })
              .toList(),
          'totalAmount': capturedAmount,
          'finalAmount': capturedAmount,
          'createdAt': DateTime.now().toIso8601String(),
        };
        final salesRepo = SalesRepositoryImpl(firestore: FirebaseFirestore.instance);
        await salesRepo.createSale(saleData);
      } catch (_) {}

      // Clear cart
      setState(() => _cartItems.clear());

      // Show success
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Transaction Completed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text('Amount: ₦${capturedAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Items: $capturedItems'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }
}

