import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../services/export_service.dart';
import '../../../widgets/custom_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExportSalesHistoryScreen extends StatefulWidget {
  const ExportSalesHistoryScreen({super.key});

  @override
  State<ExportSalesHistoryScreen> createState() =>
      _ExportSalesHistoryScreenState();
}

class _ExportSalesHistoryScreenState extends State<ExportSalesHistoryScreen> {
  String _selectedFormat = 'pdf'; // pdf, csv, json
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeImages = false;
  bool _isExporting = false;
  String? _exportMessage;

  // Sales listing & filtering
  List<Map<String, dynamic>> _salesList = [];
  bool _isLoadingSales = false;
  String _searchQuery = '';

  // Last restore notification (populated after a delete that restored stock)
  Map<String, dynamic>? _lastRestoreNotification;
  DateTime? _lastRestoreAt;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _endDate = DateTime.now();
    // initial load after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSales());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    if (!auth.isOwnerUser) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Export Sales History'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: theme.iconTheme.color),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Only business owners can access this feature. Please contact the account owner to perform exports or manage historical sales.', textAlign: TextAlign.center, style: AppTextStyles.body2),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Export Sales History'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export Format Selection
            _buildSectionHeader('Export Format'),
            const SizedBox(height: 12),
            _buildFormatSelector(),
            const SizedBox(height: 24),

            // Date Range Selection
            _buildSectionHeader('Date Range'),
            const SizedBox(height: 12),
            _buildDateRangeSelector(),
            const SizedBox(height: 24),

            // Options
            _buildSectionHeader('Options'),
            const SizedBox(height: 12),
            _buildOptions(),
            const SizedBox(height: 32),

            // Preview
            if (_selectedFormat != 'pdf') ...[
              _buildSectionHeader('Preview Settings'),
              const SizedBox(height: 12),
              _buildPreview(),
              const SizedBox(height: 32),
            ],

            // Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 16),

