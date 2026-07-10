import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_utils.dart';

/// Service to export reports with real data in multiple formats
class ReportExportService {
  static final ReportExportService _instance = ReportExportService._internal();

  factory ReportExportService() {
    return _instance;
  }

  ReportExportService._internal();

  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  /// Export financial report as PDF with real data
  Future<bool> exportFinancialReportPdf({
    required String filePath,
    required String businessName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalSales,
    required double totalExpenses,
    required double totalRevenue,
    required double netProfit,
    required List<Map<String, dynamic>> detailedTransactions,
    required bool includeCharts,
    required bool includeNotes,
  }) async {
    try {
      final pdf = pw.Document();

      // load font and logo
      final fontResult = await loadDefaultPdfFont();
      final font = fontResult.font;
      final supportsNaira = fontResult.supportsNaira;
      final logoBytes = await loadBusinessLogoBytes();
      final currency = NumberFormat.currency(locale: 'en_NG', symbol: supportsNaira ? '₦' : 'NGN ');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: font),
          build: (context) => [
            // Shared header
            buildPdfHeader(font: font, businessName: businessName, businessDetails: null, logoBytes: logoBytes),

            // Title
            pw.Text(
              'Financial Report',
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              businessName,
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 20),

            // Report Metadata
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Generated: ${DateTime.now().toString().split('.')[0]}',
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
                ),
                pw.Text(
                  'Period: ${_dateFormat.format(startDate)} to ${_dateFormat.format(endDate)}',
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Financial Summary Table
            pw.Text(
              'Financial Summary',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildTableCell('Item', bold: true),
                    _buildTableCell('Amount', bold: true),
                    _buildTableCell('% of Total', bold: true),
                  ],
                ),
                // Data rows
                pw.TableRow(
                  children: [
                    _buildTableCell('Total Sales'),
                    _buildTableCell(currency.format(totalSales)),
                    _buildTableCell(
                      '${((totalSales / (totalSales + totalExpenses)) * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Total Expenses'),
                    _buildTableCell(currency.format(totalExpenses)),
                    _buildTableCell(
                      '${((totalExpenses / (totalSales + totalExpenses)) * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Total Revenue'),
                    _buildTableCell(currency.format(totalRevenue)),
                    _buildTableCell('100.0%'),
                  ],
                ),
                // Net profit (highlighted)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell(
                      'Net Profit',
                      bold: true,
                    ),
                    _buildTableCell(
                      currency.format(netProfit),
                      bold: true,
                    ),
                    _buildTableCell(
                      '${((netProfit / totalRevenue) * 100).toStringAsFixed(1)}%',
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Detailed Transactions
            if (detailedTransactions.isNotEmpty) ...[
              pw.Text(
                'Detailed Transactions',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Date', bold: true),
                      _buildTableCell('Description', bold: true),
                      _buildTableCell('Type', bold: true),
                      _buildTableCell('Amount', bold: true),
                    ],
                  ),
                  // Transaction rows
                  ...detailedTransactions.take(20).map((transaction) {
                    final amount = transaction['amount'] ?? 0.0;
                    final type = transaction['type'] ?? 'Other';
                    return pw.TableRow(
                      children: [
                        _buildTableCell(
                          _dateFormat.format(
                            DateTime.tryParse(transaction['date'].toString()) ??
                                DateTime.now(),
                          ),
                        ),
                        _buildTableCell(
                          transaction['description'] ?? 'N/A',
                        ),
                        _buildTableCell(type),
                        _buildTableCell(
                          currency.format(amount),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              if (detailedTransactions.length > 20)
                pw.SizedBox(
                  height: 10,
                ),
              if (detailedTransactions.length > 20)
                pw.Text(
                  'Showing first 20 of ${detailedTransactions.length} transactions. Export to CSV for complete list.',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
            ],

            pw.SizedBox(height: 30),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'This is an auto-generated financial report. All figures are based on actual business data.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      return true;
    } catch (e) {
      print('Error generating PDF: $e');
      return false;
    }
  }

  /// Export sales report as PDF with real data
  Future<bool> exportSalesReportPdf({
    required String filePath,
    required String businessName,
    required DateTime startDate,
    required DateTime endDate,
    required int totalTransactions,
    required double totalSalesAmount,
    required Map<String, double> salesByCategory,
    required Map<String, int> transactionsByPaymentMethod,
    required List<Map<String, dynamic>> topProducts,
  }) async {
    try {
      final pdf = pw.Document();

      // load font and logo
      final fontResult = await loadDefaultPdfFont();
      final font = fontResult.font;
      final supportsNaira = fontResult.supportsNaira;
      final logoBytes = await loadBusinessLogoBytes();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: font),
          build: (context) => [
            // Shared header
            buildPdfHeader(font: font, businessName: businessName, businessDetails: null, logoBytes: logoBytes),

            // Title
            pw.Text(
              'Sales Report',
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              businessName,
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 20),

            // Metadata
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Generated: ${DateTime.now().toString().split('.')[0]}',
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
                ),
                pw.Text(
                  'Period: ${_dateFormat.format(startDate)} to ${_dateFormat.format(endDate)}',
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Sales Summary
            pw.Text(
              'Sales Summary',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildTableCell('Metric', bold: true),
                    _buildTableCell('Value', bold: true),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Total Transactions'),
                    _buildTableCell('$totalTransactions'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Total Sales Amount'),
                    _buildTableCell(
                      _currencyFormat.format(totalSalesAmount),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Average Transaction'),
                    _buildTableCell(
                      _currencyFormat.format(totalTransactions > 0
                          ? totalSalesAmount / totalTransactions
                          : 0),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Sales by Category
            if (salesByCategory.isNotEmpty) ...[
              pw.Text(
                'Sales by Category',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Category', bold: true),
                      _buildTableCell('Amount', bold: true),
                      _buildTableCell('% Share', bold: true),
                    ],
                  ),
                  ...salesByCategory.entries.map((entry) {
                    final percentage = (entry.value / totalSalesAmount * 100)
                        .toStringAsFixed(1);
                    return pw.TableRow(
                      children: [
                        _buildTableCell(entry.key),
                        _buildTableCell(
                          _currencyFormat.format(entry.value),
                        ),
                        _buildTableCell('$percentage%'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 30),
            ],

            // Top Products
            if (topProducts.isNotEmpty) ...[
              pw.Text(
                'Top Products',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Product', bold: true),
                      _buildTableCell('Units Sold', bold: true),
                      _buildTableCell('Revenue', bold: true),
                    ],
                  ),
                  ...topProducts.take(10).map((product) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(product['name'] ?? 'N/A'),
                        _buildTableCell('${product['quantity'] ?? 0}'),
                        _buildTableCell(
                          _currencyFormat.format(product['revenue'] ?? 0.0),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],

            pw.SizedBox(height: 30),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'This is an auto-generated sales report. All figures are based on actual transaction data.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      return true;
    } catch (e) {
      print('Error generating sales PDF: $e');
      return false;
    }
  }

  /// Export financial data as CSV
  String exportFinancialCsv({
    required String businessName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalSales,
    required double totalExpenses,
    required double totalRevenue,
    required double netProfit,
    required List<Map<String, dynamic>> detailedTransactions,
  }) {
    final rows = <List<String>>[
      ['Financial Report'],
      ['Business', businessName],
      ['Generated', DateTime.now().toString().split('.')[0]],
      [
        'Period',
        '${_dateFormat.format(startDate)} to ${_dateFormat.format(endDate)}'
      ],
      [],
      ['Financial Summary'],
      ['Item', 'Amount'],
      ['Total Sales', _currencyFormat.format(totalSales)],
      ['Total Expenses', _currencyFormat.format(totalExpenses)],
      ['Total Revenue', _currencyFormat.format(totalRevenue)],
      ['Net Profit', _currencyFormat.format(netProfit)],
      [],
      ['Detailed Transactions'],
      ['Date', 'Description', 'Type', 'Amount'],
      ...detailedTransactions.map((t) => [
            _dateFormat.format(
                DateTime.tryParse(t['date'].toString()) ?? DateTime.now()),
            t['description'] ?? 'N/A',
            t['type'] ?? 'Other',
            _currencyFormat.format(t['amount'] ?? 0.0),
          ]),
    ];

    // Convert to CSV format
    return rows.map((row) => row.map((cell) => '"$cell"').join(',')).join('\n');
  }

  /// Export sales data as CSV
  String exportSalesCsv({
    required String businessName,
    required DateTime startDate,
    required DateTime endDate,
    required int totalTransactions,
    required double totalSalesAmount,
    required Map<String, double> salesByCategory,
    required List<Map<String, dynamic>> topProducts,
  }) {
    final rows = <List<String>>[
      ['Sales Report'],
      ['Business', businessName],
      ['Generated', DateTime.now().toString().split('.')[0]],
      [
        'Period',
        '${_dateFormat.format(startDate)} to ${_dateFormat.format(endDate)}'
      ],
      [],
      ['Sales Summary'],
      ['Metric', 'Value'],
      ['Total Transactions', '$totalTransactions'],
      ['Total Sales Amount', _currencyFormat.format(totalSalesAmount)],
      [
        'Average Transaction',
        _currencyFormat.format(
            totalTransactions > 0 ? totalSalesAmount / totalTransactions : 0)
      ],
      [],
      ['Sales by Category'],
      ['Category', 'Amount', '% Share'],
      ...salesByCategory.entries.map((e) => [
            e.key,
            _currencyFormat.format(e.value),
            '${(e.value / totalSalesAmount * 100).toStringAsFixed(1)}%',
          ]),
      [],
      ['Top Products'],
      ['Product', 'Units Sold', 'Revenue'],
      ...topProducts.take(20).map((p) => [
            p['name'] ?? 'N/A',
            '${p['quantity'] ?? 0}',
            _currencyFormat.format(p['revenue'] ?? 0.0),
          ]),
    ];

    // Convert to CSV format
    return rows.map((row) => row.map((cell) => '"$cell"').join(',')).join('\n');
  }

  /// Export procurements summary as PDF
  Future<bool> exportProcurementsPdf({
    required String filePath,
    required String businessName,
    required List<Map<String, dynamic>> procurements,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text('Procurements Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(businessName, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),

          // Table header
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(1.8),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('Date', bold: true),
                  _buildTableCell('Procurement ID', bold: true),
                  _buildTableCell('Supplier', bold: true),
                  _buildTableCell('Invoice', bold: true),
                  _buildTableCell('Baker', bold: true),
                  _buildTableCell('Sales Rep', bold: true),
                  _buildTableCell('Units', bold: true),
                  _buildTableCell('Total', bold: true, align: pw.TextAlign.right),
                ],
              ),
              ...procurements.map((p) {
                final dt = p['createdAt'] as DateTime?;
                final dateStr = dt != null ? _dateFormat.format(dt) : '';
                return pw.TableRow(children: [
                  _buildTableCell(dateStr),
                  _buildTableCell(p['id'] ?? ''),
                  _buildTableCell(p['supplierName'] ?? ''),
                  _buildTableCell(p['invoiceRef'] ?? ''),
                  _buildTableCell(p['bakerName'] ?? ''),
                  _buildTableCell(p['salesRepName'] ?? ''),
                  _buildTableCell('${p['totalQuantity'] ?? 0}'),
                  _buildTableCell(_currencyFormat.format((p['totalCost'] ?? 0.0)), align: pw.TextAlign.right),
                ]);
              }).toList(),
            ],
          ),

          pw.SizedBox(height: 12),

          // Detailed items for each procurement (first few items)
          ...procurements.map((p) {
            final items = (p['items'] as List?) ?? [];
            if (items.isEmpty) return pw.SizedBox.shrink();
            return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(height: 8),
              pw.Text('Items for ${p['id'] ?? ''}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey300), children: [
                    _buildTableCell('Item', bold: true),
                    _buildTableCell('Qty', bold: true),
                    _buildTableCell('Unit Cost', bold: true),
                    _buildTableCell('Total', bold: true),
                  ]),
                  ...items.map((it) => pw.TableRow(children: [
                        _buildTableCell(it['name'] ?? ''),
                        _buildTableCell('${it['quantity'] ?? 0}'),
                        _buildTableCell(_currencyFormat.format((it['cost'] ?? 0.0))),
                        _buildTableCell(_currencyFormat.format((it['total'] ?? 0.0)), align: pw.TextAlign.right),
                      ])),
                ],
              ),
            ]);
          }).toList(),
        ],
      ));

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      return true;
    } catch (e) {
      print('Error generating procurements PDF: $e');
      return false;
    }
  }

  pw.Widget _buildTableCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: bold ? 12 : 11,
        ),
        textAlign: align,
      ),
    );
  }
}

