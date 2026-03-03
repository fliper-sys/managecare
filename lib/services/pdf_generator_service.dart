import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../core/utils/currency.dart';
import 'pdf_utils.dart';

/// PDF generator service for creating receipts and reports
class PdfGeneratorService {
  static final PdfGeneratorService _instance = PdfGeneratorService._internal();

  factory PdfGeneratorService() {
    return _instance;
  }

  PdfGeneratorService._internal();

  /// Generate receipt PDF
  Future<String> generateReceipt(Map<String, dynamic> saleData) async {
    final pdf = pw.Document();

    // Extract data with defaults
    final businessName = saleData['businessName'] ?? 'Business';
    final orderId = saleData['id'] ?? saleData['orderId'] ?? 'N/A';
    final totalAmount =
        (saleData['total'] ?? saleData['amount'] ?? 0.0).toDouble();
    final items = saleData['items'] as List? ?? [];
    final date = saleData['date'] ?? DateTime.now().toString();
    final paymentMethod = saleData['paymentMethod'] ?? 'Cash';

    // Ensure robust font and logo so currency symbols (e.g. ₦) render correctly and header is consistent
    final fontResult = await loadDefaultPdfFont();
    final font = fontResult.font;
    final supportsNaira = fontResult.supportsNaira;
    final symbol = supportsNaira ? '₦' : 'NGN ';
    final logoBytes = await loadBusinessLogoBytes();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return [
            buildPdfHeader(font: font, businessName: businessName, businessDetails: null, logoBytes: logoBytes),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Order ID: $orderId'),
                pw.Text('Date: $date'),
              ],
            ),
            pw.SizedBox(height: 20),
            _buildItemsTable(items, symbol: symbol),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  formatCurrency(totalAmount, symbol: symbol),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment Method:'),
                pw.Text(paymentMethod),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Thank you for your purchase!',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return await _savePdf('receipt_$orderId', pdf);
  }

  /// Generate financial report PDF
  Future<String> generateReport(
    String reportType,
    Map<String, dynamic> filters,
  ) async {
    final pdf = pw.Document();

    final title = 'Financial Report - ${reportType.toUpperCase()}';
    final generatedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final startDate = filters['startDate'] ?? 'N/A';
    final endDate = filters['endDate'] ?? 'N/A';
    final data = filters['data'] as List? ?? [];

    // Load font and logo
    final fontResult = await loadDefaultPdfFont();
    final font = fontResult.font;
    final supportsNaira = fontResult.supportsNaira;
    final symbol = supportsNaira ? '₦' : 'NGN ';
    final logoBytes = await loadBusinessLogoBytes();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return [
            buildPdfHeader(font: font, businessName: 'Manage Care', businessDetails: null, logoBytes: logoBytes),

            pw.Center(
              child: pw.Text(
                title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Generated: $generatedDate'),
            pw.Text('Period: $startDate to $endDate'),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            _buildReportTable(data, reportType, symbol: symbol),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                'Confidential - For Internal Use Only',
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ];
        },
      ),
    );

    return await _savePdf(
        'report_${reportType}_${DateTime.now().millisecondsSinceEpoch}', pdf);
  }

  /// Save PDF to file
  Future<String> _savePdf(String fileName, pw.Document pdf) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Build items table for receipt
  pw.Widget _buildItemsTable(List items, {String symbol = '₦'}) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Item',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Qty',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Price',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        ...items.map(
          (item) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(item['name'] ?? 'Item'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text((item['quantity'] ?? 1).toString()),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(formatCurrency((item['price'] ?? 0.0).toDouble(), symbol: symbol)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  formatCurrency(((item['quantity'] ?? 1) * (item['price'] ?? 0.0)).toDouble(), symbol: symbol),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build report table
  pw.Widget _buildReportTable(List data, String reportType, {String symbol = '₦'}) {
    if (data.isEmpty) {
      return pw.Center(
        child: pw.Text('No data available for this period'),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Date',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Amount',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Details',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        ...data.map(
          (row) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(row['date']?.toString() ?? 'N/A'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(formatCurrency((row['amount'] ?? 0.0).toDouble(), symbol: symbol)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(row['description']?.toString() ?? 'N/A'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

