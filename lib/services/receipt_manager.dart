import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import 'thermal_printing_service.dart';
import '../providers/receipt_settings_provider.dart';
import '../providers/business_provider.dart';
import '../providers/auth_provider.dart';
import '../presentation/sales/widgets/post_sale_action_sheet.dart';

class ReceiptManager {
  static String? _resolveCustomerName(Map<String, dynamic> sale) {
    final raw = (sale['customerName'] ??
            sale['customerDisplayName'] ??
            (sale['customer'] is Map ? sale['customer']['name'] : null))
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.toLowerCase() == 'walk-in customer') {
      return null;
    }
    return raw;
  }

  /// Handle post-sale actions: show action sheet with Share/Email/Print options
  static Future<void> handlePostSale(
      BuildContext context, Map<String, dynamic> sale) async {
    try {
      debugPrint('[ReceiptManager] Starting handlePostSale...');

      if (!context.mounted) {
        debugPrint('[ReceiptManager] Context not mounted, aborting');
        return;
      }

      final businessProvider =
          Provider.of<BusinessProvider>(context, listen: false);
      final receiptProvider =
          Provider.of<ReceiptSettingsProvider>(context, listen: false);
      // TODO: Send email
      final auth = Provider.of<AuthProvider>(context, listen: false);

      debugPrint('[ReceiptManager] Providers obtained successfully');

      final business = businessProvider.currentBusiness;
      final settings = receiptProvider.receiptSettings;
      final rawStoreName = (sale['storeName'] ??
              sale['store_name'] ??
              (sale['store'] is Map ? sale['store']['name'] : null))
          ?.toString()
          .trim();
      final storeName =
          (rawStoreName != null && rawStoreName.isNotEmpty) ? rawStoreName : null;
      final customerName = _resolveCustomerName(sale);
      final rawTableLabel = (sale['tableLabel'] ??
              sale['tableNo'] ??
              sale['tableNumber'] ??
              sale['table'] ??
              '')
          .toString()
          .trim();
      final tableLabel =
          rawTableLabel.isNotEmpty ? rawTableLabel : null;

      // Build items in expected structure for ThermalPrintingService
      final items = <Map<String, dynamic>>[];
      final rawItems = sale['items'] as List? ?? [];
      for (final it in rawItems) {
        // it may be Map with product object keys or simple maps
        if (it is Map<String, dynamic>) {
          // Determine item name (support nested product map)
          String name = 'Item';
          if (it.containsKey('name') &&
              it['name']?.toString().trim().isNotEmpty == true) {
            name = it['name'].toString();
          } else if (it.containsKey('productName') &&
              it['productName']?.toString().trim().isNotEmpty == true) {
            name = it['productName'].toString();
          } else if (it.containsKey('menuItemName') &&
              it['menuItemName']?.toString().trim().isNotEmpty == true) {
            name = it['menuItemName'].toString();
          } else if (it.containsKey('product_name') &&
              it['product_name']?.toString().trim().isNotEmpty == true) {
            name = it['product_name'].toString();
          } else if (it['product'] is Map && it['product']['name'] != null) {
            name = it['product']['name'].toString();
          } else if (it.containsKey('itemId')) {
            name = it['itemId'].toString();
          }

          final quantityRaw = it['quantity'] ?? it['qty'] ?? 1;
          final quantity = ThermalPrintingService.parseNum(quantityRaw);

          final priceRaw =
              it['price'] ?? it['unitPrice'] ?? it['unit_price'] ?? 0;
          var price = ThermalPrintingService.parseDouble(priceRaw);

          // If price missing but a total is present, derive unit price
          if (price == 0 && it['total'] != null) {
            final total = ThermalPrintingService.parseDouble(it['total']);
            if (total > 0 && quantity > 0) {
              price = total / quantity;
            }
          }

          // Capture unit when available so receipts can format quantities correctly (e.g., L -> 3 decimals)
          final unitRaw = (it['unit'] ??
                  it['unitName'] ??
                  it['uom'] ??
                  it['saleUnit'] ??
                  it['inventoryUnit'] ??
                  it['resolvedSaleUnit'] ??
                  it['selectedUnit'] ??
                  ((it['product'] is Map)
                      ? (it['product']['saleUnit'] ??
                          it['product']['unit'] ??
                          it['product']['unitName'] ??
                          it['product']['uom'])
                      : null) ??
                  '')
              .toString();

          items.add({
            'name': name,
            'quantity': quantity,
            'price': price,
            'unit': unitRaw.isNotEmpty ? unitRaw : null,
            'pricingMode': it['pricingMode']?.toString(),
          });
        }
      }

      final paperWidth = settings?.paperWidth ??
          (business?.settings is Map
              ? (business!.settings!['receipt'] is Map
                  ? (business.settings!['receipt']['paperWidth'] as int?)
                  : null)
              : null) ??
          58;
      final receiptText = ThermalPrintingService.createCompleteReceipt(
        businessName: business?.name ?? 'Business',
        paperWidth: paperWidth,
        items: items,
        totalAmount: (sale['total'] ?? sale['amount'] ?? 0.0).toDouble(),
        paymentMethod: sale['paymentMethod'] ?? 'Cash',
        orderId: sale['id']?.toString(),
        cashier: sale['workerName'] ??
            auth.currentUser?.fullName ??
            auth.currentUser?.email ??
            'POS',
        customerName: customerName,
        storeName: storeName,
        tableLabel: tableLabel,
      );

      // Do not generate PDFs automatically for pump/fuel sales. Defer generation
      // to user-initiated action in the PostSaleActionSheet so the app shows a
      // confirmation/print action immediately without doing extra work.
      Future<dynamic>? pdfFuture =
          null; // generation will be triggered on demand by UI
      // (Intentionally left pdfFuture null for all categories by default. If we
      // need different behaviour per category, adjust here.)

      // Show user-facing action sheet with Share/Email/Print options
      if (!context.mounted) {
        debugPrint('[ReceiptManager] Context not mounted before showing modal');
        return;
      }

      debugPrint(
          '[ReceiptManager] About to show modal bottom sheet (root navigator)');

      // Use the root navigator so the sheet remains visible even if callers
      // navigate to a new route (e.g., SalesReceipt screen).
      await showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isDismissible: true,
        enableDrag: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => PostSaleActionSheet(
          receiptText: receiptText,
          businessName: business?.name ?? 'Business',
          orderId: sale['id']?.toString(),
          customerEmail: sale['customerEmail'] ??
              (sale['customer'] is Map ? sale['customer']['email'] : null),
          saleData: sale,
          pdfFuture: pdfFuture,
          allowEditing: false, // Disable price editing on print action sheet
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Transaction complete. Post-sale options are available.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }

      debugPrint('[ReceiptManager] Modal bottom sheet dismissed');
    } catch (e) {
      debugPrint('[ReceiptManager] Error: $e');
      debugPrintStack(label: 'ReceiptManager Stack Trace');
    }
  }
}
