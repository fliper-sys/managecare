import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class EnhancedPdfBuilder {
  /// Create a 58mm PDF receipt with optional QR image (using Barcode.qrCode)
  static Future<Uint8List> buildPdf({
    required String businessName,
    required String address,
    required String phone,
    required String orderId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double subtotal, 
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    required String footerMessage,
    String? currencySymbol,
    bool showQrCode = false,
    String? receiptUrlBase,
    Uint8List? logoBytes,
    String? stylePreset,
    String? accentColor,
  }) async {
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, PdfPageFormat.a4.height),
      build: (ctx) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.LayoutBuilder(builder: (ctx, constraints) {
                PdfColor resolveAccent() {
                  try {
                    if (accentColor != null && accentColor.startsWith('#')) {
                      final hex = accentColor.replaceFirst('#', '');
                      final v = int.parse('FF$hex', radix: 16);
                      return PdfColor.fromInt(v);
                    }
                  } catch (_) {}
                  return PdfColor.fromInt(0xFF2C3E50);
                }

                final accent = resolveAccent();

                if (stylePreset == 'minimal') {
                  return pw.Column(children: [
                    if (logoBytes != null) pw.Center(child: pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60)),
                    pw.SizedBox(height: 2),
                    pw.Center(child: pw.Text(businessName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                  ]);
                }

                // Professional or Colorful
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: pw.BoxDecoration(color: accent, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(children: [
                    if (logoBytes != null) pw.Center(child: pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60)),
                    pw.SizedBox(height: 2),
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ]),
                );
              }),
              pw.SizedBox(height: 6),
              if (address.isNotEmpty) pw.Text(address, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF666666))),
              if (phone.isNotEmpty) pw.Text('Tel: $phone', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF666666))),
              pw.Divider(),
              pw.Text('Receipt: $orderId', style: pw.TextStyle(fontSize: 8)),
              pw.Text('Date: ${date.toIso8601String()}', style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 6),
              // Items
              pw.Column(children: items.map((it) {
                final name = (it['name'] ?? 'Item').toString();
                final qty = (it['quantity'] ?? 1).toString();
                final lineTotal = (it['total'] ?? 0).toString();
                return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Expanded(child: pw.Text('$name', style: pw.TextStyle(fontSize: 8))),
                  pw.Text('$qty', style: pw.TextStyle(fontSize: 8)),
                  pw.Text('${currencySymbol ?? ''}$lineTotal', style: pw.TextStyle(fontSize: 8)),
                ]);
              }).toList()),
              pw.Divider(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFECF0F1), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2C3E50))),
                  pw.Text('${currencySymbol ?? ''}${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2C3E50))),
                ]),
              ),
              pw.SizedBox(height: 8),
              if (showQrCode && receiptUrlBase != null && receiptUrlBase.isNotEmpty)
                pw.Center(child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: '${receiptUrlBase.replaceAll(RegExp(r'/*$'), '')}/$orderId', width: 80, height: 80)),
              if (footerMessage.isNotEmpty) pw.SizedBox(height: 8),
              if (footerMessage.isNotEmpty) pw.Text(footerMessage, style: pw.TextStyle(fontSize: 8)),
            ],
          ),
        );
      },
    ));

    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
  }
}
