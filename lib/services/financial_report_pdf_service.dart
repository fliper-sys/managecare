import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'pdf_utils.dart';
import 'web_download.dart' as web_download;

class FinancialReportPdfOptions {
  final String title;
  final String note;
  final bool includeSummary;
  final bool includeInsights;
  final bool includeExpenseBreakdown;
  final bool includePaymentBreakdown;
  final bool includeInventorySummary;
  final bool includeMonthlyBreakdown;
  final bool includeTransactions;
  final int transactionLimit;

  const FinancialReportPdfOptions({
    this.title = 'Financial Performance Report',
    this.note = '',
    this.includeSummary = true,
    this.includeInsights = true,
    this.includeExpenseBreakdown = true,
    this.includePaymentBreakdown = true,
    this.includeInventorySummary = true,
    this.includeMonthlyBreakdown = true,
    this.includeTransactions = false,
    this.transactionLimit = 80,
  });

  FinancialReportPdfOptions copyWith({
    String? title,
    String? note,
    bool? includeSummary,
    bool? includeInsights,
    bool? includeExpenseBreakdown,
    bool? includePaymentBreakdown,
    bool? includeInventorySummary,
    bool? includeMonthlyBreakdown,
    bool? includeTransactions,
    int? transactionLimit,
  }) {
    return FinancialReportPdfOptions(
      title: title ?? this.title,
      note: note ?? this.note,
      includeSummary: includeSummary ?? this.includeSummary,
      includeInsights: includeInsights ?? this.includeInsights,
      includeExpenseBreakdown:
          includeExpenseBreakdown ?? this.includeExpenseBreakdown,
      includePaymentBreakdown:
          includePaymentBreakdown ?? this.includePaymentBreakdown,
      includeInventorySummary:
          includeInventorySummary ?? this.includeInventorySummary,
      includeMonthlyBreakdown:
          includeMonthlyBreakdown ?? this.includeMonthlyBreakdown,
      includeTransactions: includeTransactions ?? this.includeTransactions,
      transactionLimit: transactionLimit ?? this.transactionLimit,
    );
  }
}

class FinancialReportPeriodRow {
  final String label;
  final double revenue;
  final double cogs;
  final double operatingExpenses;
  final double salariesEstimate;
  final double utilitiesEstimate;

  const FinancialReportPeriodRow({
    required this.label,
    required this.revenue,
    required this.cogs,
    required this.operatingExpenses,
    this.salariesEstimate = 0,
    this.utilitiesEstimate = 0,
  });

  double get grossProfit => revenue - cogs;
  double get netProfit => grossProfit - operatingExpenses;
  double get margin => revenue == 0 ? 0 : (netProfit / revenue) * 100;
}

class FinancialReportTransactionRow {
  final DateTime date;
  final String description;
  final String type;
  final double amount;
  final String paymentMethod;
  final String cashier;
  final int itemCount;

  const FinancialReportTransactionRow({
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    this.paymentMethod = 'N/A',
    this.cashier = 'N/A',
    this.itemCount = 0,
  });
}

class FinancialReportPdfData {
  final String businessName;
  final String? businessAddress;
  final String? businessPhone;
  final String? businessEmail;
  final String? businessTaxId;
  final String? businessLogoUrl;
  final String? subscriptionTier;
  final String? businessClass;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  final String? generatedBy;
  final double totalRevenue;
  final double totalCogs;
  final double totalOperatingExpenses;
  final double grossProfit;
  final double netProfit;
  final double grossMargin;
  final double netProfitMargin;
  final double inventoryValue;
  final int inventoryItemCount;
  final List<FinancialReportPeriodRow> periods;
  final List<FinancialReportTransactionRow> transactions;
  final Map<String, double> paymentBreakdown;

