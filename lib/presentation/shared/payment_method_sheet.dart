import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Simple reusable payment method selection sheet.
/// Returns selected payment method as a `String` when confirmed.
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? _selectedCashierName;
  bool _isVerifying = false;
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
              _selectedCashierName = (found['name'] ?? found['fullName'] ?? 'Owner');
            }
          }
          // If still none, default to current user
          if (_selectedCashierId == null) {
            final auth = context.read<AuthProvider>();
            _selectedCashierId = auth.currentUser?.id;
            _selectedCashierName = auth.currentUser?.fullName ?? auth.currentUser?.email;
          }
        });
      } else {
        setState(() => _isLoadingWorkers = false);
      }
    });
  }

  Future<String?> _fetchPinForUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('pin')) return data['pin']?.toString();
      }
    } catch (_) {}

    try {
      final doc = await FirebaseFirestore.instance.collection('workers').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('pin')) return data['pin']?.toString();
      }
    } catch (_) {}

    return null;
  }

  Future<bool> _promptForPinAndVerify(String cashierId) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(hintText: '4-digit PIN'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final pin = controller.text.trim();
              if (pin.length != 4) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a 4-digit PIN')));
                return;
              }

              Navigator.of(ctx).pop(pin == await _fetchPinForUser(cashierId));
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _onConfirmPayment() async {
    if (_selectedCashierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a cashier')));
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final ok = await _promptForPinAndVerify(_selectedCashierId!);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
        setState(() => _isVerifying = false);
        return;
      }

      // Return a map with method and cashier info
      final result = {
        'method': _selected,
        'cashierId': _selectedCashierId,
        'cashierName': _selectedCashierName,
      };
      Navigator.of(context).pop(result);
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkersProvider>();
    final workers = wp.workers;

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
                value: _selectedCashierId,
                items: workers.map((w) {
                  final id = (w['id'] ?? '') as String;
                  final name = (w['name'] ?? w['fullName'] ?? w['email'] ?? id) as String;
                  return DropdownMenuItem(value: id, child: Text(name));
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedCashierId = v;
                    Map<String, dynamic>? found;
                    try {
                      if (v != null) found = workers.firstWhere((w) => (w['id'] ?? '') == v);
                    } catch (_) {
                      found = null;
                    }
                    _selectedCashierName = found != null ? (found['name'] ?? found['fullName'] ?? found['email']) : null;
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
                onPressed: _isVerifying ? null : _onConfirmPayment,
                child: _isVerifying ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirm Payment'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
