import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/currency.dart';
import 'pdf_utils.dart';

/// Thermal receipt PDF generator
/// Creates PDFs with exact sizing for thermal printers to minimize paper waste
class ThermalReceiptPdfGenerator {
  static const String _tag = '[ThermalReceiptPDF]';

  // Thermal printer specifications
  static const double pointsPerMm = 2.834645669;

  // Thermal paper widths
  static const int paperWidth58mm = 58;
  static const int paperWidth80mm = 80;

  // Character widths per line based on paper size and font
  static const int charsPerLine58mm = 30;
  static const int charsPerLine80mm = 48;

  // Receipt dimensions (in mm)
  static const int minHeight = 80;
  static const int maxHeight = 320;
  static const double marginMm = 1.5;

  /// Generate thermal receipt PDF
  /// Returns properly sized PDF for thermal printer
  static Future<Uint8List> generateReceiptPdf({
    required String businessName,
    required String receiptNumber,
    required DateTime receiptDate,
    required List<ReceiptItem> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    required String customerName,
    int paperWidth = paperWidth58mm,
    String? customHeader,
    String? customFooter,
    bool showQrCode = false,
    String? qrCodeUrl,
  }) async {
    _log('Generating receipt PDF for receipt #$receiptNumber');

    // Create document
    final doc = pw.Document();

    // Calculate dimensions
    final widthMm = paperWidth;
    final widthPt = widthMm * pointsPerMm;
    final heightMm = _calculateHeight(items, showQrCode, customHeader, customFooter);
    final heightPt = heightMm * pointsPerMm;

    _log('Page size: ${widthMm}mm x ${heightMm}mm');

    // Create page format
    final pageFormat = PdfPageFormat(
      widthPt,
      heightPt,
      marginLeft: marginMm * pointsPerMm,
      marginRight: marginMm * pointsPerMm,
      marginTop: marginMm * pointsPerMm,
      marginBottom: marginMm * pointsPerMm,
    );

    // Load a font with reliable currency support where available.
    final fontResult = await loadDefaultPdfFont();
    final font = fontResult.font;
    final currencySymbol = resolvePdfCurrencySymbol(fontResult.supportsNaira);

    // Build page
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(base: font),
        build: (context) => _buildReceiptWidget(
          font: font,
          businessName: businessName,
          receiptNumber: receiptNumber,
          receiptDate: receiptDate,
          items: items,
          subtotal: subtotal,
          tax: tax,
          discount: discount,
          total: total,
          paymentMethod: paymentMethod,
          customerName: customerName,
          customHeader: customHeader,
          customFooter: customFooter,
          showQrCode: showQrCode,
          qrCodeUrl: qrCodeUrl,
          charsPerLine: _getCharsPerLine(paperWidth),
          currencySymbol: currencySymbol,
        ),
      ),
    );

    final bytes = await doc.save();
    _log('PDF generated: ${bytes.length} bytes');
    return bytes;
  }

  /// Build the receipt widget
  static pw.Widget _buildReceiptWidget({
    required pw.Font font,
    required String businessName,
    required String receiptNumber,
    required DateTime receiptDate,
    required List<ReceiptItem> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    required String customerName,
    String? customHeader,
    String? customFooter,
    bool showQrCode = false,
    String? qrCodeUrl,
    required int charsPerLine,
    required String currencySymbol,
  }) {
    final children = <pw.Widget>[];

    // Business name (header)
    children.add(
      pw.Text(
        businessName,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
    children.add(pw.SizedBox(height: 3));

    // Custom header
    if (customHeader != null && customHeader.isNotEmpty) {
      children.add(
        pw.Text(
          customHeader,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
      );
      children.add(pw.SizedBox(height: 3));
    }

    // Receipt title
    children.add(
      pw.Text(
        'RECEIPT',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );

    // Receipt number
    children.add(
      pw.Text(
        'No: $receiptNumber',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 8.5),
      ),
    );

    // Receipt date
    children.add(
      pw.Text(
        DateFormat('dd/MM/yyyy HH:mm').format(receiptDate),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );

    // Separator
    children.add(pw.SizedBox(height: 2));
    children.add(_buildSeparator('=', charsPerLine, font));
    children.add(pw.SizedBox(height: 1));

    // Customer name
    children.add(
      pw.Text(
        'Customer: $customerName',
        style: pw.TextStyle(font: font, fontSize: 8.5),
      ),
    );

    // Separator
    children.add(_buildSeparator('-', charsPerLine, font));
    children.add(pw.SizedBox(height: 3));

    // Items header
    children.add(
      pw.Text(
        _formatLine('Item', 'Qty', 'Price', charsPerLine),
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
    children.add(_buildSeparator('-', charsPerLine, font));

    // Items
    for (final item in items) {
      final lineTotal = item.quantity * item.price;
      final qtyPrice = '${item.quantity} x ${formatCurrency(item.price, symbol: currencySymbol)}';
      children.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    item.name,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Text(
                  formatCurrency(lineTotal, symbol: currencySymbol),
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Text(
              qtyPrice,
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey800),
            ),
          ],
        ),
      );
      children.add(pw.SizedBox(height: 2));
    }

    // Separator
    children.add(_buildSeparator('=', charsPerLine, font));
    children.add(pw.SizedBox(height: 2));

    // Subtotal
    children.add(
      pw.Text(
        _formatLineRightAlign(
          'Subtotal:',
          formatCurrency(subtotal, symbol: currencySymbol),
          charsPerLine,
        ),
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );

    // Discount
    if (discount > 0) {
      children.add(
        pw.Text(
          _formatLineRightAlign(
            'Discount:',
            formatCurrency(discount, symbol: currencySymbol),
            charsPerLine,
          ),
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
      );
    }

    // Tax
    if (tax > 0) {
      children.add(
        pw.Text(
          _formatLineRightAlign(
            'Tax:',
            formatCurrency(tax, symbol: currencySymbol),
            charsPerLine,
          ),
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
      );
    }

    // Total
    children.add(_buildSeparator('=', charsPerLine, font));
    children.add(
      pw.Text(
        _formatLineRightAlign(
          'TOTAL:',
          formatCurrency(total, symbol: currencySymbol),
          charsPerLine,
        ),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
    children.add(_buildSeparator('=', charsPerLine, font));
    children.add(pw.SizedBox(height: 2));

    // Payment method
    children.add(
      pw.Text(
        'Payment: $paymentMethod',
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );

    // QR code
    if (showQrCode && qrCodeUrl != null && qrCodeUrl.isNotEmpty) {
      children.add(pw.SizedBox(height: 3));
      children.add(
        pw.Center(
          child: pw.Text(
            'QR: $qrCodeUrl',
            style: pw.TextStyle(font: font, fontSize: 6),
          ),
        ),
      );
    }

    // Custom footer
    if (customFooter != null && customFooter.isNotEmpty) {
      children.add(pw.SizedBox(height: 3));
      children.add(
        pw.Text(
          customFooter,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
      );
    }

    // Thank you message
    children.add(pw.SizedBox(height: 2));
    children.add(
      pw.Text(
        'Thank you!',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
    children.add(
      pw.Text(
        'Please come again',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  /// Build separator widget
  static pw.Widget _buildSeparator(String char, int charsPerLine, pw.Font font) {
    return pw.Text(
      char * charsPerLine,
      style: pw.TextStyle(font: font, fontSize: 8),
    );
  }

  /// Format line with left and right aligned text
  static String _formatLine(
    String left,
    String middle,
    String right,
    int charsPerLine,
  ) {
    final maxLeft = charsPerLine ~/ 3;
    final maxRight = charsPerLine ~/ 3;
    final maxMiddle = charsPerLine - maxLeft - maxRight;

    final leftPad = left.padRight(maxLeft).substring(0, maxLeft);
    final middlePad = middle.padRight(maxMiddle).substring(0, maxMiddle);
    final rightPad = right.padLeft(maxRight);

    return (leftPad + middlePad + rightPad).substring(0, charsPerLine);
  }

  /// Format line with left and right aligned text
  static String _formatLineRightAlign(
    String left,
    String right,
    int charsPerLine,
  ) {
    final leftPad = left.padRight(charsPerLine ~/ 2);
    final rightPad = right.padLeft(charsPerLine ~/ 2);
    return (leftPad + rightPad).substring(0, charsPerLine);
  }

  /// Get characters per line based on paper width
  static int _getCharsPerLine(int paperWidth) {
    return paperWidth == paperWidth58mm ? charsPerLine58mm : charsPerLine80mm;
  }

  /// Calculate receipt height based on content
  static int _calculateHeight(
    List<ReceiptItem> items,
    bool hasQr,
    String? customHeader,
    String? customFooter,
  ) {
    // Base height (header, separator, totals, footer)
    int height = 64;

    for (final item in items) {
      height += 7 + (item.name.length ~/ 24) * 4;
    }

    // QR code section
    if (hasQr) {
      height += 20;
    }
    if ((customHeader ?? '').trim().isNotEmpty) {
      height += 8;
    }
    if ((customFooter ?? '').trim().isNotEmpty) {
      height += 10;
    }

    // Ensure within bounds
    return height.clamp(minHeight, maxHeight);
  }

  static void _log(String message) {
    print('$_tag $message');
  }
}

/// Receipt item model
class ReceiptItem {
  final String name;
  final int quantity;
  final double price;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      name: map['name'] ?? map['productName'] ?? 'Unknown',
      quantity: (map['quantity'] ?? 1).toInt(),
      price: (map['price'] ?? map['unitPrice'] ?? 0).toDouble(),
    );
  }
}
