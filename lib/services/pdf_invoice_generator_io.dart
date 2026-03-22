import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Service for generating PDF invoices from cart items before sale completion.
class PdfInvoiceGenerator {
  static const String _currencySymbol = '₦';

  /// Generate a PDF invoice from cart items and return bytes.
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
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: paperWidth == '58' ? 14 : 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      businessName,
                      style: pw.TextStyle(
                        fontSize: paperWidth == '58' ? 12 : 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (businessAddress != null && businessAddress.isNotEmpty)
                      pw.Text(
                        businessAddress,
                        style: pw.TextStyle(
                            fontSize: paperWidth == '58' ? 8 : 10),
                      ),
                    if (businessPhone != null && businessPhone.isNotEmpty)
                      pw.Text(
                        'Phone: $businessPhone',
                        style: pw.TextStyle(
                            fontSize: paperWidth == '58' ? 8 : 10),
                      ),
                    if (businessEmail != null && businessEmail.isNotEmpty)
                      pw.Text(
                        'Email: $businessEmail',
                        style: pw.TextStyle(
                            fontSize: paperWidth == '58' ? 8 : 10),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice #: $invoiceNumber',
                        style: pw.TextStyle(
                          fontSize: paperWidth == '58' ? 9 : 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(invoiceDate)}',
                        style: pw.TextStyle(
                            fontSize: paperWidth == '58' ? 8 : 10),
                      ),
                      if (cashierName != null && cashierName.isNotEmpty)
                        pw.Text(
                          'Cashier: $cashierName',
                          style: pw.TextStyle(
                              fontSize: paperWidth == '58' ? 8 : 10),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Customer:',
                        style: pw.TextStyle(
                          fontSize: paperWidth == '58' ? 9 : 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        customerName.isNotEmpty
                            ? customerName
                            : 'Walk-in Customer',
                        style: pw.TextStyle(
                            fontSize: paperWidth == '58' ? 8 : 10),
                      ),
                      if (customerEmail != null && customerEmail.isNotEmpty)
                        pw.Text(
                          customerEmail,
                          style: pw.TextStyle(
                              fontSize: paperWidth == '58' ? 8 : 10),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.grey300),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: paperWidth == '58' ? 3 : 4,
                            child: _headerCell('Item', paperWidth),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: _headerCell(
                              'Qty',
                              paperWidth,
                              align: pw.TextAlign.center,
                            ),
                          ),
                          pw.Expanded(
                            flex: paperWidth == '58' ? 2 : 3,
                            child: _headerCell(
                              'Price',
                              paperWidth,
                              align: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: paperWidth == '58' ? 2 : 3,
                            child: _headerCell(
                              'Total',
                              paperWidth,
                              align: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
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

                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.grey200),
                          ),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: paperWidth == '58' ? 3 : 4,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    name.toString(),
                                    style: pw.TextStyle(
                                        fontSize: paperWidth == '58' ? 8 : 10),
                                  ),
                                  if (item['specialInstructions'] != null &&
                                      item['specialInstructions']
                                          .toString()
                                          .isNotEmpty)
                                    pw.Text(
                                      'Note: ${item['specialInstructions']}',
                                      style: pw.TextStyle(
                                        fontSize: paperWidth == '58' ? 6 : 8,
                                        fontStyle: pw.FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                _displayQty(quantity),
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                    fontSize: paperWidth == '58' ? 8 : 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: paperWidth == '58' ? 2 : 3,
                              child: pw.Text(
                                _money(unitPrice),
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    fontSize: paperWidth == '58' ? 8 : 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: paperWidth == '58' ? 2 : 3,
                              child: pw.Text(
                                _money(itemTotal),
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    fontSize: paperWidth == '58' ? 8 : 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Column(
                  children: [
                    _totalRow('Subtotal:', subtotal, paperWidth),
                    if (discount > 0)
                      _totalRow('Discount:', -discount, paperWidth,
                          negative: true),
                    _totalRow('Tax:', tax, paperWidth),
                    pw.Divider(),
                    _totalRow('TOTAL:', total, paperWidth, bold: true),
                  ],
                ),
              ),
              if (notes != null && notes.isNotEmpty)
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 15),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Notes:',
                        style: pw.TextStyle(
                          fontSize: paperWidth == '58' ? 9 : 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        notes,
                        style: pw.TextStyle(
                            fontSize: paperWidth == '58' ? 8 : 10),
                      ),
                    ],
                  ),
                ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: paperWidth == '58' ? 9 : 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Generated on ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: paperWidth == '58' ? 7 : 9,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String getInvoiceFilename(String invoiceNumber) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'invoice_${invoiceNumber}_$timestamp.pdf';
  }

  /// Generate a PDF invoice and save it to device on IO platforms.
  static Future<File> generateInvoicePdf({
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
    final bytes = await generateInvoicePdfBytes(
      businessName: businessName,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      cartItems: cartItems,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      customerName: customerName,
      customerEmail: customerEmail,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
      cashierName: cashierName,
      notes: notes,
      paperWidth: paperWidth,
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/${getInvoiceFilename(invoiceNumber)}');
    await file.writeAsBytes(bytes);
    return file;
  }

  static pw.Widget _headerCell(String text, String paperWidth,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: paperWidth == '58' ? 8 : 10,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double amount,
    String paperWidth, {
    bool bold = false,
    bool negative = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: paperWidth == '58' ? (bold ? 11 : 9) : (bold ? 13 : 11),
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          negative ? '-${_money(amount.abs())}' : _money(amount),
          style: pw.TextStyle(
            fontSize: paperWidth == '58' ? (bold ? 11 : 9) : (bold ? 13 : 11),
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: negative ? PdfColors.red : (bold ? PdfColors.green : null),
          ),
        ),
      ],
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static String _displayQty(double quantity) {
    return quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString();
  }

  static String _money(double value) => '$_currencySymbol${value.toStringAsFixed(2)}';
}
