import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Web-safe invoice PDF generator.
class PdfInvoiceGenerator {
  static const String _currencySymbol = '₦';

  static Future<Uint8List> generateInvoicePdfBytes({
    required String businessName,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String customerName,
    String? customerEmail,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? cashierName,
    String? notes,
    String paperWidth = '80',
  }) async {
    final pdf = pw.Document();
    final pageWidth = paperWidth == '58' ? 220.0 : 303.0;
    const pageHeight = 1063.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('INVOICE',
                style: pw.TextStyle(
                    fontSize: paperWidth == '58' ? 14 : 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue)),
            pw.SizedBox(height: 4),
            pw.Text(businessName,
                style: pw.TextStyle(
                    fontSize: paperWidth == '58' ? 12 : 16,
                    fontWeight: pw.FontWeight.bold)),
            if (businessAddress != null && businessAddress.isNotEmpty)
              pw.Text(businessAddress),
            if (businessPhone != null && businessPhone.isNotEmpty)
              pw.Text('Phone: $businessPhone'),
            if (businessEmail != null && businessEmail.isNotEmpty)
              pw.Text('Email: $businessEmail'),
            pw.SizedBox(height: 12),
            pw.Text('Invoice #: $invoiceNumber'),
            pw.Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format(invoiceDate)}'),
            if (cashierName != null && cashierName.isNotEmpty)
              pw.Text('Cashier: $cashierName'),
            pw.SizedBox(height: 8),
            pw.Text('Customer: ${customerName.isNotEmpty ? customerName : 'Walk-in Customer'}'),
            if (customerEmail != null && customerEmail.isNotEmpty)
              pw.Text(customerEmail),
            pw.SizedBox(height: 12),
            ...cartItems.map((item) {
              final name = item['menuItemName'] ??
                  item['name'] ??
                  item['productName'] ??
                  'Unknown Item';
              final quantity = _toDouble(item['quantity'] ?? 1);
              final unitPrice =
                  _toDouble(item['price'] ?? item['unitPrice'] ?? 0.0);
              final itemTotal = _toDouble(
                item['subtotal'] ?? item['total'] ?? (unitPrice * quantity),
              );
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(name.toString())),
                    pw.SizedBox(width: 12),
                    pw.Text('${_displayQty(quantity)} x ${_money(unitPrice)}'),
                    pw.SizedBox(width: 12),
                    pw.Text(_money(itemTotal)),
                  ],
                ),
              );
            }),
            pw.Divider(),
            pw.Text('Subtotal: ${_money(subtotal)}'),
            if (discount > 0) pw.Text('Discount: -${_money(discount)}'),
            pw.Text('Tax: ${_money(tax)}'),
            pw.Text('TOTAL: ${_money(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(notes),
            ],
          ],
        ),
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static String getInvoiceFilename(String invoiceNumber) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'invoice_${invoiceNumber}_$timestamp.pdf';
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static String _displayQty(double quantity) {
    return quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString();
  }

  static String _money(double value) =>
      '$_currencySymbol${value.toStringAsFixed(2)}';
}
