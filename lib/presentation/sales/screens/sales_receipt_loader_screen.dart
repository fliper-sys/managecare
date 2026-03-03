import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/business_provider.dart';
import '../../../core/theme/colors.dart';
import 'receipt_screen.dart';

/// Loader screen that fetches sale data by ID and displays the receipt
class SalesReceiptLoaderScreen extends StatefulWidget {
  final String saleId;

  const SalesReceiptLoaderScreen({super.key, required this.saleId});

  @override
  State<SalesReceiptLoaderScreen> createState() =>
      _SalesReceiptLoaderScreenState();
}

class _SalesReceiptLoaderScreenState extends State<SalesReceiptLoaderScreen> {
  late Future<Map<String, dynamic>?> _saleFuture;

  @override
  void initState() {
    super.initState();
    _saleFuture = _loadSaleData();
  }

  Future<Map<String, dynamic>?> _loadSaleData() async {
    try {
      final businessId =
          context.read<BusinessProvider>().currentBusiness?.id;
      if (businessId == null || businessId.isEmpty) {
        return null;
      }

      // Try to fetch from sales collection
      final saleDoc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .doc(widget.saleId)
          .get();

      if (saleDoc.exists) {
        final saleData = saleDoc.data() ?? {};
        return {
          'id': saleDoc.id,
          ...saleData,
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error loading sale data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _saleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading Receipt'),
              backgroundColor: AppColors.primary,
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Receipt'),
              backgroundColor: AppColors.primary,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text('Could not load receipt details'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        // Display the receipt with loaded sale data
        return ReceiptScreen(
          sale: snapshot.data ?? {},
          isSubscriptionReceipt: false,
          isInvoice: false,
        );
      },
    );
  }
}
