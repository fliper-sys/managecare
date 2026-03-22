import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Simple reusable payment method selection sheet.
/// Returns selected payment method as a `String` when confirmed.
import 'package:provider/provider.dart';
import '../../providers/workers_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';

class PaymentMethodSheet extends StatefulWidget {
  final double? amount;
  final String initial;

  const PaymentMethodSheet({super.key, this.amount, this.initial = 'Cash'});

  @override
  State<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<PaymentMethodSheet> {
  late String _selected;
  String? _selectedCashierId;
  bool _isLoadingWorkers = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;

    // Ensure workers are loaded for the current business
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = context.read<BusinessProvider>();
      final businessId = bp.currentBusiness?.id;
      if (businessId != null && businessId.isNotEmpty) {
        final wp = context.read<WorkersProvider>();
        wp.setBusinessId(businessId).whenComplete(() {
          setState(() => _isLoadingWorkers = false);
          // Default cashier to owner if available
          final workers = wp.workers;
          final ownerId = bp.currentBusiness?.ownerId;
          if (ownerId != null && ownerId.isNotEmpty) {
            Map<String, dynamic>? found;
            try {
              found = workers.firstWhere((w) => (w['id'] ?? '') == ownerId);
            } catch (_) {
              found = null;
            }
            if (found != null) {
              _selectedCashierId = found['id'];
            }
          }
          // If still none, default to current user
          if (_selectedCashierId == null) {
            final auth = context.read<AuthProvider>();
            _selectedCashierId = auth.currentUser?.id;
          }
        });
      } else {
        setState(() => _isLoadingWorkers = false);
      }
    });
  }

  String? _getValidCashierId(List<Map<String, dynamic>> workers) {
    // If no selected cashier, return null
    if (_selectedCashierId == null) return null;

    // Check if the selected cashier exists in the workers list
    final exists = workers.any((w) => (w['id'] ?? '') == _selectedCashierId);
    if (exists) {
      return _selectedCashierId;
    }

    // If not found, clear the selection and return null (or first worker if preferred)
    _selectedCashierId = null;
    return null;
  }

  Future<void> _onConfirmPayment() async {
    if (_selectedCashierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a cashier')));
      return;
    }

    // Return the selected payment method as a string
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkersProvider>();
    final auth = context.watch<AuthProvider>();
    final workers = wp.workers;

    // Create extended workers list that includes current user if not already present
    final extendedWorkers = List<Map<String, dynamic>>.from(workers);
    final currentUserId = auth.currentUser?.id;
    final currentUserExists = workers.any((w) => (w['id'] ?? '') == currentUserId);
    if (currentUserId != null && !currentUserExists) {
      extendedWorkers.insert(0, {
        'id': currentUserId,
        'name': auth.currentUser?.fullName ?? auth.currentUser?.email ?? 'Current User',
        'fullName': auth.currentUser?.fullName,
        'email': auth.currentUser?.email,
      });
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.amount != null) Text('Total: ₦${widget.amount!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // Cashier selection
            const Text('Cashier', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_isLoadingWorkers)
              const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
            else
              DropdownButtonFormField<String>(
                value: _getValidCashierId(extendedWorkers),
                items: extendedWorkers.map((w) {
                  final id = (w['id'] ?? '') as String;
                  final name = (w['name'] ?? w['fullName'] ?? w['email'] ?? id) as String;
                  return DropdownMenuItem(value: id, child: Text(name));
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedCashierId = v;
                  });
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),

            const SizedBox(height: 12),

            RadioListTile<String>(
              title: const Text('Cash'),
              value: 'Cash',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
            RadioListTile<String>(
              title: const Text('Card'),
              value: 'Card',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
            RadioListTile<String>(
              title: const Text('Transfer'),
              value: 'Transfer',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _onConfirmPayment,
                child: const Text('Confirm Payment'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
