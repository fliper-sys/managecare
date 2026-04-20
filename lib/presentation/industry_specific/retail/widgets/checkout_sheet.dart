import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../data/repositories/worker_repository_impl.dart';
import '../../../../widgets/profile_avatar.dart';
import '../../../../services/business_notification_manager.dart';
import '../../../../services/web_download.dart' as web_download;
import '../../../../services/pdf_invoice_generator.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/customer_provider.dart';
import '../../../../data/models/customer_model.dart';

class CheckoutSheet extends StatefulWidget {
  final ScrollController? scrollController;
  const CheckoutSheet({super.key, this.scrollController});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  bool _loadingWorkers = false;
  String? _selectedStoreId;
  String? _selectedWorkerId;
  String? _selectedWorkerName;
  late TextEditingController _taxCtrl;
  late TextEditingController _discountCtrl;
  // Editable tax/discount
  double _taxPercent = 0.0;
  double _discountAmount = 0.0;

  // Worker switching
  List<Map<String, dynamic>> _workers = [];

  // Payment method selection
  String _selectedPaymentMethod = 'Cash';
  final List<String> _paymentMethods = ['Cash', 'Card', 'Transfer', 'Mobile Money'];
  CustomerModel? _selectedCustomer;

  @override
  void dispose() {
    _taxCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _taxCtrl = TextEditingController(text: _taxPercent.toStringAsFixed(2));
    _discountCtrl =
        TextEditingController(text: _discountAmount.toStringAsFixed(2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final retail = Provider.of<RetailProvider>(context, listen: false);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (retail.stores.isEmpty) retail.loadStores();
        _selectedStoreId = auth.currentUser?.storeId;

        // Initialize worker selection and load available workers for the current business
        _selectedWorkerId = auth.currentUser?.id;
        _selectedWorkerName = auth.currentUser?.fullName;
        _loadWorkers();
        _loadCustomers();
      } catch (_) {}
    });
  }

  bool _canApplyDiscount(AuthProvider auth) {
    final role = auth.currentUser?.role ?? '';
    return auth.isOwnerUser || WorkerPermissions.canApplyDiscount(role);
  }

  double _calculateSubtotal(RetailProvider provider) {
    double subtotal = 0.0;
    for (final entry in provider.cartItems.entries) {
      final effectivePrice = provider.getEffectivePriceForCartItem(entry.key.id);
      subtotal += effectivePrice * entry.value;
    }
    return subtotal;
  }

  Future<void> _loadCustomers() async {
    try {
      final businessId = Provider.of<BusinessProvider>(context, listen: false)
              .currentBusiness
              ?.id ??
          context.read<AuthProvider>().currentUser?.businessId ?? '';
      if (businessId.isEmpty) return;

      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      customerProvider.setBusinessId(businessId);
      if (customerProvider.customers.isEmpty && !customerProvider.isLoading) {
        await customerProvider.loadCustomers();
      }
      if (!mounted) return;
      setState(() => _selectedCustomer = customerProvider.selectedCustomer);
    } catch (e) {
      debugPrint('[CheckoutSheet] Failed to load customers: $e');
    }
  }

  Future<void> _loadWorkers() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId =
          Provider.of<BusinessProvider>(context, listen: false)
              .currentBusiness
              ?.id ??
          auth.currentUser?.primaryBusinessId ??
          auth.currentUser?.businessId ??
          '';
      if (businessId.isEmpty) return;
      setState(() => _loadingWorkers = true);
      final repo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
      final list = await repo.getWorkers(businessId);
      // Normalize to Map<String,dynamic>
      _workers = list.cast<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();

      // Ensure current user is present in the list
      final authId = auth.currentUser?.id;
      if (authId != null && !_workers.any((w) => (w['id'] ?? '') == authId)) {
        _workers.insert(0, {'id': authId, 'fullName': auth.currentUser?.fullName ?? auth.currentUser?.email ?? 'You'});
      }

      // If no selected worker, pick the current user or first worker
      if (_selectedWorkerId == null && _workers.isNotEmpty) {
        _selectedWorkerId = _workers.first['id'] as String?;
        _selectedWorkerName = (_workers.first['fullName'] ?? _workers.first['name'] ?? '') as String?;
      }
    } catch (e) {
      print('[CheckoutSheet] Failed to load workers: $e');
    } finally {
      if (mounted) setState(() => _loadingWorkers = false);
    }
  }

  /// Show a searchable selection dialog for workers
  Future<void> _showWorkerSelectionDialog(BuildContext ctx) async {
    try {
      String filter = '';
      await showDialog<void>(
        context: ctx,
        builder: (dctx) => StatefulBuilder(builder: (dctx, setStateSB) {
          final filtered = _workers.where((w) {
            if (filter.trim().isEmpty) return true;
            final name = (w['fullName'] ?? w['name'] ?? w['email'] ?? '').toString().toLowerCase();
            return name.contains(filter.toLowerCase());
          }).toList();

          return AlertDialog(
            title: const Text('Select worker'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name or email'),
                    onChanged: (v) => setStateSB(() => filter = v),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(8.0), child: Text('No workers match your search')) else Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (context, idx) {
                        final w = filtered[idx];
                        final wid = (w['id'] ?? '') as String;
                        final wname = (w['fullName'] ?? w['name'] ?? w['email'] ?? 'Worker') as String;
                        final initials = (wname.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join()).toUpperCase();
                        return ListTile(
                          leading: ProfileAvatar(
                            photoUrl: (w['photoUrl'] ?? '') as String?,
                            initials: initials.isNotEmpty ? initials : '?',
                            radius: 18,
                          ),
                          title: Text(wname, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text((w['email'] ?? '') as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            setState(() {
                              _selectedWorkerId = wid;
                              _selectedWorkerName = wname;
                            });
                            Navigator.of(dctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Close')),
            ],
          );
        }),
      );
    } catch (e) {
      print('[CheckoutSheet] Error showing worker selection dialog: $e');
    }
  }

  Future<void> _generatePdfInvoice() async {
    try {
      final provider = Provider.of<RetailProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;

      // Calculate totals
      double subtotal = 0.0;
      final cartItems = provider.cartItems.entries.map((e) {
        final product = e.key;
        final qty = e.value;
        final price = product.price;
        subtotal += price * qty;
        return {
          'name': product.name,
          'menuItemName': product.name,
          'quantity': qty,
          'price': price,
          'unitPrice': price,
          'subtotal': price * qty,
          'total': price * qty,
          'specialInstructions': null,
          'selectedOptions': [],
        };
      }).toList();

      final taxAmt = subtotal * (_taxPercent / 100.0);
      final discountAmt = _discountAmount.clamp(0.0, subtotal);
      final total = subtotal + taxAmt - discountAmt;

      // Debug logging
      print('Checkout Sheet - Subtotal: $subtotal, Tax: $taxAmt, Discount: $discountAmt, Total: $total');

      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdfBytes(
        businessName: business?.name ?? 'Business',
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        cartItems: cartItems,
        subtotal: subtotal,
        tax: taxAmt,
        discount: discountAmt,
        total: total,
        customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        cashierName: auth.currentUser?.fullName,
        businessLogoUrl: business?.logoUrl,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
      );

      final filename = PdfInvoiceGenerator.getInvoiceFilename(invoiceNumber);

      if (kIsWeb) {
        web_download.downloadBytes(pdfBytes, filename, 'application/pdf');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice PDF downloaded: $filename')),
        );
      } else {
        await _sharePdfOnMobile(pdfBytes, filename);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF invoice: $e')),
      );
    }
  }

  Future<void> _sharePdfOnMobile(Uint8List pdfBytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice PDF',
        subject: 'Invoice',
      );
    } catch (e) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final file = File('${docsDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice saved to: ${file.path}')),
        );
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving PDF invoice')),
        );
      }
    }
  }

  Future<bool> _verifyWorkerPin(AuthProvider auth, {String? workerId}) async {
    try {
      // Determine which worker's PIN to validate: selected worker or the current user
      String? requiredPin;
      String workerName = 'Worker';

      // If workerId corresponds to the logged-in user, prefer their auth-stored PIN
      if (workerId != null && workerId == auth.currentUser?.id) {
        requiredPin = auth.currentUser?.pin?.toString();
        workerName = auth.currentUser?.fullName ?? workerName;
      } else if (workerId != null) {
        // Try to find the worker in the already-loaded list
        final idx = _workers.indexWhere((w) => (w['id'] ?? '') == workerId);
        if (idx != -1) {
          final w = _workers[idx];
          requiredPin = (w['pin'] ?? w['pinCode'] ?? '')?.toString();
          workerName = (w['fullName'] ?? w['name'] ?? w['email'] ?? workerName).toString();
        } else {
          // Fallback: fetch worker from repo
          try {
            final repo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
            final remote = await repo.getWorkerById(workerId);
            if (remote != null) {
              requiredPin = (remote['pin'] ?? remote['pinCode'] ?? '')?.toString();
              workerName = (remote['fullName'] ?? remote['name'] ?? remote['email'] ?? workerName).toString();
            }
          } catch (e) {
            print('[CheckoutSheet] Failed to fetch worker for PIN check: $e');
          }
        }
      } else {
        // No worker selected; default to current user's PIN if any
        requiredPin = auth.currentUser?.pin?.toString();
        workerName = auth.currentUser?.fullName ?? workerName;
      }

      // If no PIN is set for the selected worker, no verification is required
      if (requiredPin == null || requiredPin.trim().isEmpty) return true;

      int attempts = 0;
      while (attempts < 3) {
        final TextEditingController pinCtrl = TextEditingController();
        final entered = await showDialog<String?>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('Enter PIN for $workerName'),
            content: TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(pinCtrl.text), child: const Text('Confirm')),
            ],
          ),
        );

        if (entered == null) return false; // cancelled
        if (entered.trim() == requiredPin.trim()) return true;

        attempts += 1;
        // show brief error
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN, try again'), backgroundColor: Colors.red));
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN verification failed'), backgroundColor: Colors.red));
      return false;
    } catch (e) {
      print('[CheckoutSheet] PIN verification error: $e');
      return false;
    }
  }

  Future<CustomerModel?> _showCreateCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    bool isSaving = false;

    return showDialog<CustomerModel?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Customer name is required')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final customerProvider =
                          Provider.of<CustomerProvider>(context, listen: false);
                      final created = await customerProvider.createCustomer(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop(created);
                    },
              child: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerSelectionSheet() async {
    final businessId = Provider.of<BusinessProvider>(context, listen: false)
            .currentBusiness
            ?.id ??
        context.read<AuthProvider>().currentUser?.businessId ?? '';
    if (businessId.isEmpty) return;

    final customerProvider =
        Provider.of<CustomerProvider>(context, listen: false);
    customerProvider.setBusinessId(businessId);
    if (customerProvider.customers.isEmpty && !customerProvider.isLoading) {
      await customerProvider.loadCustomers();
    }

    if (!mounted) return;

    final selected = await showModalBottomSheet<CustomerModel?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final customers = customerProvider.customers.where((customer) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return customer.name.toLowerCase().contains(q) ||
                  (customer.phone?.toLowerCase().contains(q) ?? false) ||
                  (customer.email?.toLowerCase().contains(q) ?? false);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select customer',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search by name, phone, or email',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) =>
                          setSheetState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(null),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Walk-in customer'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            final created = await _showCreateCustomerDialog();
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop(created);
                          },
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Add new'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (customerProvider.isLoading)
                      const SizedBox(
                        height: 140,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (customers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No customers found'),
                        ),
                      )
                    else
                      SizedBox(
                        height: 280,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: customers.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  customer.name.isNotEmpty
                                      ? customer.name[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(customer.name),
                              subtitle: Text(
                                customer.phone?.isNotEmpty == true
                                    ? customer.phone!
                                    : (customer.email?.isNotEmpty == true
                                        ? customer.email!
                                        : 'No contact info'),
                              ),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(customer),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    final customerProviderAfter =
        Provider.of<CustomerProvider>(context, listen: false);
    customerProviderAfter.selectCustomer(selected);
    setState(() => _selectedCustomer = selected);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RetailProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final items = provider.cartItems;
    final canApplyDiscount = _canApplyDiscount(auth);
    final subtotal = _calculateSubtotal(provider);
    final safeDiscount = _discountAmount.clamp(0.0, subtotal);
    final effectiveDiscount = canApplyDiscount ? safeDiscount : 0.0;
    final taxAmt = subtotal * (_taxPercent / 100.0);
    final total = subtotal + taxAmt - effectiveDiscount;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Theme.of(context).cardColor,
            elevation: 2,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.tr(context, 'checkout'),
                    style: AppTextStyles.heading5.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty) ...[
              Center(
                  child: Text(AppLocalizations.tr(context, 'cart_empty'),
                      style: AppTextStyles.body2)),
              const SizedBox(height: 12),
            ] else ...[
              // Store selector
              Consumer<RetailProvider>(builder: (context, retail, _) {
                final stores = retail.stores;
                if (stores.isEmpty) return const SizedBox.shrink();
                final auth = Provider.of<AuthProvider>(context, listen: false);
                _selectedStoreId ??= auth.currentUser?.storeId ?? stores.first.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Store', style: AppTextStyles.subtitle1),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStoreId,
                          isExpanded: true,
                          items: stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                          onChanged: (val) => setState(() => _selectedStoreId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Worker switcher
                    if (_loadingWorkers)
                      const SizedBox(height: 40, child: Center(child: SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth:2))))
                    else if (_workers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Serving as', style: AppTextStyles.subtitle1),
                      const SizedBox(height: 8),
                      // If many workers, show a compact picker with search dialog, otherwise show chips
                      Builder(builder: (ctx) {
                        const int compactThreshold = 6;
                        if (_workers.length > compactThreshold) {
                          final selectedLabel = _selectedWorkerName ?? 'Select worker';
                          return Row(
                            children: [
                              ChoiceChip(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                label: Row(children: [
                                  ProfileAvatar(
                                    photoUrl: (_workers.firstWhere((w) => (w['id'] ?? '') == (_selectedWorkerId ?? ''), orElse: () => {})['photoUrl']) as String?,
                                    initials: (_selectedWorkerName != null && _selectedWorkerName!.isNotEmpty) ? _selectedWorkerName!.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join() : '?',
                                    radius: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 140),
                                    child: Tooltip(
                                      message: selectedLabel,
                                      child: Text(
                                        selectedLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ]),
                                selected: false,
                                onSelected: (_) async {
                                  await _showWorkerSelectionDialog(ctx);
                                },
                                selectedColor: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: 'Search worker',
                                onPressed: () async => await _showWorkerSelectionDialog(ctx),
                              ),
                            ],
                          );
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _workers.map((w) {
                              final wid = (w['id'] ?? '') as String;
                              final wname = (w['fullName'] ?? w['name'] ?? w['email'] ?? 'Worker') as String;
                              final selected = wid == _selectedWorkerId;
                              final initials = (wname.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join()).toUpperCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  label: Row(
                                    children: [
                                      ProfileAvatar(
                                        photoUrl: (w['photoUrl'] ?? '') as String?,
                                        initials: initials.isNotEmpty ? initials : '?',
                                        radius: 12,
                                      ),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 110),
                                        child: Tooltip(
                                          message: wname,
                                          child: Text(
                                            wname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: selected ? Colors.white : Colors.black87),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  selected: selected,
                                  onSelected: (_) => setState(() {
                                    _selectedWorkerId = wid;
                                    _selectedWorkerName = wname;
                                  }),
                                  selectedColor: AppColors.primary,
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ] else const SizedBox.shrink(),
                  ],
                );
              }),
              const Text('Customer', style: AppTextStyles.subtitle1),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCustomer?.name ?? 'Walk-in Customer',
                                style: AppTextStyles.body2.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_selectedCustomer != null)
                                Text(
                                  _selectedCustomer!.phone?.isNotEmpty == true
                                      ? _selectedCustomer!.phone!
                                      : (_selectedCustomer!.email?.isNotEmpty ==
                                              true
                                          ? _selectedCustomer!.email!
                                          : 'Customer selected for this sale'),
                                  style: AppTextStyles.caption,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showCustomerSelectionSheet,
                          icon: const Icon(Icons.manage_accounts_outlined),
                          label: Text(
                            _selectedCustomer == null
                                ? 'Select Customer'
                                : 'Change Customer',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final created = await _showCreateCustomerDialog();
                            if (!mounted || created == null) return;
                            Provider.of<CustomerProvider>(context, listen: false)
                                .selectCustomer(created);
                            setState(() => _selectedCustomer = created);
                          },
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Add New'),
                        ),
                        if (_selectedCustomer != null)
                          TextButton(
                            onPressed: () {
                              Provider.of<CustomerProvider>(context,
                                      listen: false)
                                  .clearSelectedCustomer();
                              setState(() => _selectedCustomer = null);
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              ...items.entries.map((e) {
                final product = e.key;
                final qty = e.value;
                final retail = Provider.of<RetailProvider>(context, listen: false);
                final effectivePrice = retail.getEffectivePriceForCartItem(product.id);
                final pricingMode = retail.getPricingModeForCartItem(product.id);
                final isWholesale = pricingMode == 'wholesale';
                final canToggleWholesale = product.hasWholesalePricing;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(product.name, style: AppTextStyles.body2)),
                          Text('x$qty', style: AppTextStyles.body2),
                          const SizedBox(width: 8),
                          Row(children: [
                            Text('${formatCurrency(effectivePrice)}', style: AppTextStyles.body2),
                            const SizedBox(width: 12),
                            Text('₦${(effectivePrice * qty).toStringAsFixed(2)}', style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700)),
                          ]),
                        ],
                      ),
                      if (canToggleWholesale)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SizedBox(
                            height: 28,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                retail.togglePricingModeForCartItem(product.id);
                                setState(() {});
                              },
                              icon: Icon(
                                isWholesale ? Icons.local_shipping : Icons.shopping_bag,
                                size: 14,
                              ),
                              label: Text(
                                isWholesale ? 'Wholesale' : 'Retail',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                side: BorderSide(
                                  color: isWholesale ? AppColors.primary : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              // Tax & Discount inputs
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tax (%)', border: OutlineInputBorder()),
                      onChanged: (v) => setState(() => _taxPercent = double.tryParse(v) ?? 0.0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: canApplyDiscount
                        ? TextField(
                            controller: _discountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Discount (NGN)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final parsed = double.tryParse(v) ?? 0.0;
                              final clamped = parsed.clamp(0.0, subtotal);
                              setState(() {
                                _discountAmount = clamped;
                                if (clamped != parsed) {
                                  _discountCtrl.text =
                                      clamped.toStringAsFixed(2);
                                  _discountCtrl.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _discountCtrl.text.length,
                                    ),
                                  );
                                }
                              });
                            },
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              auth.isOwnerUser
                                  ? 'Discount unavailable'
                                  : 'Discounts are limited to managers',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Payment method selection
              const Text('Payment Method', style: AppTextStyles.subtitle1),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _paymentMethods.map((method) {
                    final isSelected = _selectedPaymentMethod == method;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(method),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedPaymentMethod = method),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.tr(context, 'total'), style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Subtotal: ${formatCurrency(subtotal)}', style: AppTextStyles.caption),
                      Text('Tax: ${formatCurrency(taxAmt)}', style: AppTextStyles.caption),
                      if (effectiveDiscount > 0)
                        Text(
                          'Discount: -${formatCurrency(effectiveDiscount)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(formatCurrency(total), style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: provider.cartItems.isNotEmpty ? () => _generatePdfInvoice() : null,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Generate PDF Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Tooltip(
                  message: AppLocalizations.tr(context, 'confirm_pay'),
                  child: Semantics(
                    button: true,
                    label: AppLocalizations.tr(context, 'confirm_pay'),
                    child: ElevatedButton(
                      onPressed: () async {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final customerProvider =
                            Provider.of<CustomerProvider>(context, listen: false);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);

                        // Require PIN confirmation for the selected worker if set
                        final proceed = await _verifyWorkerPin(auth, workerId: _selectedWorkerId);
                        if (!proceed) return; // PIN verification failed or cancelled

                        // Capture sale details before checkout clears the cart
                        double subtotal = 0.0;
                        final customerName =
                            _selectedCustomer?.name ?? 'Walk-in Customer';
                        final customerEmail = _selectedCustomer?.email;
                        final customerId = _selectedCustomer?.id;
                        final storeIdForReceipt =
                            _selectedStoreId ?? auth.currentUser?.storeId;
                        String? storeNameForReceipt;
                        if (storeIdForReceipt != null &&
                            storeIdForReceipt.isNotEmpty) {
                          for (final store in provider.stores) {
                            if (store.id == storeIdForReceipt) {
                              storeNameForReceipt = store.name;
                              break;
                            }
                          }
                        }
                        final saleItems = provider.cartItems.entries.map((e) {
                          final product = e.key;
                          final qty = e.value;
                          final price = product.price;
                          subtotal += price * qty;
                          return {
                            'productId': product.id,
                            'name': product.name,
                            'quantity': qty,
                            'price': price,
                            'unit': product.resolvedSaleUnit,
                            'saleUnit': product.resolvedSaleUnit,
                            'inventoryUnit': product.unit,
                          };
                        }).toList();
                        final taxAmt = subtotal * (_taxPercent / 100.0);
                        final discountAmt = canApplyDiscount
                            ? _discountAmount.clamp(0.0, subtotal)
                            : 0.0;
                        final total = subtotal + taxAmt - discountAmt;

                        final saleMap = {
                          'id': 'SALE-${DateTime.now().millisecondsSinceEpoch}',
                          'items': saleItems,
                          'subtotal': subtotal,
                          'tax': taxAmt,
                          'taxRate': _taxPercent,
                          'discount': discountAmt,
                          'total': total,
                          'totalAmount': total,
                          'finalAmount': total,
                          'paymentMethod': _selectedPaymentMethod,
                          'paymentBreakdown': [
                            {'method': _selectedPaymentMethod, 'amount': total}
                          ],
                          'customerId': customerId,
                          'customerName': customerName,
                          'customerEmail': customerEmail,
                          if (discountAmt > 0)
                            'discountApprovedById': auth.currentUser?.id,
                          if (discountAmt > 0)
                            'discountApprovedByName': auth.currentUser?.fullName,
                          if (storeIdForReceipt != null &&
                              storeIdForReceipt.isNotEmpty)
                            'storeId': storeIdForReceipt,
                          if (storeNameForReceipt != null &&
                              storeNameForReceipt.isNotEmpty)
                            'storeName': storeNameForReceipt,
                        };

                        final savedOffline = await provider.checkout(
                          paymentMethod: _selectedPaymentMethod,
                          workerId: _selectedWorkerId ?? auth.currentUser?.id,
                          workerName: _selectedWorkerName ?? auth.currentUser?.fullName,
                          customerId: customerId,
                          customerEmail: customerEmail,
                          customerName: customerName,
                          storeId: storeIdForReceipt,
                          tax: _taxPercent,
                          discount: discountAmt,
                        );
                        Navigator.of(context).pop();

                        if (savedOffline) {
                          scaffoldMessenger.showSnackBar(SnackBar(
                              content: Text('Sale recorded offline and will sync when online'),
                              backgroundColor: AppColors.warning));
                        } else {
                          scaffoldMessenger.showSnackBar(SnackBar(
                              content: Text(AppLocalizations.tr(context, 'checkout_success')),
                              backgroundColor: AppColors.success));
                        }

                        // Send push notification to business owners
                        try {
                          final currentBusinessId =
                              Provider.of<BusinessProvider>(context,
                                          listen: false)
                                      .currentBusiness
                                      ?.id ??
                                  auth.currentUser?.primaryBusinessId ??
                                  auth.currentUser?.businessId ??
                                  '';
                          await BusinessNotificationManager.instance.notifySaleCompleted(
                            businessId: currentBusinessId,
                            customerName: customerName,
                            amount: total,
                            paymentMethod: _selectedPaymentMethod,
                          );

                          if (total > 100) {
                            await BusinessNotificationManager.instance.notifyLargeSale(
                              businessId: currentBusinessId,
                              customerName: customerName,
                              amount: total,
                            );
                          }
                        } catch (e) {
                          debugPrint('[CheckoutSheet] Push notification failed: $e');
                        }

                        if (!savedOffline && customerId != null) {
                          try {
                            await customerProvider.updateCustomerAfterPurchase(
                              customerId,
                              total,
                            );
                          } catch (e) {
                            debugPrint(
                                '[CheckoutSheet] Failed to update customer summary: $e');
                          }
                        }

                        // Perform post-sale receipt actions
                        try {
                          await ReceiptManager.handlePostSale(context, saleMap);
                        } catch (_) {}
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(AppLocalizations.tr(context, 'confirm_pay')),
                    ),
                  ),
                ),
              ),
                    ],
                  ]
                ),
              ),
            ),
          ),
        ),
      ));
  }
}
