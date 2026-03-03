import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/business_provider.dart';
import '../../../core/theme/colors.dart';

class InventorySearchScreen extends StatefulWidget {
  const InventorySearchScreen({super.key});

  @override
  State<InventorySearchScreen> createState() => _InventorySearchScreenState();
}

class _InventorySearchScreenState extends State<InventorySearchScreen> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
  }

  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;

      if (business == null) {
        setState(() => _isLoading = false);
        return;
      }

      final query = _searchController.text.toLowerCase();
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses/${business.id}/inventory')
          .get();

      final results = snapshot.docs
          .where((doc) {
            final name = (doc['name'] as String? ?? '').toLowerCase();
            final sku = (doc['sku'] as String? ?? '').toLowerCase();
            return name.contains(query) || sku.contains(query);
          })
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search inventory...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'Enter a search term'
                        : 'No results found',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    final name = item['name'] as String? ?? 'Product';
                    final sku = item['sku'] as String? ?? 'N/A';
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                    final price = (item['price'] as num? ?? 0).toDouble();

                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text('SKU: $sku | Stock: $quantity'),
                        trailing: Text(
                          '₦${price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

