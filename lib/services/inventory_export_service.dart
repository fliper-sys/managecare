import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/utils/inventory_utils.dart';
import 'pdf_utils.dart';
import 'web_download.dart' as web_download;

class InventoryExportResult {
  final String fileName;
  final int bytes;

  const InventoryExportResult({
    required this.fileName,
    required this.bytes,
  });
}

class InventoryExportService {
  static String buildCsv(List<Map<String, dynamic>> items) {
    final buffer = StringBuffer();
    buffer.writeln('Product ID,Product Name,Category,SKU,Barcode,Quantity,Unit,Min Stock,Unit Price,Cost Price,Profit/Unit,Profit Total,Total Value,Status');

    for (final item in items) {
      final quantity = _toNum(item['quantity']);
      final minStock = _toNum(item['minStock'], fallback: 10);
      final unitPrice = _toDouble(item['price']);
      final costPrice = _toDouble(item['costPrice']);
      final profitPerUnit = unitPrice - costPrice;
      final profitTotal = profitPerUnit * quantity.toDouble();
      final totalValue = quantity.toDouble() * unitPrice;
      final status = quantity <= minStock ? 'Low Stock' : 'OK';
      final row = [
        item['id'] ?? '',
        item['name'] ?? '',
        item['category'] ?? '',
        item['sku'] ?? '',
        item['barcode'] ?? '',
        formatInventoryQuantity(quantity),
        canonicalizeInventoryUnit(item['unit']?.toString()),
        formatInventoryQuantity(minStock),
        unitPrice.toStringAsFixed(2),
        costPrice.toStringAsFixed(2),
        profitPerUnit.toStringAsFixed(2),
        profitTotal.toStringAsFixed(2),
        totalValue.toStringAsFixed(2),
        status,
      ];

      buffer.writeln(row.map(_escapeCsvCell).join(','));
    }

    return buffer.toString();
  }

  static Future<InventoryExportResult> exportCsv({
    required List<Map<String, dynamic>> items,
    required String businessName,
    String fileBaseName = 'Inventory_Export',
  }) async {
    final fileName = '${_safeFileName(fileBaseName)}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final csv = buildCsv(items);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    await _shareBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'text/csv',
      shareText: '$businessName inventory export',
    );

    return InventoryExportResult(fileName: fileName, bytes: bytes.length);
  }

  static Future<InventoryExportResult> exportPdf({
    required List<Map<String, dynamic>> items,
    required String businessName,
    String fileBaseName = 'Inventory_Export',
  }) async {
    final fileName = '${_safeFileName(fileBaseName)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final pdfBytes = await _buildPdfBytes(items: items, businessName: businessName);

    await _shareBytes(
      bytes: pdfBytes,
      fileName: fileName,
      mimeType: 'application/pdf',
      shareText: '$businessName inventory export',
    );

    return InventoryExportResult(fileName: fileName, bytes: pdfBytes.length);
  }

  static Future<Uint8List> _buildPdfBytes({
    required List<Map<String, dynamic>> items,
    required String businessName,
  }) async {
    final pdf = pw.Document();
    final fontResult = await loadDefaultPdfFont();
    final font = fontResult.font;
    final logoBytes = await loadBusinessLogoBytes();
    final symbol = 'NGN ';

    final totalValue = items.fold<double>(
      0,
      (sum, item) =>
          sum + (_toNum(item['quantity']).toDouble() * _toDouble(item['price'])),
    );
    final lowStockCount = items.where((item) {
      final quantity = _toNum(item['quantity']);
      final minStock = _toNum(item['minStock'], fallback: 10);
      return quantity <= minStock;
    }).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font),
        build: (context) => [
          buildPdfHeader(
            font: font,
            businessName: businessName,
            businessDetails: 'Inventory export',
            logoBytes: logoBytes,
          ),
          pw.Text(
            'Inventory Export',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryCard('Products', items.length.toString()),
              _summaryCard('Low Stock', lowStockCount.toString()),
              _summaryCard('Total Value', '$symbol${totalValue.toStringAsFixed(2)}'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.4),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(1.1),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.2),
              6: const pw.FlexColumnWidth(1.4),
              7: const pw.FlexColumnWidth(1.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEF2FF)),
                children: [
                  _tableCell('Product', isHeader: true),
                  _tableCell('Category', isHeader: true),
                  _tableCell('Quantity', isHeader: true),
                  _tableCell('Unit', isHeader: true),
                  _tableCell('Unit Price', isHeader: true),
                  _tableCell('Cost Price', isHeader: true),
                  _tableCell('Profit/Unit', isHeader: true),
                  _tableCell('Profit Total', isHeader: true),
                  _tableCell('Total Value', isHeader: true),
                  _tableCell('Status', isHeader: true),
                ],
              ),
              ...items.map((item) {
                final quantity = _toNum(item['quantity']);
                final minStock = _toNum(item['minStock'], fallback: 10);
                final unitPrice = _toDouble(item['price']);
                final costPrice = _toDouble(item['costPrice']);
                final profitPerUnit = unitPrice - costPrice;
                final profitTotal = profitPerUnit * quantity.toDouble();
                final total = quantity.toDouble() * unitPrice;
                final status = quantity <= minStock ? 'Low Stock' : 'OK';
                return pw.TableRow(
                  children: [
                    _tableCell((item['name'] ?? '').toString()),
                    _tableCell((item['category'] ?? '').toString()),
                    _tableCell(formatInventoryQuantity(quantity)),
                    _tableCell(canonicalizeInventoryUnit(item['unit']?.toString())),
                    _tableCell('$symbol${unitPrice.toStringAsFixed(2)}'),
                    _tableCell('$symbol${costPrice.toStringAsFixed(2)}'),
                    _tableCell('$symbol${profitPerUnit.toStringAsFixed(2)}'),
                    _tableCell('$symbol${profitTotal.toStringAsFixed(2)}'),
                    _tableCell('$symbol${total.toStringAsFixed(2)}'),
                    _tableCell(
                      status,
                      color: status == 'Low Stock' ? PdfColors.orange800 : PdfColors.green700,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static Future<void> _shareBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String shareText,
  }) async {
    if (kIsWeb) {
      web_download.downloadBytes(bytes, fileName, mimeType);
      return;
    }

    final file = XFile.fromData(
      bytes,
      mimeType: mimeType,
      name: fileName,
    );
    await Share.shareXFiles([file], text: shareText);
  }

  static String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }

  static String _escapeCsvCell(Object? value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  static num _toNum(dynamic value, {num fallback = 0}) {
    if (value is num) return value;
    if (value == null) return fallback;
    return num.tryParse(value.toString()) ?? fallback;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  static pw.Widget _summaryCard(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: color,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
        ),
      ),
    );
  }
}