  const FinancialReportPdfData({
    required this.businessName,
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    required this.totalRevenue,
    required this.totalCogs,
    required this.totalOperatingExpenses,
    required this.grossProfit,
    required this.netProfit,
    required this.grossMargin,
    required this.netProfitMargin,
    this.businessAddress,
    this.businessPhone,
    this.businessEmail,
    this.businessTaxId,
    this.businessLogoUrl,
    this.subscriptionTier,
    this.businessClass,
    this.generatedBy,
    this.inventoryValue = 0,
    this.inventoryItemCount = 0,
    this.periods = const [],
    this.transactions = const [],
    this.paymentBreakdown = const {},
  });

  double get totalExpenses => totalCogs + totalOperatingExpenses;

  double get estimatedSalaries => periods.fold<double>(
        0,
        (sum, row) => sum + row.salariesEstimate,
      );

  double get estimatedUtilities => periods.fold<double>(
        0,
        (sum, row) => sum + row.utilitiesEstimate,
      );
}

class FinancialReportPdfExportResult {
  final String fileName;
  final int bytes;

  const FinancialReportPdfExportResult({
    required this.fileName,
    required this.bytes,
  });
}

class FinancialReportPdfService {
  static final DateFormat _headerDateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _generatedDateFormat =
      DateFormat('dd MMM yyyy, HH:mm');
  static final DateFormat _transactionDateFormat = DateFormat('dd MMM yyyy');

  static Future<FinancialReportPdfExportResult> exportPdf({
    required FinancialReportPdfData data,
    FinancialReportPdfOptions options = const FinancialReportPdfOptions(),
    String fileBaseName = 'Financial_Report',
  }) async {
    final fileName =
        '${_safeFileName(fileBaseName)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await buildPdfBytes(data: data, options: options);

    if (kIsWeb) {
      web_download.downloadBytes(bytes, fileName, 'application/pdf');
    } else {
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: fileName,
      );
      await Share.shareXFiles(
        [file],
        text: '${data.businessName} financial report',
      );
    }

