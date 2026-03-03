import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/receipt_settings_provider.dart';
import '../../../../presentation/sales/screens/receipt_screen.dart';

class RetailReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> sale;
  final String businessId;

  const RetailReceiptScreen({
    required this.sale,
    required this.businessId,
    super.key,
  });

  @override
  State<RetailReceiptScreen> createState() => _RetailReceiptScreenState();
}

class _RetailReceiptScreenState extends State<RetailReceiptScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure receipt settings are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final receiptProvider =
          Provider.of<ReceiptSettingsProvider>(context, listen: false);
      receiptProvider.fetchReceiptSettings(widget.businessId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Route to the main ReceiptScreen with the sale data
    return ReceiptScreen(
      sale: widget.sale,
      isSubscriptionReceipt: false,
      isInvoice: false,
    );
  }
}

