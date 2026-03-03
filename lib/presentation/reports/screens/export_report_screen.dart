import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import '../../../services/pdf_receipt_generator_io.dart';
import '../../../services/web_download.dart' as web_download;
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/reports_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/report_export_service.dart';

class ExportReportScreen extends StatefulWidget {
  const ExportReportScreen({super.key});

  @override
  State<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends State<ExportReportScreen> {
  String _selectedFormat = 'pdf';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeCharts = true;
  bool _includeNotes = false;
  bool _schedule = false;
  String _scheduleFrequency = 'weekly';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Export Report'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export Format Section
            const _SectionHeader(title: 'Export Format'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _ExportFormatCard(
                    format: 'pdf',
                    title: 'PDF Document',
                    description: 'Professional formatted document with charts',
                    icon: Icons.picture_as_pdf,
                    color: AppColors.error,
                    isSelected: _selectedFormat == 'pdf',
                    onSelect: () => setState(() => _selectedFormat = 'pdf'),
                  ),
                  const Divider(),

                  _ExportFormatCard(
                    format: 'csv',
                    title: 'CSV File',
                    description: 'Lightweight comma-separated values',
                    icon: Icons.insert_drive_file,
                    color: AppColors.info,
                    isSelected: _selectedFormat == 'csv',
                    onSelect: () => setState(() => _selectedFormat = 'csv'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date Range Section
            const _SectionHeader(title: 'Date Range'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DatePickerButton(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerButton(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Data Options Section
            const _SectionHeader(title: 'Data Options'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _CheckboxOption(
                    title: 'Include Charts',
                    subtitle: 'Visual representation of data',
                    value: _includeCharts,
                    onChanged: (value) {
                      setState(() => _includeCharts = value ?? false);
                    },
                  ),
                  const Divider(),
                  _CheckboxOption(
                    title: 'Include Notes & Comments',
                    subtitle: 'Add your annotations to the report',
                    value: _includeNotes,
                    onChanged: (value) {
                      setState(() => _includeNotes = value ?? false);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Scheduled Export Section
            const _SectionHeader(title: 'Scheduled Export'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable Scheduled Exports',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Automatically generate and send reports',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withAlpha(0xAA)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _schedule,
                        onChanged: (value) => setState(() => _schedule = value),
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                  if (_schedule) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Frequency',
                      style: AppTextStyles.body2
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['daily', 'weekly', 'monthly'].map((freq) {
                        final isSelected = _scheduleFrequency == freq;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _scheduleFrequency = freq),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  freq[0].toUpperCase() + freq.substring(1),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Export History
            const _SectionHeader(title: 'Export History'),
            const SizedBox(height: 12),
            const _ExportHistoryItem(
              fileName: 'Monthly_Report_Nov2024.pdf',
              format: 'PDF',
              date: 'Today, 3:45 PM',
              size: '2.3 MB',
              icon: Icons.picture_as_pdf,
              color: AppColors.error,
            ),
            const SizedBox(height: 8),
            const _ExportHistoryItem(
              fileName: 'Quarterly_Sales_Q3.csv',
              format: 'CSV',
              date: 'Yesterday, 10:20 AM',
              size: '1.8 MB',
              icon: Icons.insert_drive_file,
              color: AppColors.info,
            ),
            const SizedBox(height: 8),
            const _ExportHistoryItem(
              fileName: 'Customer_Data_Export.csv',
              format: 'CSV',
              date: '3 days ago',
              size: '856 KB',
              icon: Icons.insert_drive_file,
              color: AppColors.info,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Report preview opened'),
                          backgroundColor: AppColors.info,
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _exportReport(context);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReport(BuildContext context) async {
    final reportsProvider = context.read<ReportsProvider>();
    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();
    final businessId = businessProvider.currentBusiness?.id ??
        authProvider.currentUser?.businessId;
    final businessName = businessProvider.currentBusiness?.name ??
        authProvider.currentUser?.fullName ??
        'Business';

    if (businessId == null || businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business ID not found')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating report with real data...'),
            ],
          ),
        ),
      ),
    );

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      late String filePath;
      late String content;

      // Generate financial report with real data
      final financialSummary = reportsProvider.getFinancialSummary();
      final totalSales =
          (financialSummary['totalSales'] as num?)?.toDouble() ?? 0.0;
      final totalExpenses =
          (financialSummary['totalExpenses'] as num?)?.toDouble() ?? 0.0;
      final totalRevenue =
          (financialSummary['totalRevenue'] as num?)?.toDouble() ?? 0.0;
      final netProfit =
          (financialSummary['netProfit'] as num?)?.toDouble() ?? 0.0;

      // Get detailed transactions
      final transactions = reportsProvider.getDetailedTransactions() ?? [];

      final exportService = ReportExportService();

      if (_selectedFormat == 'pdf') {
        if (kIsWeb) {
          // Generate bytes and trigger browser download
          final footerWithPowered = 'Powered by Manage Care';
          const cashierName = 'System';

          final pdfBytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
            businessName: businessName,
            receiptNumber: 'Financial_Report_$timestamp',
            receiptDate: DateTime.now(),
            items: transactions,
            subtotal: totalSales,
            tax: 0.0,
            total: totalSales,
            paymentMethod: 'N/A',
            paymentBreakdown: null,
            customerName: businessName,
            customerEmail: null,
            customHeader: null,
            customFooter: footerWithPowered,
            paperWidth: '80',
            cashier: cashierName,
            poweredByText: footerWithPowered,
            showQrCode: false,
          );
          // Trigger download
          web_download.downloadBytes(
              pdfBytes, 'Financial_Report_$timestamp.pdf', 'application/pdf');
        } else {
          filePath = '${directory.path}/Financial_Report_$timestamp.pdf';

          final success = await exportService.exportFinancialReportPdf(
            filePath: filePath,
            businessName: businessName,
            startDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
            endDate: _endDate ?? DateTime.now(),
            totalSales: totalSales,
            totalExpenses: totalExpenses,
            totalRevenue: totalRevenue,
            netProfit: netProfit,
            detailedTransactions: transactions,
            includeCharts: _includeCharts,
            includeNotes: _includeNotes,
          );

          if (!success) throw Exception('PDF generation failed');

          // Share the file on non-web platforms
          await Share.shareXFiles([XFile(filePath)], text: 'Financial Report - PDF');
        }
      } else {
        // CSV
        content = exportService.exportFinancialCsv(
          businessName: businessName,
          startDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
          endDate: _endDate ?? DateTime.now(),
          totalSales: totalSales,
          totalExpenses: totalExpenses,
          totalRevenue: totalRevenue,
          netProfit: netProfit,
          detailedTransactions: transactions,
        );

        if (kIsWeb) {
          final csvBytes = Uint8List.fromList(content.codeUnits);
          web_download.downloadBytes(csvBytes, 'Financial_Report_$timestamp.csv', 'text/csv');
        } else {
          filePath = '${directory.path}/Financial_Report_$timestamp.csv';
          final file = File(filePath);
          await file.writeAsString(content);
          await Share.shareXFiles([XFile(filePath)], text: 'Financial Report - CSV');
        }
      } 

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report exported successfully with real data'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      print('Export error: $e');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.heading5.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ExportFormatCard extends StatelessWidget {
  final String format;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onSelect;

  const _ExportFormatCard({
    required this.format,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body2
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 12, color: color)
                  : const SizedBox(width: 12, height: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date!.day}/${date!.month}/${date!.year}'
                        : 'Select date',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: date != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool?)? onChanged;

  const _CheckboxOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportHistoryItem extends StatelessWidget {
  final String fileName;
  final String format;
  final String date;
  final String size;
  final IconData icon;
  final Color color;

  const _ExportHistoryItem({
    required this.fileName,
    required this.format,
    required this.date,
    required this.size,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style:
                      AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        format,
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      size,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloaded: $fileName'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon:
                const Icon(Icons.download, size: 18, color: AppColors.primary),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