    return FinancialReportPdfExportResult(
      fileName: fileName,
      bytes: bytes.length,
    );
  }

  static Future<Uint8List> buildPdfBytes({
    required FinancialReportPdfData data,
    FinancialReportPdfOptions options = const FinancialReportPdfOptions(),
  }) async {
    final pdf = pw.Document();
    final branding = await loadPdfBranding(
      businessLogoUrl: data.businessLogoUrl,
      subscriptionTier: data.subscriptionTier,
      businessClass: data.businessClass,
    );

    final accent = PdfColor.fromInt(0xFF0F4C81);
    final surface = PdfColor.fromInt(0xFFF8FAFC);
    final outline = PdfColor.fromInt(0xFFD7E2F0);
    final revenueColor = PdfColor.fromInt(0xFF0F9D58);
    final warningColor = PdfColor.fromInt(0xFFF59E0B);
    final expenseColor = PdfColor.fromInt(0xFFE76F51);
    final muted = PdfColor.fromInt(0xFF475569);

    final money = NumberFormat.currency(
      locale: 'en_US',
      symbol: branding.currencySymbol,
      decimalDigits: 2,
    );
    final percent = NumberFormat('0.0');
    final primaryLogo = branding.showBusinessLogo
        ? branding.businessLogoBytes
        : branding.manageCareLogoBytes;
    final transactions = [...data.transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    final visibleTransactions = options.includeTransactions
        ? transactions.take(options.transactionLimit).toList()
        : const <FinancialReportTransactionRow>[];
    final insights = _buildInsights(data, money, percent);

    final details = <String>[
      if ((data.businessAddress ?? '').trim().isNotEmpty)
        data.businessAddress!.trim(),
      if ((data.businessPhone ?? '').trim().isNotEmpty)
        'Tel: ${data.businessPhone!.trim()}',
      if ((data.businessEmail ?? '').trim().isNotEmpty)
        data.businessEmail!.trim(),
      if ((data.businessTaxId ?? '').trim().isNotEmpty)
        'Tax ID: ${data.businessTaxId!.trim()}',
    ].join(' | ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        theme: pw.ThemeData.withFont(base: branding.font),
        build: (_) {
          return [
            buildPdfHeader(
              font: branding.font,
              businessName: data.businessName,
              businessDetails: details.isEmpty ? null : details,
              logoBytes: primaryLogo,
            ),
            _buildHero(
              font: branding.font,
              title: options.title,
              periodLabel:
                  '${_headerDateFormat.format(data.startDate)} - ${_headerDateFormat.format(data.endDate)}',
              generatedAt: _generatedDateFormat.format(data.generatedAt),
              generatedBy: (data.generatedBy ?? '').trim(),
              periodCount: data.periods.length,
              transactionCount: data.transactions.length,
              accent: accent,
            ),
            if (options.note.trim().isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _buildNoteBox(
                font: branding.font,
                note: options.note.trim(),
                outline: outline,
                muted: muted,
              ),
            ],
            if (options.includeSummary) ...[
              pw.SizedBox(height: 18),
              _buildSectionTitle('Performance Snapshot', branding.font),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildMetricCard(
                    font: branding.font,
                    label: 'Revenue',
                    value: money.format(data.totalRevenue),
                    subtitle: 'Sales captured in the selected period',
                    accent: revenueColor,
                  ),
                  _buildMetricCard(
                    font: branding.font,
                    label: 'COGS',
                    value: money.format(data.totalCogs),
                    subtitle: 'Direct product cost from sold inventory',
                    accent: warningColor,
                  ),
                  _buildMetricCard(
                    font: branding.font,
                    label: 'Operating Expenses',
                    value: money.format(data.totalOperatingExpenses),
                    subtitle: 'Tracked expenses excluding product cost',
                    accent: expenseColor,
                  ),
                  _buildMetricCard(
                    font: branding.font,
                    label: 'Gross Profit',
                    value: money.format(data.grossProfit),
                    subtitle:
                        '${percent.format(data.grossMargin)}% gross margin',
                    accent: accent,
                  ),
                  _buildMetricCard(
                    font: branding.font,
                    label: 'Net Profit',
                    value: money.format(data.netProfit),
                    subtitle:
                        '${percent.format(data.netProfitMargin)}% net margin',
                    accent: data.netProfit >= 0 ? revenueColor : expenseColor,
                  ),
                  if (options.includeInventorySummary)
                    _buildMetricCard(
                      font: branding.font,
                      label: 'Inventory Value',
                      value: money.format(data.inventoryValue),
                      subtitle:
                          '${data.inventoryItemCount} items currently in stock',
                      accent: PdfColor.fromInt(0xFF7C3AED),
                    ),
                ],
              ),
            ],
            if (options.includeInsights && insights.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildSectionTitle('Report Insights', branding.font),
              pw.SizedBox(height: 10),
              _buildInsightsCard(
                font: branding.font,
                insights: insights,
                surface: surface,
                outline: outline,
                muted: muted,
              ),
            ],
            if (options.includeExpenseBreakdown) ...[
              pw.SizedBox(height: 18),
              _buildSectionTitle('Expense Structure', branding.font),
              pw.SizedBox(height: 10),
              _buildExpenseTable(
                font: branding.font,
                data: data,
                money: money,
                percent: percent,
                accent: accent,
                muted: muted,
              ),
            ],
            if (options.includeInventorySummary) ...[
              pw.SizedBox(height: 18),
              _buildSectionTitle('Inventory Snapshot', branding.font),
              pw.SizedBox(height: 10),
              _buildInventoryCard(
                font: branding.font,
                data: data,
                money: money,
                outline: outline,
                muted: muted,
              ),
            ],
            if (options.includePaymentBreakdown &&
                data.paymentBreakdown.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildSectionTitle('Payment Mix', branding.font),
              pw.SizedBox(height: 10),
              _buildPaymentBreakdown(
                font: branding.font,
                paymentBreakdown: data.paymentBreakdown,
                money: money,
                percent: percent,
                accent: accent,
                outline: outline,
                muted: muted,
              ),
            ],
            if (options.includeMonthlyBreakdown && data.periods.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildSectionTitle('Monthly Breakdown', branding.font),
              pw.SizedBox(height: 10),
              _buildMonthlyTable(
                font: branding.font,
                periods: data.periods,
                money: money,
                percent: percent,
              ),
            ],
            if (options.includeTransactions && visibleTransactions.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildSectionTitle('Transaction Ledger', branding.font),
              pw.SizedBox(height: 6),
              pw.Text(
                visibleTransactions.length < transactions.length
                    ? 'Showing the most recent ${visibleTransactions.length} transactions.'
                    : 'All transactions currently loaded for the selected period.',
                style: pw.TextStyle(
                  font: branding.font,
                  fontSize: 9,
                  color: muted,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildTransactionTable(
                font: branding.font,
                transactions: visibleTransactions,
                money: money,
              ),
            ],
            if (data.periods.isEmpty &&
                data.transactions.isEmpty &&
                data.totalRevenue == 0 &&
                data.totalExpenses == 0) ...[
              pw.SizedBox(height: 20),
              _buildEmptyState(
                font: branding.font,
                muted: muted,
              ),
            ],
            pw.SizedBox(height: 18),
            _buildFootnote(
              font: branding.font,
              muted: muted,
            ),
            buildDocumentFooter(
              font: branding.font,
              manageCareLogoBytes: branding.manageCareLogoBytes,
            ),
          ];
        },
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static pw.Widget _buildHero({
    required pw.Font font,
    required String title,
    required String periodLabel,
    required String generatedAt,
    required String generatedBy,
    required int periodCount,
    required int transactionCount,
    required PdfColor accent,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: font,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'A focused view of profitability, expense pressure, and cash mix for the current reporting window.',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: PdfColor.fromInt(0xFFE6EEF7),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(font, 'Period: $periodLabel'),
              _buildPill(font, 'Generated: $generatedAt'),
              if (generatedBy.isNotEmpty)
                _buildPill(font, 'Prepared by: $generatedBy'),
              _buildPill(font, 'Months: $periodCount'),
              _buildPill(font, 'Transactions: $transactionCount'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPill(pw.Font font, String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x33FFFFFF),
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.5,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildNoteBox({
    required pw.Font font,
    required String note,
    required PdfColor outline,
    required PdfColor muted,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: outline),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Prepared Notes',
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            note,
            style: pw.TextStyle(
              font: font,
              fontSize: 9.5,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title, pw.Font font) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: font,
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _buildMetricCard({
    required pw.Font font,
    required String label,
    required String value,
    required String subtitle,
    required PdfColor accent,
  }) {
    return pw.Container(
      width: 165,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD8E5F2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 30,
            height: 4,
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(999),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInsightsCard({
    required pw.Font font,
    required List<String> insights,
    required PdfColor surface,
    required PdfColor outline,
    required PdfColor muted,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: surface,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: outline),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: insights
            .map(
              (insight) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '-',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(
                        insight,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 9.5,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  static pw.Widget _buildExpenseTable({
    required pw.Font font,
    required FinancialReportPdfData data,
    required NumberFormat money,
    required NumberFormat percent,
    required PdfColor accent,
    required PdfColor muted,
  }) {
    final total = data.totalExpenses;
    final rows = <List<String>>[
      [
        'Cost of Goods Sold',
        money.format(data.totalCogs),
        '${percent.format(total == 0 ? 0 : (data.totalCogs / total) * 100)}%',
      ],
      [
        'Operating Expenses',
        money.format(data.totalOperatingExpenses),
        '${percent.format(total == 0 ? 0 : (data.totalOperatingExpenses / total) * 100)}%',
      ],
      if (data.estimatedSalaries > 0)
        [
          'Estimated Salaries',
          money.format(data.estimatedSalaries),
          '${percent.format(total == 0 ? 0 : (data.estimatedSalaries / total) * 100)}%',
        ],
      if (data.estimatedUtilities > 0)
        [
          'Estimated Utilities',
          money.format(data.estimatedUtilities),
          '${percent.format(total == 0 ? 0 : (data.estimatedUtilities / total) * 100)}%',
        ],
      [
        'Total Expenses',
        money.format(total),
        total == 0 ? '0.0%' : '100.0%',
      ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(0.9),
          },
          children: [
            pw.TableRow(
              decoration:
                  pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8F0F8)),
              children: [
                _tableCell(font, 'Category', isHeader: true),
                _tableCell(font, 'Amount', isHeader: true),
                _tableCell(font, 'Share', isHeader: true),
              ],
            ),
            ...rows.map(
              (row) => pw.TableRow(
                children: [
                  _tableCell(font, row[0]),
                  _tableCell(font, row[1]),
                  _tableCell(font, row[2]),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Salary and utilities lines are estimated from the app\'s current operating-expense allocation.',
          style: pw.TextStyle(
            font: font,
            fontSize: 8.5,
            color: muted,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInventoryCard({
    required pw.Font font,
    required FinancialReportPdfData data,
    required NumberFormat money,
    required PdfColor outline,
    required PdfColor muted,
  }) {
    final coverageRatio = data.totalRevenue == 0
        ? 0.0
        : (data.inventoryValue / data.totalRevenue) * 100;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: outline),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Stock on hand is currently valued at ${money.format(data.inventoryValue)}.',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${data.inventoryItemCount} tracked items are included in this snapshot. Inventory value is ${coverageRatio.toStringAsFixed(1)}% of the selected period revenue.',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentBreakdown({
    required pw.Font font,
    required Map<String, double> paymentBreakdown,
    required NumberFormat money,
    required NumberFormat percent,
    required PdfColor accent,
    required PdfColor outline,
    required PdfColor muted,
  }) {
    final sortedEntries = paymentBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sortedEntries.fold<double>(0, (sum, entry) => sum + entry.value);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: outline),
      ),
      child: pw.Column(
        children: sortedEntries.map((entry) {
          final share = total == 0 ? 0.0 : entry.value / total;
          final normalizedShare = share.clamp(0.0, 1.0).toDouble();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      entry.key.toUpperCase(),
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${money.format(entry.value)} (${percent.format(share * 100)}%)',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 6,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE5EAF1),
                    borderRadius: pw.BorderRadius.circular(999),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        height: 6,
                        width: 420 * normalizedShare,
                        decoration: pw.BoxDecoration(
                          color: accent,
                          borderRadius: pw.BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildMonthlyTable({
    required pw.Font font,
    required List<FinancialReportPeriodRow> periods,
    required NumberFormat money,
    required NumberFormat percent,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.3),
        1: const pw.FlexColumnWidth(1.1),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(1.0),
        5: const pw.FlexColumnWidth(1.0),
        6: const pw.FlexColumnWidth(0.8),
      },
      children: [
        pw.TableRow(
          decoration:
              pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEF4FB)),
          children: [
            _tableCell(font, 'Month', isHeader: true),
            _tableCell(font, 'Revenue', isHeader: true),
            _tableCell(font, 'COGS', isHeader: true),
            _tableCell(font, 'OpEx', isHeader: true),
            _tableCell(font, 'Gross', isHeader: true),
            _tableCell(font, 'Net', isHeader: true),
            _tableCell(font, 'Margin', isHeader: true),
          ],
        ),
        ...periods.map(
          (row) => pw.TableRow(
            children: [
              _tableCell(font, row.label),
              _tableCell(font, money.format(row.revenue)),
              _tableCell(font, money.format(row.cogs)),
              _tableCell(font, money.format(row.operatingExpenses)),
              _tableCell(font, money.format(row.grossProfit)),
              _tableCell(font, money.format(row.netProfit)),
              _tableCell(font, '${percent.format(row.margin)}%'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTransactionTable({
    required pw.Font font,
    required List<FinancialReportTransactionRow> transactions,
    required NumberFormat money,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.35),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.1),
        1: const pw.FlexColumnWidth(2.6),
        2: const pw.FlexColumnWidth(0.8),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(0.9),
        5: const pw.FlexColumnWidth(1.1),
      },
      children: [
        pw.TableRow(
          decoration:
              pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEF4FB)),
          children: [
            _tableCell(font, 'Date', isHeader: true),
            _tableCell(font, 'Description', isHeader: true),
            _tableCell(font, 'Type', isHeader: true),
            _tableCell(font, 'Method', isHeader: true),
            _tableCell(font, 'Cashier', isHeader: true),
            _tableCell(font, 'Amount', isHeader: true),
          ],
        ),
        ...transactions.map(
          (tx) => pw.TableRow(
            children: [
              _tableCell(font, _transactionDateFormat.format(tx.date)),
              _tableCell(
                font,
                tx.itemCount > 0
                    ? '${tx.description} (${tx.itemCount} items)'
                    : tx.description,
              ),
              _tableCell(font, tx.type),
              _tableCell(font, tx.paymentMethod),
              _tableCell(font, tx.cashier),
              _tableCell(font, money.format(tx.amount)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildEmptyState({
    required pw.Font font,
    required PdfColor muted,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Text(
        'No financial activity was available for the selected date range. Try widening the range or syncing sales and expense entries first.',
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          color: muted,
        ),
      ),
    );
  }

  static pw.Widget _buildFootnote({
    required pw.Font font,
    required PdfColor muted,
  }) {
    return pw.Text(
      'This report is generated from the business data currently loaded in Manage Care. Profitability reflects revenue, cost of goods sold, and tracked operating expenses for the selected period.',
      style: pw.TextStyle(
        font: font,
        fontSize: 8.5,
        color: muted,
      ),
      textAlign: pw.TextAlign.center,
    );
  }

  static pw.Widget _tableCell(
    pw.Font font,
    String text, {
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static List<String> _buildInsights(
    FinancialReportPdfData data,
    NumberFormat money,
    NumberFormat percent,
  ) {
    final insights = <String>[];
    insights.add(
      data.netProfit >= 0
          ? 'The business stayed profitable with net profit of ${money.format(data.netProfit)} and a net margin of ${percent.format(data.netProfitMargin)}%.'
          : 'The business closed the period at a net loss of ${money.format(data.netProfit.abs())}, which puts net margin at ${percent.format(data.netProfitMargin)}%.',
    );

    final highestRevenueMonth = data.periods.isEmpty
        ? <FinancialReportPeriodRow>[]
        : [...data.periods]
          ..sort((a, b) => b.revenue.compareTo(a.revenue));
    if (highestRevenueMonth.isNotEmpty) {
      final topMonth = highestRevenueMonth.first;
      insights.add(
        '${topMonth.label} produced the strongest revenue at ${money.format(topMonth.revenue)}.',
      );
    }

    if (data.totalRevenue > 0) {
      final expenseRatio = (data.totalExpenses / data.totalRevenue) * 100;
      insights.add(
        'Combined expenses consumed ${percent.format(expenseRatio)}% of revenue over this reporting window.',
      );
    }

    if (data.paymentBreakdown.isNotEmpty) {
      final topMethod = data.paymentBreakdown.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final totalPayments = data.paymentBreakdown.values.fold<double>(
        0,
        (sum, value) => sum + value,
      );
      if (topMethod.isNotEmpty && totalPayments > 0) {
        final leader = topMethod.first;
        final share = (leader.value / totalPayments) * 100;
        insights.add(
          '${leader.key.toUpperCase()} handled the largest share of recorded payments at ${percent.format(share)}% of the mix.',
        );
      }
    }

    if (data.inventoryValue > 0 && data.totalRevenue > 0) {
      final coverage = (data.inventoryValue / data.totalRevenue) * 100;
      insights.add(
        'Inventory on hand is valued at ${money.format(data.inventoryValue)}, equal to ${percent.format(coverage)}% of revenue for the selected period.',
      );
    }

    return insights.take(5).toList();
  }

  static String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }
}