            // Status Message
            if (_exportMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _exportMessage!.contains('successfully')
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _exportMessage!.contains('successfully')
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _exportMessage!.contains('successfully')
                          ? Icons.check_circle
                          : Icons.error,
                      color: _exportMessage!.contains('successfully')
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _exportMessage!,
                        style: AppTextStyles.body2.copyWith(
                          color: _exportMessage!.contains('successfully')
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            _buildSalesHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.heading5.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildFormatOption('PDF', 'pdf', '📄 Professional report format'),
          const Divider(height: 1),
          _buildFormatOption('CSV', 'csv', '📊 Spreadsheet compatible'),
          const Divider(height: 1),
          _buildFormatOption('JSON', 'json', '💾 Structured data format'),

        ],
      ),
    );
  }

  Widget _buildFormatOption(String label, String value, String description) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: _selectedFormat == value
            ? AppColors.primary.withOpacity(0.05)
            : Colors.transparent,
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedFormat,
              onChanged: (val) {
                if (val != null) setState(() => _selectedFormat = val);
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Start Date
          _buildDateField(
            label: 'Start Date',
            date: _startDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _startDate = picked);
              }
            },
          ),
          const SizedBox(height: 16),
          // End Date
          _buildDateField(
            label: 'End Date',
            date: _endDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _endDate = picked);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date != null
                      ? DateFormat('dd MMM yyyy').format(date)
                      : 'Select date',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_today, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Include Images Option
          _buildOptionItem(
            'Include Product Images',
            'Add product images to the export',
            _includeImages,
            (value) => setState(() => _includeImages = value),
          ),
          const Divider(height: 1),
          // Auto Backup Option
          _buildOptionItem(
            'Auto Backup',
            'Automatically backup this export',
            context.read<SettingsProvider>().autoBackup,
            (value) => _updateAutoBackup(value),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export Settings Summary',
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Format', _selectedFormat.toUpperCase()),
          _buildSummaryRow(
            'Date Range',
            '${DateFormat('dd MMM').format(_startDate ?? DateTime.now())} - ${DateFormat('dd MMM yyyy').format(_endDate ?? DateTime.now())}',
          ),
          _buildSummaryRow(
            'Include Images',
            _includeImages ? 'Yes' : 'No',
          ),
          _buildSummaryRow(
            'File Size (estimated)',
            '~2.5 MB',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomButton(
          text: _isExporting ? 'Exporting...' : 'Export Now',
          onPressed: _isExporting ? null : _handleExport,
          isLoading: _isExporting,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _isExporting ? null : _handleShare,
          child: const Text('Export & Share'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isExporting ? null : _handleGenerateReport,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Generate Report'),
        ),
      ],
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final reports = context.read<ReportsProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      final raw = await reports.fetchSalesList(businessId: businessId, start: _startDate, end: _endDate, search: _searchQuery, limit: 5000);

      String filename = ExportService.getExportFilename(_selectedFormat);
      final dir = await getTemporaryDirectory();
      final filepath = '${dir.path}/$filename';
      final file = File(filepath);

      switch (_selectedFormat) {
        case 'csv':
          final content = await ExportService.exportRawToCSV(raw);
          await file.writeAsString(content);
          break;
        case 'json':
          final content = await ExportService.exportRawToJSON(raw);
          await file.writeAsString(content);
          break;
        case 'txt':
          final content = await ExportService.generateSummaryFromRaw(raw);
          await file.writeAsString(content);
          break;
        default:
          final content = await ExportService.exportRawToCSV(raw);
          await file.writeAsString(content);
      }

      // Update last export date
      final settingsProvider = context.read<SettingsProvider>();
      final businessProvider = context.read<BusinessProvider>();
      final auth = context.read<AuthProvider>();
      if (businessProvider.currentBusiness?.id != null) {
        await settingsProvider.updateLastExportDate(
          businessProvider.currentBusiness!.id,
          auth.currentUser?.id ?? 'system',
        );
      }

      setState(() {
        _exportMessage = 'Export completed successfully! Saved to $filepath';
        _isExporting = false;
      });

      // Show actions to open/share/copy
      _showExportActions(filepath);

    } catch (e) {
      setState(() {
        _exportMessage = 'Export failed: $e';
        _isExporting = false;
      });
      _showErrorSnackBar('Failed to export sales history: $e');
    }
  }

  Future<void> _handleShare() async {
    setState(() => _isExporting = true);

    try {
      final reports = context.read<ReportsProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      final raw = await reports.fetchSalesList(businessId: businessId, start: _startDate, end: _endDate, search: _searchQuery, limit: 5000);

      String filename = ExportService.getExportFilename(_selectedFormat);
      final dir = await getTemporaryDirectory();
      final filepath = '${dir.path}/$filename';
      final file = File(filepath);

      switch (_selectedFormat) {
        case 'csv':
          final content = await ExportService.exportRawToCSV(raw);
          await file.writeAsString(content);
          break;
        case 'json':
          final content = await ExportService.exportRawToJSON(raw);
          await file.writeAsString(content);
          break;
        case 'txt':
          final content = await ExportService.generateSummaryFromRaw(raw);
          await file.writeAsString(content);
          break;
        default:
          final content = await ExportService.exportRawToCSV(raw);
          await file.writeAsString(content);
      }

      setState(() {
        _exportMessage = 'Preparing to share...';
        _isExporting = false;
      });

      await Share.shareXFiles([XFile(filepath)], text: 'Sales History Export - $_selectedFormat format');

      // Offer the user to open or copy path after sharing
      _showExportActions(filepath);
    } catch (e) {
      setState(() {
        _exportMessage = 'Share failed: $e';
        _isExporting = false;
      });
      _showErrorSnackBar('Failed to prepare share: $e');
    }
  }

  Future<void> _handleGenerateReport() async {
    setState(() => _isExporting = true);

    try {
      final reports = context.read<ReportsProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      final raw = await reports.fetchSalesList(businessId: businessId, start: _startDate, end: _endDate, search: _searchQuery, limit: 5000);

      final summary = await ExportService.generateSummaryFromRaw(raw);

      final dir = await getTemporaryDirectory();
      final filename = ExportService.getExportFilename('txt');
      final filepath = '${dir.path}/$filename';
      final file = File(filepath);
      await file.writeAsString(summary);

      setState(() {
        _exportMessage = 'Report generated successfully! Saved to $filepath';
        _isExporting = false;
      });

      _showSuccessSnackBar('Sales report generated and ready to download');
    } catch (e) {
      setState(() {
        _exportMessage = 'Report generation failed: $e';
        _isExporting = false;
      });
      _showErrorSnackBar('Failed to generate report: $e');
    }
  }

  Future<void> _applyFilters() async {
    if (_startDate == null || _endDate == null) return;
    setState(() => _isLoadingSales = true);
    final reports = context.read<ReportsProvider>();
    reports.setSalesDateRange(_startDate!, _endDate!);
    await _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoadingSales = true);
    try {
      final reports = context.read<ReportsProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      final list = await reports.fetchSalesList(businessId: businessId, start: _startDate, end: _endDate, search: _searchQuery, limit: 2000);
      setState(() {
        _salesList = list;
        _isLoadingSales = false;
      });
    } catch (e) {
      setState(() => _isLoadingSales = false);
      _showErrorSnackBar('Failed to load sales: $e');
    }
  }

  Future<void> _confirmDelete(String saleId) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete sale?'),
      content: const Text('This will permanently delete the sale record and restore the previously deducted stock. Are you sure?'),
      actions: [
        TextButton(onPressed: ()=>Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: ()=>Navigator.of(ctx).pop(true), child: const Text('Delete')),
      ],
    ));
    if (confirm == true) {
      await _deleteSale(saleId);
    }
  }

  Future<void> _deleteSale(String saleId) async {
    setState(() => _isLoadingSales = true);
    try {
      final reports = context.read<ReportsProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      
      // Ensure deleteSale completes fully before any UI update
      dynamic res;
      try {
        // Await the provider call and capture any thrown errors
        res = await reports.deleteSale(saleId, businessId: businessId);
      } on Object catch (err, st) {
        // Some platforms (web) may box thrown errors inside an AsyncError-like object
        String message = err.toString();
        String? stackString;

        // If it's an AsyncError (dart:async) extract underlying error & stack
        try {
          // Avoid importing dart:async type name directly in the condition to keep compatibility
          if (err is AsyncError) {
            message = (err.error?.toString() ?? message);
            stackString = err.stackTrace?.toString();
          }
        } catch (_) {}

        // If the error is a Map-like boxed object with 'error' and 'stack' keys
        try {
          if (err is Map && err.containsKey('error')) {
            message = (err['error']?.toString() ?? message);
            if (err.containsKey('stack') && err['stack'] != null) {
              stackString = err['stack'].toString();
            }
          }
        } catch (_) {}

        debugPrint('[ExportSalesHistoryScreen._deleteSale] Delete threw: $message');
        if (stackString != null) debugPrint('[ExportSalesHistoryScreen._deleteSale] Stack: $stackString');

        if (mounted) {
          _showErrorSnackBar('Failed to delete sale: $message');
          setState(() => _isLoadingSales = false);
        }
        return;
      }

      // Handle error response from provider
      if (res is Map) {
        final Map r = res as Map;
        if ((r['success'] ?? true) == false) {
          final msg = (r['error']?.toString() ?? 'Unknown error while deleting sale');
          if (mounted) {
            _showErrorSnackBar('Failed to delete sale: $msg');
            setState(() => _isLoadingSales = false);
          }
          return;
        }
      }
 
      // If items were restored, show an in-list dismissible notification
      if (mounted && res != null && (res['items'] is List) && (res['items'] as List).isNotEmpty) {
        setState(() {
          _lastRestoreNotification = res;
          _lastRestoreAt = DateTime.now();
        });
      }

      if (mounted) {
        _showSuccessSnackBar('Sale deleted');
        // Reset loading state before loading fresh data
        setState(() => _isLoadingSales = false);
      }
      
      // Now load fresh sales list
      await _loadSales();
    } catch (e) {
      debugPrint('[ExportSalesHistoryScreen._deleteSale] Error: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to delete sale: $e');
        setState(() => _isLoadingSales = false);
      }
    }
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Search by receipt, customer, payment method, product...',
        prefixIcon: Icon(Icons.search),
      ),
      onSubmitted: (v) {
        setState(() => _searchQuery = v.trim());
        _loadSales();
      },
    );
  }

  Widget _buildSalesHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Sales History'),
        const SizedBox(height: 12),
        _buildSearchField(),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(onPressed: _applyFilters, child: const Text('Apply Filters')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () {
              setState(() {
                _startDate = DateTime.now().subtract(const Duration(days:30));
                _endDate = DateTime.now();
                _searchQuery = '';
              });
              _loadSales();
            }, child: const Text('Reset')),
          ],
        ),
        const SizedBox(height: 12),
        if (_lastRestoreNotification != null) ...[
          Dismissible(
            key: ValueKey(_lastRestoreNotification!['auditId'] ?? _lastRestoreAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => setState(() => _lastRestoreNotification = null),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                children: [
                  Icon(Icons.restore, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock restored', style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Builder(builder: (ctx) {
                          final restored = (_lastRestoreNotification!['items'] as List).cast<dynamic>();
                          final preview = restored.take(3).toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...preview.map((it) {
                                final m = (it is Map) ? it : {'name': it.toString(), 'quantity': 0};
                                final name = (m['name'] ?? m['productName'] ?? m['title'] ?? 'Unknown').toString();
                                final qtyNum = (m['quantity'] ?? m['qty'] ?? m['quantitySold'] ?? 0);
                                final qty = (qtyNum is num) ? qtyNum : (double.tryParse(qtyNum.toString()) ?? 0);
                                return Text('- $name : +${qty.toString()}', style: AppTextStyles.caption);
                              }).toList(),
                              if (restored.length > 3) Text('and ${restored.length - 3} more', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => setState(() => _lastRestoreNotification = null), icon: const Icon(Icons.close)),
                ],
              ),
            ),
          ),
        ],
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: _isLoadingSales ? const Center(child: CircularProgressIndicator()) : _salesList.isEmpty ? Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No sales found for selected range', style: AppTextStyles.body2))) : ListView.separated(
            itemCount: _salesList.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, idx) {
              final s = _salesList[idx];
              final data = s['data'] as Map<String, dynamic>;
              final id = s['id'] as String;
              DateTime dateVal;
              try {
                final created = data['createdAt'];
                if (created is Timestamp) dateVal = created.toDate();
                else if (created is int) dateVal = DateTime.fromMillisecondsSinceEpoch(created);
                else dateVal = DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now();
              } catch (_) { dateVal = DateTime.now(); }
              final date = DateFormat('dd MMM yyyy, HH:mm').format(dateVal);
              final amount = ((data['finalAmount'] ?? data['totalAmount'] ?? data['total'] ?? 0) as num).toDouble();
              final customer = data['customerName'] ?? data['customerDisplayName'] ?? '';
              final pm = data['paymentMethod'] ?? data['payment'] ?? '';
              return ListTile(
                title: Text('#$id • ₦${amount.toStringAsFixed(2)}', style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('$customer • $pm\n$date', style: AppTextStyles.caption),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _updateAutoBackup(bool value) async {
    final authProvider = context.read<AuthProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final businessProvider = context.read<BusinessProvider>();
    final businessId = businessProvider.currentBusiness?.id;
    final userId = authProvider.currentUser?.id;

    if (businessId != null && userId != null) {
      await settingsProvider.updateExportSettings(
        businessId,
        userId,
        autoBackup: value,
      );
    } else {
      _showErrorSnackBar('Unable to save backup preference right now.');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show actions after an export: Open, Share, Copy path
  void _showExportActions(String filepath) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Export ready', style: AppTextStyles.heading5),
                const SizedBox(height: 8),
                Text('File saved to:', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Text(filepath, style: AppTextStyles.body2.copyWith(fontSize: 12)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open File'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _openFile(filepath);
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Share.shareXFiles([XFile(filepath)], text: 'Sales Export');
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Path'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: filepath));
                    Navigator.of(ctx).pop();
                    _showSuccessSnackBar('File path copied to clipboard');
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  child: const Text('Close'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFile(String filepath) async {
    try {
      if (kIsWeb) {
        // Opening local files is not supported on web in the same way
        _showErrorSnackBar('Opening files is not supported on Web. File saved to $filepath');
        return;
      }
      final result = await OpenFilex.open(filepath);
      // Optionally, handle result?.type or result?.message
      if (result.type == ResultType.error) {
        _showErrorSnackBar('Unable to open file: ${result.message}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open file: $e');
    }
  }
}


