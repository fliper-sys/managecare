import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'pdf_utils.dart';

class PdfReceiptGenerator {
  /// On web, generate PDF bytes for download/emailing
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
    required String paperWidth, // '58' for thermal, '80' for standard
    String? cashier,
    String? poweredByText,
    bool showQrCode = false,
    String? receiptUrlBase,
  }) async {
    final pdf = pw.Document();

    // Determine page width and height based on paper setting
    double pageWidth;
    double pageHeight;
    
    if (paperWidth == '58') {
      // Thermal printer: 58mm width = ~220 points (at 72 DPI)
      pageWidth = 220;
      // Standard thermal receipt height ~280mm = ~1063 points
      pageHeight = 1063;
    } else {
      // Standard printer: 80mm = ~227 points
      pageWidth = 227;
      pageHeight = 1063; // Same height for consistency
    }
    
    // Use calculated page height with minimal margins for thermal printing
    final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 8);

    // Load font and logo for header and correct currency glyphs
    final fontResult = await loadDefaultPdfFont();
    final font = fontResult.font;
    final supportsNaira = fontResult.supportsNaira;
    final symbol = supportsNaira ? '₦' : 'NGN ';
    final logoBytes = await loadBusinessLogoBytes();

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(8),
        theme: pw.ThemeData.withFont(base: font),
        build: (context) {
          return pw.Column(
            children: [
            // Shared header
            buildPdfHeader(font: font, businessName: businessName, businessDetails: null, logoBytes: logoBytes),

            if (customHeader != null && customHeader.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  customHeader,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            pw.SizedBox(height: 5),
              pw.Text(
                'RECEIPT',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(
                'No: $receiptNumber',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm').format(receiptDate),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),

              // Cashier info (always render; default to 'Staff' when missing)
              pw.Text(
                'Cashier: ${cashier?.trim().isNotEmpty == true ? cashier : 'Staff'}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),

              pw.SizedBox(height: 10),
              pw.Divider(
                thickness: 1,
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(customerName, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 5),
              // Items (kept simple for web)
              pw.ListView(
                children: items.map((item) {
                  final itemName = item['name'] ?? 'Item';
                  final qty = item['quantity'] ?? item['qty'] ?? 1;

                  dynamic rawPrice = item['price'] ?? item['unitPrice'] ?? item['unit_price'] ?? 0.0;
                  double priceVal;
                  if (rawPrice is num) {
                    priceVal = rawPrice.toDouble();
                  } else if (rawPrice is String) {
                    final cleaned = rawPrice.replaceAll(RegExp(r'[^0-9\.-]'), '');
                    priceVal = double.tryParse(cleaned) ?? 0.0;
                  } else {
                    priceVal = 0.0;
                  }

                  final itemTotalVal = (qty * priceVal);

                  // Use currency format for display (ensures symbol + separators)
                  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: symbol);
                  final itemTotal = currencyFormat.format(itemTotalVal);
                  final unitPriceFormatted = currencyFormat.format(priceVal);

                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.SizedBox(
                        width: pageWidth * 0.5 - 30,
                        child: pw.Text(itemName, style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.SizedBox(
                        width: 30,
                        child: pw.Text('$qty', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.SizedBox(
                        width: 50,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(unitPriceFormatted, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
                            pw.Text(itemTotal, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 10),
              // Format total with currency formatter too
              pw.Text('Total: ${NumberFormat.currency(locale: 'en_NG', symbol: symbol).format(total)}', style:  pw.TextStyle(fontWeight: pw.FontWeight.bold)),

              pw.SizedBox(height: 8),

              // Barcode (receipt number) - always included
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: receiptNumber,
                  width: pageWidth * 0.8,
                  height: 40,
                ),
              ),

              // Optional QR linking to hosted receipt
              if (showQrCode && receiptUrlBase != null && receiptUrlBase.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: '${receiptUrlBase.replaceAll(RegExp(r'/*$'), '')}/$receiptNumber',
                    width: 80,
                    height: 80,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Center(child: pw.Text('Scan to view receipt', style: const pw.TextStyle(fontSize: 8))),
              ],

              // Show custom footer, then ALWAYS render a small powered-by line if it doesn't already include the brand
              if (customFooter != null && customFooter.isNotEmpty)
                pw.Column(children: [
                  pw.Text(customFooter, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                  if (!(customFooter.contains('Powered by Manage Care') || (poweredByText ?? '').contains('Powered by Manage Care')))
                    pw.Text(poweredByText ?? 'Powered by Manage Care', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                ])
              else
                pw.Text(poweredByText ?? 'Powered by Manage Care', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
              ],
          );
        },),);


    return Uint8List.fromList(await pdf.save());
  }

  /// Get receipt filename
  static String getReceiptFilename(String receiptNumber) {
    return 'receipt_$receiptNumber.pdf';
  }

  // Not supported on web
  static Future<dynamic> generateReceiptPdf({
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
    required String paperWidth, // '58' for thermal, '80' for standard
    String? cashier,
    String? poweredByText,
    bool showQrCode = false,
    String? receiptUrlBase,
  }) async {
    // On web we only support generating bytes via `generateReceiptPdfBytes`.
    // Accept optional `cashier` and `poweredByText` arguments to keep the
    // API consistent across platforms and avoid compile-time errors.
    throw UnsupportedError('generateReceiptPdf(File) is not supported on web. Use generateReceiptPdfBytes instead.');
  }


  /// Get recommended printer paper size based on receipt width
  /// Returns paper size name suitable for print settings
  static String getPrintPaperSize(String paperWidth) {
    if (paperWidth == '58') {
      // Thermal: 58mm x 300mm (common thermal roll)
      // Use custom size or nearest standard if not available
      return 'CUSTOM_58x300'; // Will be handled by print dialog
    } else {
      // Standard: 80mm x 300mm  
      return 'CUSTOM_80x300';
    }
  }

  /// Get print settings as JSON for configuring printer
  static Map<String, dynamic> getPrintSettings({
    required String paperWidth,
    bool fitToPage = true,
    bool autoRotate = true,
  }) {
    return {
      'paperWidth': paperWidth,
      'paperHeight': '300', // mm - thermal roll length
      'fitToPage': fitToPage,
      'autoRotate': autoRotate,
      'marginDetails': {
        'top': 0,
        'right': 8,
        'bottom': 0, // Minimal bottom margin for thermal
        'left': 8,
      },
    };
  }
}
