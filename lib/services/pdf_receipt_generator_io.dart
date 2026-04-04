import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_utils.dart';

class PdfReceiptGenerator {
  static Future<File> generateReceiptPdf({
    required String businessName,
    required String receiptNumber,
    required DateTime receiptDate,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double total,
    required String paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    required String customerName,
    required String? customerEmail,
    required String? customHeader,
    required String? customFooter,
    required String paperWidth,
    String? cashier,
    String? poweredByText,
    bool showQrCode = false,
    String? receiptUrlBase,
    double discount = 0.0,
    String? businessLogoUrl,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? subscriptionTier,
    String? businessClass,
  }) async {
    final bytes = await generateReceiptPdfBytes(
      businessName: businessName,
      receiptNumber: receiptNumber,
      receiptDate: receiptDate,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      paymentBreakdown: paymentBreakdown,
      customerName: customerName,
      customerEmail: customerEmail,
      customHeader: customHeader,
      customFooter: customFooter,
      paperWidth: paperWidth,
      cashier: cashier,
      poweredByText: poweredByText,
      showQrCode: showQrCode,
      receiptUrlBase: receiptUrlBase,
      discount: discount,
      businessLogoUrl: businessLogoUrl,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
      subscriptionTier: subscriptionTier,
      businessClass: businessClass,
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/${getReceiptFilename(receiptNumber)}');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<Uint8List> generateReceiptPdfBytes({
    required String businessName,
    required String receiptNumber,
    required DateTime receiptDate,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double total,
    required String paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    required String customerName,
    required String? customerEmail,
    required String? customHeader,
    required String? customFooter,
    required String paperWidth,
    String? cashier,
    String? poweredByText,
    bool showQrCode = false,
    String? receiptUrlBase,
    double discount = 0.0,
    String? businessLogoUrl,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? subscriptionTier,
    String? businessClass,
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
    final safeCustomer =
        customerName.trim().isEmpty ? 'Walk-in Customer' : customerName.trim();
    final headerDetails = [
      if ((businessAddress ?? '').trim().isNotEmpty) businessAddress!.trim(),
      if ((businessPhone ?? '').trim().isNotEmpty) 'Tel: ${businessPhone!.trim()}',
      if ((businessEmail ?? '').trim().isNotEmpty) businessEmail!.trim(),
    ].join(' • ');

    final pageWidth = _pageWidthForPaper(paperWidth);
    final pageHeight = _estimatePageHeight(
      paperWidth: paperWidth,
      itemCount: items.length,
      paymentCount: paymentBreakdown?.length ?? 0,
      hasDiscount: discount > 0,
      hasQrCode: showQrCode && (receiptUrlBase ?? '').trim().isNotEmpty,
      hasCustomHeader: (customHeader ?? '').trim().isNotEmpty,
      hasCustomFooter: (customFooter ?? '').trim().isNotEmpty,
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
              _buildReceiptLabel(branding.font),
              if ((customHeader ?? '').trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    customHeader!.trim(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: branding.font,
                      fontSize: paperWidth == '58' ? 7.5 : 8.5,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              ],
              pw.SizedBox(height: 8),
              _buildMetaCard(
                font: branding.font,
                paperWidth: paperWidth,
                receiptNumber: receiptNumber,
                receiptDate: receiptDate,
                cashier: cashier,
                customerName: safeCustomer,
                customerEmail: customerEmail,
              ),
              pw.SizedBox(height: 8),
              _buildItemsSection(
                font: branding.font,
                paperWidth: paperWidth,
                items: items,
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
              pw.SizedBox(height: 8),
              _buildPaymentSection(
                font: branding.font,
                paperWidth: paperWidth,
                symbol: symbol,
                paymentMethod: paymentMethod,
                paymentBreakdown: paymentBreakdown,
              ),
              if (showQrCode &&
                  (receiptUrlBase ?? '').trim().isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data:
                        '${receiptUrlBase!.replaceAll(RegExp(r'/*$'), '')}/$receiptNumber',
                    width: paperWidth == '58' ? 58 : 72,
                    height: paperWidth == '58' ? 58 : 72,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Scan to view receipt',
                    style: pw.TextStyle(
                      font: branding.font,
                      fontSize: 7,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: receiptNumber,
                  width: pageWidth - (paperWidth == '58' ? 34 : 44),
                  height: paperWidth == '58' ? 28 : 32,
                ),
              ),
              if ((customFooter ?? '').trim().isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    customFooter!.trim(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: branding.font,
                      fontSize: 7.5,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              ],
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for your patronage',
                  style: pw.TextStyle(
                    font: branding.font,
                    fontSize: paperWidth == '58' ? 8 : 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF0F4C81),
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

  static String getReceiptFilename(String receiptNumber) {
    return 'receipt_$receiptNumber.pdf';
  }

  static String getPrintPaperSize(String paperWidth) {
    return paperWidth == '58' ? 'CUSTOM_58x300' : 'CUSTOM_80x300';
  }

  static Map<String, dynamic> getPrintSettings({
    required String paperWidth,
    bool fitToPage = true,
    bool autoRotate = true,
  }) {
    return {
      'paperWidth': paperWidth,
      'paperHeight': '300',
      'fitToPage': fitToPage,
      'autoRotate': autoRotate,
      'marginDetails': {
        'top': 0,
        'right': 8,
        'bottom': 0,
        'left': 8,
      },
    };
  }

  static pw.Widget _buildReceiptLabel(pw.Font font) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFEAF3FB),
          borderRadius: pw.BorderRadius.circular(20),
        ),
        child: pw.Text(
          'RECEIPT',
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF0F4C81),
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildMetaCard({
    required pw.Font font,
    required String paperWidth,
    required String receiptNumber,
    required DateTime receiptDate,
    required String? cashier,
    required String customerName,
    required String? customerEmail,
  }) {
    final fontSize = paperWidth == '58' ? 7.5 : 8.5;
    final valueStyle = pw.TextStyle(
      font: font,
      fontSize: fontSize,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );
    final labelStyle = pw.TextStyle(
      font: font,
      fontSize: fontSize,
      color: PdfColors.grey700,
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
          _metaRow(
            labelStyle: labelStyle,
            valueStyle: valueStyle,
            label: 'Receipt No',
            value: receiptNumber,
          ),
          _metaRow(
            labelStyle: labelStyle,
            valueStyle: valueStyle,
            label: 'Date',
            value: DateFormat('dd MMM yyyy, HH:mm').format(receiptDate),
          ),
          _metaRow(
            labelStyle: labelStyle,
            valueStyle: valueStyle,
            label: 'Cashier',
            value: (cashier ?? '').trim().isEmpty ? 'Staff' : cashier!.trim(),
          ),
          _metaRow(
            labelStyle: labelStyle,
            valueStyle: valueStyle,
            label: 'Customer',
            value: customerName,
          ),
          if ((customerEmail ?? '').trim().isNotEmpty)
            _metaRow(
              labelStyle: labelStyle,
              valueStyle: valueStyle.copyWith(fontSize: fontSize - 0.3),
              label: 'Email',
              value: customerEmail!.trim(),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsSection({
    required pw.Font font,
    required String paperWidth,
    required List<Map<String, dynamic>> items,
    required String symbol,
  }) {
    final titleSize = paperWidth == '58' ? 8 : 9;
    final bodySize = paperWidth == '58' ? 7.5 : 8.5;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Items',
          style: pw.TextStyle(
            font: font,
            fontSize: titleSize.toDouble(),
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF0F4C81),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF6F8FA),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            children: items.map((item) {
              final name = _resolveItemName(item);
              final qty = _toDouble(item['quantity'] ?? item['qty'] ?? 1);
              final unit = (item['unit'] ??
                      item['uom'] ??
                      item['saleUnit'] ??
                      item['inventoryUnit'] ??
                      '')
                  .toString();
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
                      '${_displayQty(qty, unit: unit)} x ${_money(unitPrice, symbol)}',
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
        color: PdfColor.fromInt(0xFFEAF3FB),
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

  static pw.Widget _buildPaymentSection({
    required pw.Font font,
    required String paperWidth,
    required String symbol,
    required String paymentMethod,
    required List<Map<String, dynamic>>? paymentBreakdown,
  }) {
    final fontSize = paperWidth == '58' ? 7.5 : 8.5;
    final rows = (paymentBreakdown ?? [])
        .where((entry) => entry.isNotEmpty)
        .map((entry) {
          final method = (entry['method'] ?? paymentMethod).toString();
          final amount = _toDouble(entry['amount'] ?? 0);
          final transactionId = (entry['transactionId'] ?? '').toString();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    transactionId.trim().isEmpty
                        ? method.toUpperCase()
                        : '${method.toUpperCase()} • $transactionId',
                    style: pw.TextStyle(font: font, fontSize: fontSize),
                  ),
                ),
                pw.Text(
                  _money(amount, symbol),
                  style: pw.TextStyle(font: font, fontSize: fontSize),
                ),
              ],
            ),
          );
        }).toList();

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
          pw.Text(
            'Payment',
            style: pw.TextStyle(
              font: font,
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF0F4C81),
            ),
          ),
          pw.SizedBox(height: 4),
          if (rows.isNotEmpty)
            ...rows
          else
            pw.Text(
              paymentMethod,
              style: pw.TextStyle(font: font, fontSize: fontSize),
            ),
        ],
      ),
    );
  }

  static pw.Widget _metaRow({
    required pw.TextStyle labelStyle,
    required pw.TextStyle valueStyle,
    required String label,
    required String value,
  }) {
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
              color: bold ? PdfColor.fromInt(0xFF0F4C81) : PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  static double _pageWidthForPaper(String paperWidth) {
    return paperWidth == '58'
        ? 58 * PdfPageFormat.mm
        : 80 * PdfPageFormat.mm;
  }

  static double _estimatePageHeight({
    required String paperWidth,
    required int itemCount,
    required int paymentCount,
    required bool hasDiscount,
    required bool hasQrCode,
    required bool hasCustomHeader,
    required bool hasCustomFooter,
  }) {
    final base = paperWidth == '58' ? 270.0 : 300.0;
    final itemHeight = paperWidth == '58' ? 28.0 : 24.0;
    final paymentHeight = paymentCount <= 0 ? 24.0 : paymentCount * 14.0;
    var height = base + (itemCount * itemHeight) + paymentHeight;
    if (hasDiscount) height += 12;
    if (hasQrCode) height += 92;
    if (hasCustomHeader) height += 18;
    if (hasCustomFooter) height += 16;
    return height.clamp(320.0, 1200.0);
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

  static int _quantityDecimalsForUnit(String unit) {
    final normalized = unit.trim().toLowerCase();
    if (normalized.isEmpty) return 0;
    if ([
      'l',
      'litre',
      'liter',
      'ltr',
      'liters',
      'litres',
      'gallon',
      'gal',
      'ml',
      'milliliter',
      'millilitre',
      'cyl',
      'cylinder',
      'cylinders',
      'tank',
      'tanks',
      'kg',
      'gram',
      'g',
      'lbs',
      'lb',
      'oz',
      'ounce',
    ].contains(normalized)) {
      return 3;
    }
    return 0;
  }

  static String _trimTrailingZeros(String text) {
    if (!text.contains('.')) return text;
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String _displayQty(double quantity, {String unit = ''}) {
    if (quantity % 1 == 0) return quantity.toInt().toString();
    if (unit.trim().isEmpty) return _trimTrailingZeros(quantity.toString());
    return _trimTrailingZeros(
      quantity.toStringAsFixed(_quantityDecimalsForUnit(unit)),
    );
  }

  static String _money(double value, String symbol) {
    return '$symbol${value.toStringAsFixed(2)}';
  }
}
