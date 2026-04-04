import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_utils.dart';

/// Web-safe invoice PDF generator using the same narrow-paper branding as the
/// IO implementation.
class PdfInvoiceGenerator {
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
    String? businessLogoUrl,
    String? subscriptionTier,
    String? businessClass,
    String? poweredByText,
  }) async {
    final pdf = pw.Document();
    final branding = await loadPdfBranding(
      businessLogoUrl: businessLogoUrl,
      subscriptionTier: subscriptionTier,
      businessClass: businessClass,
    );

    final symbol = branding.currencySymbol;
    final primaryLogo =
        branding.showBusinessLogo ? branding.businessLogoBytes : branding.manageCareLogoBytes;
    final headerDetails = [
      if ((businessAddress ?? '').trim().isNotEmpty) businessAddress!.trim(),
      if ((businessPhone ?? '').trim().isNotEmpty) 'Tel: ${businessPhone!.trim()}',
      if ((businessEmail ?? '').trim().isNotEmpty) businessEmail!.trim(),
    ].join(' • ');

    final pageWidth = _pageWidthForPaper(paperWidth);
    final pageHeight = _estimatePageHeight(
      paperWidth: paperWidth,
      itemCount: cartItems.length,
      hasDiscount: discount > 0,
      hasNotes: (notes ?? '').trim().isNotEmpty,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          pageWidth,
          pageHeight,
          marginAll: paperWidth == '58' ? 6 : 8,
        ),
        theme: pw.ThemeData.withFont(base: branding.font),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPdfHeader(
                font: branding.font,
                businessName: businessName,
                businessDetails: headerDetails.isEmpty ? null : headerDetails,
                logoBytes: primaryLogo,
                stylePreset: 'minimal',
              ),
              _buildLabel(branding.font),
              pw.SizedBox(height: 8),
              _buildMetaCard(
                font: branding.font,
                paperWidth: paperWidth,
                invoiceNumber: invoiceNumber,
                invoiceDate: invoiceDate,
                cashierName: cashierName,
                customerName: customerName.trim().isEmpty
                    ? 'Walk-in Customer'
                    : customerName.trim(),
                customerEmail: customerEmail,
              ),
              pw.SizedBox(height: 8),
              _buildItemsSection(
                font: branding.font,
                paperWidth: paperWidth,
                cartItems: cartItems,
                symbol: symbol,
              ),
              pw.SizedBox(height: 8),
              _buildTotalsCard(
                font: branding.font,
                paperWidth: paperWidth,
                symbol: symbol,
                subtotal: subtotal,
                tax: tax,
                discount: discount,
                total: total,
              ),
              if ((notes ?? '').trim().isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Notes',
                        style: pw.TextStyle(
                          font: branding.font,
                          fontSize: paperWidth == '58' ? 7.8 : 8.8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF0F4C81),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        notes!.trim(),
                        style: pw.TextStyle(
                          font: branding.font,
                          fontSize: paperWidth == '58' ? 7.4 : 8.4,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: invoiceNumber,
                  width: pageWidth - (paperWidth == '58' ? 34 : 44),
                  height: paperWidth == '58' ? 28 : 32,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Please keep this invoice for your records',
                  style: pw.TextStyle(
                    font: branding.font,
                    fontSize: paperWidth == '58' ? 7.5 : 8.5,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
              buildDocumentFooter(
                font: branding.font,
                manageCareLogoBytes: branding.manageCareLogoBytes,
                poweredByText: poweredByText ?? 'Powered by Manage Care',
                compact: true,
              ),
            ],
          );
        },
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static String getInvoiceFilename(String invoiceNumber) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'invoice_${invoiceNumber}_$timestamp.pdf';
  }

  static double _pageWidthForPaper(String paperWidth) {
    return paperWidth == '58'
        ? 58 * PdfPageFormat.mm
        : 80 * PdfPageFormat.mm;
  }

  static double _estimatePageHeight({
    required String paperWidth,
    required int itemCount,
    required bool hasDiscount,
    required bool hasNotes,
  }) {
    final base = paperWidth == '58' ? 250.0 : 280.0;
    final itemHeight = paperWidth == '58' ? 28.0 : 24.0;
    var height = base + (itemCount * itemHeight);
    if (hasDiscount) height += 12;
    if (hasNotes) height += 48;
    return height.clamp(300.0, 1200.0);
  }

  static pw.Widget _buildLabel(pw.Font font) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFFDF1E7),
          borderRadius: pw.BorderRadius.circular(20),
        ),
        child: pw.Text(
          'INVOICE',
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFFB35A00),
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildMetaCard({
    required pw.Font font,
    required String paperWidth,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String? cashierName,
    required String customerName,
    required String? customerEmail,
  }) {
    final fontSize = paperWidth == '58' ? 7.5 : 8.5;
    final labelStyle = pw.TextStyle(
      font: font,
      fontSize: fontSize,
      color: PdfColors.grey700,
    );
    final valueStyle = pw.TextStyle(
      font: font,
      fontSize: fontSize,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _metaRow(labelStyle, valueStyle, 'Invoice No', invoiceNumber),
          _metaRow(
            labelStyle,
            valueStyle,
            'Date',
            DateFormat('dd MMM yyyy, HH:mm').format(invoiceDate),
          ),
          if ((cashierName ?? '').trim().isNotEmpty)
            _metaRow(labelStyle, valueStyle, 'Cashier', cashierName!.trim()),
          _metaRow(labelStyle, valueStyle, 'Customer', customerName),
          if ((customerEmail ?? '').trim().isNotEmpty)
            _metaRow(labelStyle, valueStyle, 'Email', customerEmail!.trim()),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsSection({
    required pw.Font font,
    required String paperWidth,
    required List<Map<String, dynamic>> cartItems,
    required String symbol,
  }) {
    final titleSize = paperWidth == '58' ? 8 : 9;
    final bodySize = paperWidth == '58' ? 7.4 : 8.4;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Invoice Items',
          style: pw.TextStyle(
            font: font,
            fontSize: titleSize.toDouble(),
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFFB35A00),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFFFFAF5),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            children: cartItems.map((item) {
              final name = _resolveItemName(item);
              final qty = _toDouble(item['quantity'] ?? 1);
              final unitPrice = _toDouble(
                item['price'] ?? item['unitPrice'] ?? item['unit_price'] ?? 0,
              );
              final lineTotal = _toDouble(
                item['total'] ?? item['subtotal'] ?? (qty * unitPrice),
              );
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.3),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            name,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: bodySize,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          _money(lineTotal, symbol),
                          style: pw.TextStyle(
                            font: font,
                            fontSize: bodySize,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${_displayQty(qty)} x ${_money(unitPrice, symbol)}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: bodySize - 0.2,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalsCard({
    required pw.Font font,
    required String paperWidth,
    required String symbol,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
  }) {
    final fontSize = paperWidth == '58' ? 7.8 : 8.8;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFDF1E7),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: [
          _totalRow(font, fontSize, 'Subtotal', _money(subtotal, symbol)),
          if (discount > 0)
            _totalRow(font, fontSize, 'Discount', '-${_money(discount, symbol)}'),
          if (tax > 0) _totalRow(font, fontSize, 'Tax', _money(tax, symbol)),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey500),
          _totalRow(
            font,
            fontSize + 0.6,
            'Total',
            _money(total, symbol),
            bold: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaRow(
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
    String label,
    String value,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 42, child: pw.Text(label, style: labelStyle)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Text(value, style: valueStyle)),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(
    pw.Font font,
    double fontSize,
    String label,
    String value, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: bold ? PdfColors.black : PdfColors.grey800,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: bold ? PdfColor.fromInt(0xFFB35A00) : PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  static String _resolveItemName(Map<String, dynamic> item) {
    for (final key in const [
      'name',
      'productName',
      'menuItemName',
      'title',
    ]) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return 'Item';
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static String _displayQty(double quantity) {
    return quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2);
  }

  static String _money(double value, String symbol) {
    return '$symbol${value.toStringAsFixed(2)}';
  }
}
