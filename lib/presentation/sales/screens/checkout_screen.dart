import 'package:flutter/material.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? selectedPaymentMethod;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const ListTile(
              title: Text('Subtotal'),
              trailing: Text('\$75'),
            ),
            const ListTile(
              title: Text('Tax'),
              trailing: Text('\$7.50'),
            ),
            const ListTile(
              title: Text('Total'),
              trailing: Text('\$82.50',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildPaymentOption('Cash'),
            _buildPaymentOption('Card'),
            _buildPaymentOption('Mobile Money'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                    context, Routes.salesReceipt,
                    arguments: {'saleId': '123'}),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Complete Purchase'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String method) {
    return RadioListTile<String>(
      title: Text(method),
      value: method,
      groupValue: selectedPaymentMethod,
      onChanged: (value) => setState(() => selectedPaymentMethod = value),
    );
  }
}

