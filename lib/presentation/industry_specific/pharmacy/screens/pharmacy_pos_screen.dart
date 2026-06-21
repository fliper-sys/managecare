import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/email_service.dart';
import '../../../../services/notification_and_email_service.dart';
import '../../../../services/business_notification_manager.dart';

import '../../../industry_specific/retail/widgets/pos_product_card.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import 'pharmacy_expiry_screen.dart';
import '../../../../core/constants/routes.dart';

class PharmacyPosScreen extends StatefulWidget {
  const PharmacyPosScreen({super.key});

  @override
  State<PharmacyPosScreen> createState() => _PharmacyPosScreenState();
}

class _PharmacyPosScreenState extends State<PharmacyPosScreen> {
  final Map<String, int> _cart = {}; // drugId -> qty
  String? _customerName;
  String? _selectedPatientId;
  String? _prescriptionNote;
  // drugId -> selected saved-prescription map ({ageRange, intensity, dosage})
  final Map<String, Map<String, dynamic>> _selectedPrescriptions = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(String id) {
    setState(() => _cart.update(id, (v) => v + 1, ifAbsent: () => 1));
  }

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  Future<void> _showCart(PharmacyProvider provider) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final controller = TextEditingController(text: _customerName ?? '');
        final prescriptionNoteController =
            TextEditingController(text: _prescriptionNote ?? '');
        return StatefulBuilder(
          builder: (context, setModalState) {
            double subtotal() {
              double s = 0.0;
              for (final entry in _cart.entries) {
                Drug? drug;
                try {
                  drug = provider.drugs.firstWhere((d) => d.id == entry.key);
                } catch (_) {
                  drug = null;
                }
                if (drug != null) s += drug.price * entry.value;
              }
              return s;
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              builder: (sheetContext, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cart', style: AppTextStyles.heading4),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _cart.isEmpty
                              ? const Center(child: Text('Cart is empty'))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: _cart.length,
                                  itemBuilder: (context, index) {
                                    final entry = _cart.entries.elementAt(index);
                                    Drug? drug;
                                    try {
                                      drug = provider.drugs.firstWhere(
                                        (d) => d.id == entry.key,
                                      );
                                    } catch (_) {
                                      drug = null;
                                    }
                                    if (drug == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final qty = entry.value;
                                    final selectedPres =
                                        _selectedPrescriptions[entry.key];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(drug.name),
                                            subtitle: Text(
                                              '₦${drug.price.toStringAsFixed(2)} x $qty',
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                  ),
                                                  onPressed: () {
                                                    setModalState(() {
                                                      final newQty =
                                                          (_cart[entry.key]! - 1)
                                                              .clamp(0, 999999);
                                                      if (newQty <= 0) {
                                                        _cart.remove(entry.key);
                                                        _selectedPrescriptions
                                                            .remove(entry.key);
                                                      } else {
                                                        _cart[entry.key] = newQty;
                                                      }
                                                    });
                                                    setState(() {});
                                                  },
                                                ),
                                                Text('$qty'),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                  ),
                                                  onPressed: () {
                                                    setModalState(() {
                                                      _cart.update(
                                                        entry.key,
                                                        (v) => v + 1,
                                                      );
                                                    });
                                                    setState(() {});
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.delete_outline),
                                                  onPressed: () {
                                                    setModalState(() {
                                                      _cart.remove(entry.key);
                                                      _selectedPrescriptions
                                                          .remove(entry.key);
                                                    });
                                                    setState(() {});
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (drug.prescriptions.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 6),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.description_outlined,
                                                      size: 16,
                                                      color: Colors.grey[600]),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: TextButton(
                                                      style: TextButton.styleFrom(
                                                        padding: EdgeInsets.zero,
                                                        alignment:
                                                            Alignment.centerLeft,
                                                      ),
                                                      onPressed: () async {
                                                        final chosen =
                                                            await showModalBottomSheet<
                                                                Map<String,
                                                                    dynamic>?>(
                                                          context: context,
                                                          builder: (sheetCtx) =>
                                                              SafeArea(
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize.min,
                                                              children: [
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(12),
                                                                  child: Text(
                                                                    'Saved prescriptions for ${drug.name}',
                                                                    style: AppTextStyles
                                                                        .body1,
                                                                  ),
                                                                ),
                                                                ...drug.prescriptions
                                                                    .map((p) =>
                                                                        ListTile(
                                                                          title: Text(
                                                                              '${p['ageRange'] ?? ''} • ${p['intensity'] ?? ''}'),
                                                                          subtitle:
                                                                              Text(
                                                                            p['dosage']?.toString() ??
                                                                                '',
                                                                          ),
                                                                          onTap: () =>
                                                                              Navigator.pop(
                                                                                  sheetCtx,
                                                                                  p),
                                                                        )),
                                                                ListTile(
                                                                  title: const Text(
                                                                      'None (write dosage manually)'),
                                                                  onTap: () =>
                                                                      Navigator.pop(
                                                                          sheetCtx,
                                                                          null),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                        setModalState(() {
                                                          if (chosen != null) {
                                                            _selectedPrescriptions[
                                                                    entry.key] =
                                                                chosen;
                                                          } else {
                                                            _selectedPrescriptions
                                                                .remove(entry.key);
                                                          }
                                                        });
                                                      },
                                                      child: Text(
                                                        selectedPres == null
                                                            ? 'Use saved prescription'
                                                            : 'Rx: ${selectedPres['dosage']}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: selectedPres ==
                                                                  null
                                                              ? Colors.grey[700]
                                                              : AppColors.primary,
                                                        ),
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const Divider(height: 1),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        // Patient picker - replaces free-text customer name.
                        // Selecting "Walk-in / No patient" keeps the sale
                        // available for non-patient customers.
                        DropdownButtonFormField<String>(
                          value: _selectedPatientId,
                          decoration: const InputDecoration(
                            labelText: 'Patient',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Walk-in / No patient'),
                            ),
                            ...provider.patients
                                .where((p) => p != null)
                                .map((p) => DropdownMenuItem<String>(
                                      value: p!.id,
                                      child: Text(p.name),
                                    )),
                          ],
                          onChanged: (value) {
                            setModalState(() {
                              _selectedPatientId = value;
                              if (value != null) {
                                final match = provider.patients.firstWhere(
                                  (p) => p?.id == value,
                                  orElse: () => null,
                                );
                                controller.text = match?.name ?? '';
                              } else {
                                controller.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Patient / Customer name',
                            helperText:
                                'Auto-filled from patient above, or type a walk-in name',
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Free-text prescription note - printed alongside
                        // the receipt (item #6). Used when the attendant
                        // wants to write dosage/instructions manually
                        // instead of (or in addition to) a saved
                        // prescription selected per drug above.
                        TextField(
                          controller: prescriptionNoteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Prescription / Dosage Note (optional)',
                            helperText:
                                'Printed on the receipt alongside the items',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal: ₦${subtotal().toStringAsFixed(2)}',
                              style: AppTextStyles.body1,
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setModalState(() => _cart.clear());
                                    setState(() {});
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Clear'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    _customerName = controller.text.trim().isEmpty
                                        ? null
                                        : controller.text.trim();
                                    _prescriptionNote = prescriptionNoteController
                                            .text.trim().isEmpty
                                        ? null
                                        : prescriptionNoteController.text.trim();
                                    Navigator.pop(ctx);
                                    _confirmSale(
                                      provider,
                                      customerName: _customerName,
                                      patientId: _selectedPatientId,
                                      prescriptionNote: _prescriptionNote,
                                    );
                                  },
                                  child: const Text('Checkout'),
                                ),
                              ],
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
      },
    );
  }

  Future<void> _confirmSale(
    PharmacyProvider provider, {
    String? customerName,
    String? patientId,
    String? prescriptionNote,
  }) async {
    if (_cart.isEmpty) return;

    try {
      // Prepare items list
      final items = <Map<String, dynamic>>[];
      final businessProvider =
          Provider.of<BusinessProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final businessId = businessProvider.currentBusiness?.id ??
          authProvider.currentUser?.businessId;

      if (businessId == null || businessId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business ID not found')),
        );
        return;
      }

      // Prepare items list and check stock availability
      for (final e in _cart.entries) {
        final drugId = e.key;
        final qty = e.value;
        final drug = provider.drugs.firstWhere((d) => d.id == drugId);

        if (drug.stock < qty) {
          throw Exception('Insufficient stock for ${drug.name}');
        }

        items.add({
          'drugId': drugId,
          'productName': drug.name,
          'qty': qty,
          'unitPrice': drug.price,
          'total': drug.price * qty,
        });
      }

      // Build prescription line items from any saved drug-level
      // prescriptions the attendant selected while building the cart
      // (item #9) - these are printed alongside the receipt.
      final prescriptionLines = <Map<String, dynamic>>[];
      for (final entry in _selectedPrescriptions.entries) {
        Drug? drug;
        try {
          drug = provider.drugs.firstWhere((d) => d.id == entry.key);
        } catch (_) {
          drug = null;
        }
        if (drug == null) continue;
        final pres = entry.value;
        final ageRange = pres['ageRange']?.toString() ?? '';
        final intensity = pres['intensity']?.toString() ?? '';
        final dosage = pres['dosage']?.toString() ?? '';
        prescriptionLines.add({
          'drugName': drug.name,
          'dosage': [
            if (ageRange.isNotEmpty) ageRange,
            if (intensity.isNotEmpty) intensity,
            if (dosage.isNotEmpty) dosage,
          ].join(' - '),
        });
      }

      // Ask for tax and discount
      final taxDiscountData = await showDialog<Map<String, double>>(
            context: context,
            builder: (ctx) => _TaxDiscountDialog(),
          ) ??
          {'tax': 0.0, 'discount': 0.0};

      final taxRate = taxDiscountData['tax'] ?? 0.0;
      final discount = taxDiscountData['discount'] ?? 0.0;

      // Ask for payment method
      final paymentMethod = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Cash'),
                    onTap: () => Navigator.pop(ctx, 'Cash'),
                  ),
                  ListTile(
                    title: const Text('Debit/Credit Card'),
                    onTap: () => Navigator.pop(ctx, 'Debit/Credit Card'),
                  ),
                  ListTile(
                    title: const Text('Digital Wallet'),
                    onTap: () => Navigator.pop(ctx, 'Digital Wallet'),
                  ),
                  ListTile(
                    title: const Text('Cancel'),
                    onTap: () => Navigator.pop(ctx, 'Cash'),
                  ),
                ],
              ),
            ),
          ) ??
          'Cash';

      final receiptNumber = 'PHARM-${DateTime.now().millisecondsSinceEpoch}';
      final subtotal = items.fold<double>(
          0.0, (sum, item) => sum + (item['total'] as num));
      final taxAmount = subtotal * (taxRate / 100);
      final finalTotal = subtotal + taxAmount - discount;
      
      final saleData = {
        'orderId': receiptNumber,
        'items': items,
        'subtotal': subtotal,
        'tax': taxAmount,
        'taxRate': taxRate,
        'discount': discount,
        'total': finalTotal,
        'customerName': customerName ?? 'Walk-in',
        if (patientId != null) 'patientId': patientId,
        if (prescriptionNote != null) 'prescriptionNote': prescriptionNote,
        if (prescriptionLines.isNotEmpty) 'prescriptionLines': prescriptionLines,
        'paymentMethod': paymentMethod,
        'totalAmount': finalTotal,
        'finalAmount': finalTotal,
        'type': 'pharmacy_walkin',
        'category': 'Pharmacy',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Perform Firestore transaction to atomically update inventory and add sale
      final firestore = FirebaseFirestore.instance;
      await firestore.runTransaction((tx) async {
        final businessRef = firestore.collection('businesses').doc(businessId);

        // Validate and update inventory docs
        for (final e in _cart.entries) {
          final drugId = e.key;
          final qty = e.value;
          final invDocRef = businessRef.collection('inventory').doc(drugId);
          final invSnap = await tx.get(invDocRef);

          if (!invSnap.exists) {
            throw Exception('Inventory item not found for $drugId');
          }

          final currentQty = (invSnap.data()?['quantity'] as num?)?.toInt() ?? 0;
          if (currentQty < qty) {
            throw Exception('Insufficient stock for ${invSnap.data()?['name'] ?? drugId}');
          }

          final newQty = (currentQty - qty).clamp(0, 999999);
          tx.update(invDocRef, {'quantity': newQty, 'updatedAt': DateTime.now().toIso8601String()});
        }

        // Add sale record
        final salesRef = businessRef.collection('sales');
        tx.set(salesRef.doc(), saleData);
      });

      // Upon successful transaction, update local provider cache and persist
      for (final e in _cart.entries) {
        final drugId = e.key;
        final qty = e.value;
        final drug = provider.drugs.firstWhere((d) => d.id == drugId);
        final newStock = (drug.stock - qty).clamp(0, 999999);
        await provider.updateDrugStock(drugId, newStock, persist: true, businessId: businessId);
      }

      // Add prescription record for tracking (persist to remote and local cache)
      final prescription = await provider.addPrescription(
          patientId ?? 'WALKIN',
          items.map((e) => {'drugId': e['drugId'], 'qty': e['qty']}).toList(),
          patientName: customerName,
          persist: true,
          businessId: businessId,
          userId: authProvider.currentUser?.id);

      setState(() {
        _cart.clear();
        _customerName = null;
        _selectedPatientId = null;
        _prescriptionNote = null;
        _selectedPrescriptions.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Sale completed and inventory updated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Send push notification to business owners
      try {
        final totalAmt = (saleData['total'] as num?)?.toDouble() ?? 0.0;
        await BusinessNotificationManager.instance.notifySaleCompleted(
          businessId: businessId,
          customerName: customerName ?? 'Walk-in Customer',
          amount: totalAmt,
          paymentMethod: paymentMethod,
        );

        if (totalAmt > 100) {
          await BusinessNotificationManager.instance.notifyLargeSale(
            businessId: businessId,
            customerName: customerName ?? 'Walk-in Customer',
            amount: totalAmt,
          );
        }
      } catch (e) {
        debugPrint('[PharmacyPOS] Push notification failed: $e');
      }

      // Prepare receipt map
      final saleMap = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'items': items
            .map((e) => {
                  'productName': e['productName'],
                  'quantity': e['qty'],
                  'unitPrice': e['unitPrice'],
                  'total': e['total'],
                })
            .toList(),
        'subtotal': saleData['subtotal'],
        'tax': saleData['tax'],
        'discount': saleData['discount'],
        'total': saleData['total'],
        'totalAmount': saleData['totalAmount'],
        'finalAmount': saleData['finalAmount'],
        'paymentMethod': paymentMethod,
        'date': DateTime.now().toIso8601String(),
        'customer': {'name': customerName ?? 'Walk-in', 'email': null},
        'category': 'Pharmacy',
        if (prescriptionNote != null) 'prescriptionNote': prescriptionNote,
        if (prescriptionLines.isNotEmpty) 'prescriptionLines': prescriptionLines,
        'prescriptionId': prescription.id,
        'prescriptionPatientName':
            prescription.patientName ?? customerName ?? 'Walk-in',
        'prescriptionCreatedAt':
            prescription.createdAt.toIso8601String(),
        'prescriptionItems': items
            .map((e) => {
                  'drugId': e['drugId'],
                  'name': e['productName'],
                  'qty': e['qty'],
                })
            .toList(),
      };

      // Show receipt actions
      try {
        if (mounted) {
          await ReceiptManager.handlePostSale(
            context,
            saleMap,
            invoiceGeneratedBeforeCheckout: true,
          );
        } else {
          debugPrint('[PharmacyPOS] Skipping post-sale UI because widget is unmounted');
        }
      } catch (e) {
        debugPrint('[PharmacyPOS] Receipt error: $e');
      }

      // Send order success email to business owner and always attempt an owner notification
      try {
        final firestore = FirebaseFirestore.instance;
        final businessDoc = await firestore.collection('businesses').doc(businessId).get();
        final businessData = businessDoc.data() ?? <String, dynamic>{};
        final ownerEmail = (businessData['email'] as String?) ?? '';
        final businessName = (businessData['name'] as String?) ?? 'Your Business';

        // Also send to staff user if Pro (existing behavior)
        try {
          final userEmail = authProvider.currentUser?.email;
          final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
          final canSendOrderEmail =
              businessProvider.hasFeatureAccess('email_receipts');

          if (userEmail != null &&
              userEmail.isNotEmpty &&
              canSendOrderEmail) {
            await EmailService().sendOrderSuccessAlert(
              userEmail,
              {
                'order_type': 'pharmacy_walkin',
                'itemsCount': items.length.toString(),
                'total': saleData['total'].toString(),
              },
            );
          }
        } catch (_) {
          // ignore staff email failures
        }

        // Always attempt to send a detailed sales notification to the business owner
        if (ownerEmail.isNotEmpty) {
          final notif = NotificationAndEmailService();
          final itemsForEmail = items
              .map((e) => {
                    'productName': e['productName'],
                    'quantity': e['qty'],
                    'unitPrice': e['unitPrice']
                  })
              .toList();

          final totalAmt = (saleData['total'] as num?)?.toDouble() ?? 0.0;

          final success = await notif.sendSalesNotification(
            ownerEmail: ownerEmail,
            businessName: businessName,
            customerName: customerName ?? 'Walk-in',
            customerEmail: '',
            totalAmount: totalAmt,
            items: itemsForEmail,
            paymentMethod: paymentMethod,
            receiptNumber: receiptNumber,
            businessId: businessId,
          );

          // Log notification attempt
          await notif.logNotificationEvent(
            businessId: businessId,
            type: 'sale',
            channel: 'email',
            recipient: ownerEmail,
            success: success,
            orderId: receiptNumber,
          );
        }
      } catch (e) {
        debugPrint('[PharmacyPOS] Owner email failed: $e');
      }
    } catch (e) {
      debugPrint('[PharmacyPOS] Error during checkout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    final expiring = provider.expiringWithin(const Duration(days: 7));
    final lowStock = provider.lowStock(threshold: 5);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pharmacy POS'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(
              Routes.pharmacyAddPrescription,
            ),
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Prescribe to a patient',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    onPressed: () => _showCart(provider),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    tooltip: 'View cart',
                  ),
                  if (_cartCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.error,
                        child: Text('$_cartCount',
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (expiring.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PharmacyExpiryScreen(),
                ),
              ),
              child: Container(
                width: double.infinity,
                color: AppColors.warning.withOpacity(0.12),
                padding: const EdgeInsets.all(12),
                child: Text(
                    'Expiry Alert: ${expiring.length} item(s) expiring soon',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.warning)),
              ),
            ),
          if (lowStock.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.error.withOpacity(0.08),
              padding: const EdgeInsets.all(12),
              child: Text('Low Stock: ${lowStock.length} item(s) low on stock',
                  style: AppTextStyles.body2.copyWith(color: AppColors.error)),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search drugs or batch',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Show cached/fallback hint if provider indicates it
                  if (provider.usingLocalCache == true)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Showing cached/fallback data — remote fetch may be partial',
                          style: AppTextStyles.caption.copyWith(color: Colors.black87)),
                    ),
                  // Grid / no-results
                  Expanded(
                    child: Builder(builder: (ctx) {
                      final filtered = provider.drugs
                          .where((d) => _searchQuery.isEmpty
                              ? true
                              : d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                  d.batch.toLowerCase().contains(_searchQuery.toLowerCase()))
                          .toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('No drugs match your search'));
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          int crossAxisCount = 2;
                          if (width >= 1200) {
                            crossAxisCount = 6;
                          } else if (width >= 800) {
                            crossAxisCount = 4;
                          }

                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.86,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12),
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                          final d = filtered[idx];
                          return PosProductCard(
                            id: d.id,
                            name: d.name,
                            price: d.price,
                            stock: d.stock,
                            onAdd: () => _addToCart(d.id),
                          );
                        },
                      );
                    });}),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                    child:
                        Text('Items: $_cartCount', style: AppTextStyles.body2)),
                ElevatedButton(
                  onPressed: _cart.isEmpty ? null : () => _confirmSale(provider),
                  child: const Text('Confirm Sale'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxDiscountDialog extends StatefulWidget {
  const _TaxDiscountDialog();

  @override
  State<_TaxDiscountDialog> createState() => _TaxDiscountDialogState();
}

class _TaxDiscountDialogState extends State<_TaxDiscountDialog> {
  late TextEditingController _taxRateController;
  late TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    _taxRateController = TextEditingController(text: '0');
    _discountController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tax & Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _taxRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Tax Rate (%)',
              hintText: '0',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Discount (₦)',
              hintText: '0',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final tax = double.tryParse(_taxRateController.text) ?? 0;
            final discount = double.tryParse(_discountController.text) ?? 0;
            Navigator.pop(context, {'tax': tax, 'discount': discount});
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
