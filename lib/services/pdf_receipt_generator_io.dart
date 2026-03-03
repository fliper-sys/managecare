import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'pdf_utils.dart';

class PdfReceiptGenerator {
  /// Generate a PDF receipt and save it to device (IO platforms)
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
    required String paperWidth, // '58' for thermal, '80' for standard
    String? cashier,
    String? poweredByText,
    // Show a QR code linking to the web receipt URL when available
    bool showQrCode = false,
    String? receiptUrlBase,
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
      showQrCode: showQrCode,
      receiptUrlBase: receiptUrlBase,
    );

    // Save PDF to device
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/receipt_$receiptNumber.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Generate PDF receipt and return bytes (works on all platforms)
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
    // Style options
    String? stylePreset,
    String? accentColor,
    // Barcode / QR options
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
      // Standard thermal receipt height ~150-300mm (use 280mm / ~1063 points for typical receipt)
      pageHeight = 1063; // ~280mm - adjust after content rendering if needed
    } else {
      // Standard printer: 80mm = ~227 points
      pageWidth = 227;
      pageHeight = 1063; // Same height for consistency
    }
    
    // Use calculated page height that will be adjusted for actual content
    // Margin: 8pt all around for thermal, no extra bottom margin
    final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 8);

    // Load font and logo for header and currency glyph support
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
            buildPdfHeader(font: font, businessName: businessName, businessDetails: null, logoBytes: logoBytes, stylePreset: stylePreset, accentColorHex: accentColor),

            // Optional custom header
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

// Receipt Info (styled band)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF2C3E50), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  children: [
                    pw.Text('RECEIPT', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.SizedBox(height: 2),
                    pw.Text('No: $receiptNumber', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                    pw.SizedBox(height: 2),
                    pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(receiptDate), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFB0BEC5))),
                  ],
                ),
              ),
            ),

            // Cashier info (always render; default to 'Staff' when missing)
            pw.Text(
              'Cashier: ${cashier?.trim().isNotEmpty == true ? cashier : 'Staff'}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10),
            ),

            pw.SizedBox(height: 10),

            // Customer Info
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

              // Items Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.SizedBox(
                    width: pageWidth * 0.5 - 30,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text(
                      'Price',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1),

              // Items
              ...() {
                final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: symbol);
                return items.map((item) {
                final itemName = item['name'] ?? 'Item';
                final quantityRaw = item['quantity'] ?? item['qty'] ?? 1;
                final quantity = (quantityRaw is num) ? quantityRaw.toInt() : int.tryParse(quantityRaw.toString()) ?? 1;

                dynamic rawPrice = item['price'] ?? item['unitPrice'] ?? item['unit_price'] ?? 0.0;
                double price;
                if (rawPrice is num) {
                  price = rawPrice.toDouble();
                } else if (rawPrice is String) {
                  final cleaned = rawPrice.replaceAll(RegExp(r'[^0-9\.-]'), '');
                  price = double.tryParse(cleaned) ?? 0.0;
                } else {
                  price = 0.0;
                }

                final itemTotalVal = (quantity * price);
                final itemTotal = currencyFormat.format(itemTotalVal);
                final unitPriceFormatted = currencyFormat.format(price);

                return pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.SizedBox(
                          width: pageWidth * 0.5 - 30,
                          child: pw.Text(
                            itemName,
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.SizedBox(
                          width: 30,
                          child: pw.Text(
                            '$quantity',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.SizedBox(
                          width: 50,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                unitPriceFormatted,
                                textAlign: pw.TextAlign.right,
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.Text(
                                itemTotal,
                                textAlign: pw.TextAlign.right,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList();
              }(),

              pw.Divider(thickness: 1),
              pw.SizedBox(height: 5),

              // Compute fallback totals if caller passed zeros
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 0),
                child: pw.Builder(builder: (ctx) {
                  double computedSubtotalVal = 0.0;
                  for (final it in items) {
                    final qtyRaw = it['quantity'] ?? it['qty'] ?? 1;
                    final qty = (qtyRaw is num) ? qtyRaw.toDouble() : double.tryParse(qtyRaw.toString()) ?? 1.0;
                    dynamic rawPrice = it['price'] ?? it['unitPrice'] ?? it['unit_price'] ?? 0.0;
                    double priceVal;
                    if (rawPrice is num) {
                      priceVal = rawPrice.toDouble();
                    } else if (rawPrice is String) {
                      final cleaned = rawPrice.replaceAll(RegExp(r'[^0-9\.-]'), '');
                      priceVal = double.tryParse(cleaned) ?? 0.0;
                    } else {
                      priceVal = 0.0;
                    }
                    computedSubtotalVal += (qty * priceVal);
                  }

                  final effectiveSubtotal = subtotal > 0.0001 ? subtotal : computedSubtotalVal;
                  final effectiveTax = tax > 0.0001 ? tax : 0.0;
                  final effectiveTotal = total > 0.0001 ? total : (effectiveSubtotal + effectiveTax);

                  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: symbol);

                  return pw.Column(children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(currencyFormat.format(effectiveSubtotal), style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Tax:', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(currencyFormat.format(effectiveTax), style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Divider(thickness: 2),
                    pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFECF0F1), borderRadius: pw.BorderRadius.circular(6)),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2C3E50))),
                            pw.Text(currencyFormat.format(effectiveTotal), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2C3E50))),
                          ],
                        ),
                      ),
                  ]);
                }),
              ),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 5),

              // Payment Breakdown
              if (paymentBreakdown != null && paymentBreakdown.isNotEmpty) pw.Column(children: [
                pw.Text('Payments', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Column(children: paymentBreakdown.map((pb) {
                  final method = (pb['method'] ?? '').toString().toUpperCase();
                  final amount = (pb['amount'] ?? 0.0);
                  final tx = pb['transactionId'] ?? '';
                  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: symbol);
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text('$method${tx.toString().isNotEmpty ? ' • ${tx.toString()}' : ''}', style: pw.TextStyle(fontSize: 9))),
                      pw.Text(currencyFormat.format((amount as num).toDouble()), style: pw.TextStyle(fontSize: 9)),
                    ],
                  );
                }).toList()),
                pw.SizedBox(height: 10),
              ]) else pw.Column(children: [
                pw.Text(
                  'Payment: $paymentMethod',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 10),
              ]),

              // Footer
              if (customFooter != null && customFooter.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    customFooter,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                )
              else
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    poweredByText ?? 'Powered by Manage Care',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),

              // Barcode (receipt number) - always include to satisfy 'all receipts have a barcode'
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: receiptNumber,
                  width: pageWidth * 0.8,
                  height: 40,
                ),
              ),

              // Optional QR linking to a hosted receipt (controlled by receipt settings)
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

              pw.SizedBox(height: 5),
              pw.Text(
                'Thank you for your business!',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
              ],
            );
        },
          ));
        
    
    return Uint8List.fromList(await pdf.save());
  }

  /// Get receipt filename
  static String getReceiptFilename(String receiptNumber) {
    return 'receipt_$receiptNumber.pdf';
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
      'fitToPage': fitToPage, // Don't scale up/down
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
