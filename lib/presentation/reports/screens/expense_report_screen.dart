import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../services/web_email_receipt_service.dart';
import '../../../services/email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../core/constants/routes.dart';
import '../widgets/report_theme.dart';

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  late TextEditingController _searchController;
  late TextEditingController _categoryController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  String _filterCategory = 'all';
  String? _lastBusinessId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _categoryController = TextEditingController();
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
          authProvider.currentUser?.businessId;
      if (businessId != null && businessId.isNotEmpty) {
        final rp = context.read<ReportsProvider>();
        rp.subscribeToFinancialReports(businessId: businessId);
        rp.subscribeToExpensesReports(businessId: businessId);
        _lastBusinessId = businessId;
      }
    });
  }

  @override
  void dispose() {
    // Cancel only the financial and expenses subscriptions used by this screen
    context.read<ReportsProvider>().unsubscribeFromFinancialReports();
    context.read<ReportsProvider>().unsubscribeFromExpensesReports();
    _searchController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final currentBusinessId = businessProvider.currentBusiness?.id ??
        authProvider.currentUser?.businessId;
    if (currentBusinessId == null || currentBusinessId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Expense Reports'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No business selected',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.businessSelection),
                child: const Text('Select Business'),
              ),
            ],
          ),
        ),
      );
    }
    if (_lastBusinessId != currentBusinessId) {
      _lastBusinessId = currentBusinessId;
      if (currentBusinessId.isNotEmpty) {
        final rp = context.read<ReportsProvider>();
        rp.subscribeToFinancialReports(businessId: currentBusinessId);
        rp.subscribeToExpensesReports(businessId: currentBusinessId);
      }
    }
    return Scaffold(
      backgroundColor: context.reportBackground,
      appBar: AppBar(
        title: const Text('Expense Reports'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _showExportOptions(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddExpenseDialog(context),
          ),
        ],
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, reportsProvider, _) {
          if (reportsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = reportsProvider.getExpensesByFilter(_filterCategory);
          final searchQuery = _searchController.text.toLowerCase();
          final filteredExpenses = expenses
              .where((expense) =>
                  expense['description'].toLowerCase().contains(searchQuery))
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search expenses...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category Filter
                Text(
                  'Filter by Category',
                  style: AppTextStyles.heading5
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryFilter('all', 'All'),
                      _buildCategoryFilter('utilities', 'Utilities'),
                      _buildCategoryFilter('salaries', 'Salaries'),
                      _buildCategoryFilter('supplies', 'Supplies'),
                      _buildCategoryFilter('maintenance', 'Maintenance'),
                      _buildCategoryFilter('rent', 'Rent'),
                      _buildCategoryFilter('other', 'Other'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Expenses',
                        value: reportsProvider.getTotalExpenses(),
                        icon: Icons.trending_down,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'This Month',
                        value: reportsProvider.getMonthlyExpenses(),
                        icon: Icons.calendar_month,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Expenses List
                Text(
                  'Expense Details (${filteredExpenses.length})',
                  style: AppTextStyles.heading5
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (filteredExpenses.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 48, color: Theme.of(context).dividerColor),
                          const SizedBox(height: 16),
                          Text('No expenses found',
                              style: AppTextStyles.body2
                                  .copyWith(color: context.reportMutedText)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = filteredExpenses[index];
                      return _buildExpenseCard(expense, context);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilter(String category, String label) {
    final isSelected = _filterCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filterCategory = category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primary : context.reportChipSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.reportBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : context.reportMutedText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.reportSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.reportBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(expense['category']),
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense['description'],
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        expense['category'],
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatExpenseDate(expense['date']),
                      style: AppTextStyles.caption.copyWith(
                        color: context.reportMutedText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Receipt thumbnail (if available)
          if (expense['receiptUrl'] != null && expense['receiptUrl'].toString().isNotEmpty)
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: CachedNetworkImage(
                    imageUrl: WebEmailReceiptService().getCachedImageUrl(expense['receiptUrl'].toString()),
                    placeholder: (_, __) => const SizedBox(
                      height: 200,
                      width: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(
                      height: 200,
                      width: 200,
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.reportBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: WebEmailReceiptService().getCachedImageUrl(expense['receiptUrl'].toString()),
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₦${expense['amount']}',
                style: AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              GestureDetector(
                onTap: () => _showDeleteConfirmation(context, expense),
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.72),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'utilities':
        return Icons.bolt;
      case 'salaries':
        return Icons.person;
      case 'supplies':
        return Icons.shopping_cart;
      case 'maintenance':
        return Icons.build;
      case 'rent':
        return Icons.home;
      default:
        return Icons.receipt;
    }
  }

  void _showAddExpenseDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(),
      ),
    );
  }

  String _formatExpenseDate(dynamic raw) {
    if (raw == null) return '-';
    try {
      DateTime date;
      if (raw is Timestamp) {
        date = raw.toDate();
      } else if (raw is int) {
        date = DateTime.fromMillisecondsSinceEpoch(raw);
      } else if (raw is DateTime) {
        date = raw;
      } else {
        date = DateTime.tryParse(raw.toString()) ?? DateTime.now();
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  void _showDeleteConfirmation(
      BuildContext context, Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ReportsProvider>().removeExpense(
                    expense['id'] ?? DateTime.now().toString(),
                  );
              Navigator.pop(context);
              setState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Expense deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export Expense Report As',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final csvContent = await context
                      .read<ReportsProvider>()
                      .exportExpenseReportToCSV();
                  final directory = await getApplicationDocumentsDirectory();
                  final fileName =
                      'Expense_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
                  final filePath = '${directory.path}/$fileName';
                  final file = File(filePath);
                  await file.writeAsString(csvContent);

                  await Share.shareXFiles([XFile(file.path)],
                      text: 'Expense Report');

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Expense report exported as CSV and shared')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to export: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('PDF'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final pdfContent = await context
                      .read<ReportsProvider>()
                      .exportExpenseReportToPDF();
                  final directory = await getApplicationDocumentsDirectory();
                  final fileName =
                      'Expense_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
                  final filePath = '${directory.path}/$fileName';
                  final file = File(filePath);
                  await file.writeAsString(pdfContent);

                  await Share.shareXFiles([XFile(file.path)],
                      text: 'Expense Report');

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Expense report exported as PDF and shared')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to export: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body2.copyWith(
                    color: context.reportMutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading4.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Add Expense Screen - Full featured screen for adding expenses
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  int _tabIndex = 0; // 0: Single, 1: Multiple, 2: Receipt
  final List<ExpenseEntry> _entries = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingReceipt = false;
  late TextEditingController _receiptAmountController;
  late TextEditingController _receiptDescriptionController;
  
  // Consistent image upload pattern properties
  Uint8List? _pendingReceiptBytes;
  String? _pendingReceiptFilename;
  String? _receiptUploadErrorMessage;
  String? _uploadedReceiptUrl;
  XFile? _receiptImage;

  static const List<String> _categories = [
    'utilities',
    'salaries',
    'supplies',
    'maintenance',
    'rent',
    'procurement',
    'salary',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _receiptAmountController = TextEditingController();
    _receiptDescriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _receiptAmountController.dispose();
    _receiptDescriptionController.dispose();
    super.dispose();
  }

  /// Pick receipt image using same method as profile image upload
  Future<void> _pickAndUploadReceiptImage() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (xfile == null) return;
      
      final bytes = await xfile.readAsBytes();
      final filename = xfile.name;

      // Optimistic UI update (before upload)
      setState(() {
        _isUploadingReceipt = true;
        _pendingReceiptBytes = bytes;
        _pendingReceiptFilename = filename;
        _receiptUploadErrorMessage = null;
      });

      // Upload using EmailService (same as profile)
      debugPrint('[AddExpense] Uploading receipt via EmailService.uploadBytes');
      final url = await EmailService().uploadBytes(bytes, filename);

      setState(() => _isUploadingReceipt = false);

      if (url == null) {
        setState(() => _receiptUploadErrorMessage = 'Upload failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Receipt upload failed'),
              backgroundColor: AppColors.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _retryReceiptUpload,
                textColor: Colors.white,
              ),
            ),
          );
        }
        return;
      }

      // Cache bust URL with timestamp (same as profile)
      final cachebustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      // Clear any existing caches
      await _evictAndRemoveCache(url);

      setState(() {
        _uploadedReceiptUrl = cachebustedUrl;
        _receiptImage = xfile;
        _receiptUploadErrorMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingReceipt = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading receipt: $e'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _retryReceiptUpload,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  /// Retry receipt upload using cached bytes (same as profile retry)
  Future<void> _retryReceiptUpload() async {
    if (_pendingReceiptBytes == null || _pendingReceiptBytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cached receipt to retry')),
        );
      }
      return;
    }

    if (_isUploadingReceipt) return;

    setState(() {
      _isUploadingReceipt = true;
      _receiptUploadErrorMessage = null;
    });

    final filename = _pendingReceiptFilename ?? 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final email = EmailService();
      String? photoUrl;
      try {
        photoUrl = await email.uploadBytes(_pendingReceiptBytes!, filename);
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString();
        setState(() {
          _receiptUploadErrorMessage = msg;
          _isUploadingReceipt = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _retryReceiptUpload,
                textColor: Colors.white,
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      if (photoUrl == null) {
        setState(() => _receiptUploadErrorMessage = 'Upload failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Receipt upload failed'),
              backgroundColor: AppColors.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _retryReceiptUpload,
                textColor: Colors.white,
              ),
            ),
          );
        }
        return;
      }

      final cachebustedUrl = '$photoUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;

      setState(() {
        _uploadedReceiptUrl = cachebustedUrl;
        _isUploadingReceipt = false;
        _receiptUploadErrorMessage = null;
      });

      // Clear cache
      await _evictAndRemoveCache(photoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingReceipt = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _retryReceiptUpload,
            ),
          ),
        );
      }
    }
  }


  /// Clear image cache (same pattern as profile)
  Future<void> _evictAndRemoveCache(String? url) async {
    if (url == null) return;
    try {
      imageCache.evict(NetworkImage(url));
      await DefaultCacheManager().removeFile(url);
    } catch (e) {
      debugPrint('[AddExpense] Cache eviction error: $e');
    }
  }
  

  Future<void> _pickReceiptImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _receiptImage = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _addSingleExpense(String description, double amount, String category) {
    if (description.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    context.read<ReportsProvider>().addExpense(
          description: description,
          amount: amount,
          category: category,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addMultipleExpenses() {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one expense')),
      );
      return;
    }

    int count = 0;
    for (var entry in _entries) {
      if (entry.description.isNotEmpty && entry.amount > 0) {
        context.read<ReportsProvider>().addExpense(
              description: entry.description,
              amount: entry.amount,
              category: entry.category,
            );
        count++;
      }
    }

    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count expenses added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid expenses to add')),
      );
    }
  }

  Future<void> _addReceiptExpense() async {
    if (_receiptDescriptionController.text.isEmpty ||
        double.tryParse(_receiptAmountController.text) == null ||
        _uploadedReceiptUrl == null || _uploadedReceiptUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and upload receipt')),
      );
      return;
    }

    try {
      // Use the pre-uploaded URL (uploaded via _pickAndUploadReceiptImage)
      await context.read<ReportsProvider>().addExpense(
            description: _receiptDescriptionController.text,
            amount: double.parse(_receiptAmountController.text),
            category: 'procurement', // Receipt uploads are typically procurement
            receiptUrl: _uploadedReceiptUrl!,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt expense added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Clear form
      _receiptAmountController.clear();
      _receiptDescriptionController.clear();
      setState(() {
        _uploadedReceiptUrl = null;
        _receiptImage = null;
        _pendingReceiptBytes = null;
        _pendingReceiptFilename = null;
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save receipt expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expenses'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Tab Selector
          Container(
            color: AppColors.primary.withOpacity(0.1),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('Single Entry', 0),
                  _buildTab('Multiple Entries', 1),
                  _buildTab('Receipt Upload', 2),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : context.reportMutedText,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 0:
        return _buildSingleEntryForm();
      case 1:
        return _buildMultipleEntriesForm();
      case 2:
        return _buildReceiptUploadForm();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSingleEntryForm() {
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'utilities';

    return StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          TextField(
            controller: descriptionCtrl,
            decoration: InputDecoration(
              labelText: 'Description *',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'e.g., Office supplies',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (₦) *',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixText: '₦ ',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedCategory,
            items: _categories
                .map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat[0].toUpperCase() + cat.substring(1)),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => selectedCategory = value ?? 'utilities');
            },
            decoration: InputDecoration(
              labelText: 'Category',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _addSingleExpense(descriptionCtrl.text,
                    double.tryParse(amountCtrl.text) ?? 0, selectedCategory);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Add Expense'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleEntriesForm() {
    return Column(
      children: [
        // Display existing entries
        if (_entries.isNotEmpty) ...[
          Text('Added Expenses (${_entries.length})',
              style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          ...List.generate(_entries.length, (index) {
            final entry = _entries[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(entry.description),
                subtitle: Text(entry.category),
                trailing: SizedBox(
                  width: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('₦${entry.amount.toStringAsFixed(2)}'),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () {
                          setState(() => _entries.removeAt(index));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          const Divider(color: AppColors.primary),
          const SizedBox(height: 16),
        ],
        // Add new entry form
        const Text('Add New Expense Entry', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        _buildExpenseEntryForm(),
      ],
    );
  }

  Widget _buildExpenseEntryForm() {
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'utilities';

    return StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          TextField(
            controller: descriptionCtrl,
            decoration: InputDecoration(
              labelText: 'Description *',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'e.g., Office supplies',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (₦) *',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixText: '₦ ',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedCategory,
            items: _categories
                .map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat[0].toUpperCase() + cat.substring(1)),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => selectedCategory = value ?? 'utilities');
            },
            decoration: InputDecoration(
              labelText: 'Category',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    descriptionCtrl.clear();
                    amountCtrl.clear();
                    setState(() => selectedCategory = 'utilities');
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final desc = descriptionCtrl.text;
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (desc.isNotEmpty && amount > 0) {
                      setState(() {
                        _entries.add(ExpenseEntry(
                          description: desc,
                          amount: amount,
                          category: selectedCategory,
                        ));
                        descriptionCtrl.clear();
                        amountCtrl.clear();
                        selectedCategory = 'utilities';
                      });
                    }
                  },
                  child: const Text('Add to List'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_entries.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addMultipleExpenses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Save All (${_entries.length} items)'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReceiptUploadForm() {
    return Column(
      children: [
        // Receipt Image Preview with cache busting
        if (_uploadedReceiptUrl != null)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: _uploadedReceiptUrl!,
                fit: BoxFit.cover,
                height: 200,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: AppColors.primary.withOpacity(0.1),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.error.withOpacity(0.1),
                  child: const Center(child: Icon(Icons.error)),
                ),
              ),
            ),
          ),
        // Upload Receipt Button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: _uploadedReceiptUrl != null ? AppColors.success : AppColors.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.primary.withOpacity(0.05),
          ),
          child: Column(
            children: [
              Icon(
                _uploadedReceiptUrl != null ? Icons.check_circle : Icons.camera_alt,
                size: 48,
                color: _uploadedReceiptUrl != null ? AppColors.success : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                _uploadedReceiptUrl != null ? 'Receipt Uploaded' : 'Upload Receipt Photo',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _uploadedReceiptUrl != null
                    ? 'Ready to save expense'
                    : 'Tap to select or take receipt photo',
                style: TextStyle(color: context.reportMutedText, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (_receiptUploadErrorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _receiptUploadErrorMessage!,
                          style: TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _isUploadingReceipt ? null : _pickAndUploadReceiptImage,
                icon: _isUploadingReceipt
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.photo_library),
                label: Text(_isUploadingReceipt ? 'Uploading...' : 'Select Receipt Image'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Expense Details
        TextField(
          controller: _receiptDescriptionController,
          decoration: InputDecoration(
            labelText: 'Expense Description *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'e.g., Groceries for office',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _receiptAmountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Total Amount (₦) *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixText: '₦ ',
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUploadingReceipt ? null : _addReceiptExpense,
            style: ElevatedButton.styleFrom(
              backgroundColor: _uploadedReceiptUrl != null ? AppColors.success : AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_uploadedReceiptUrl != null ? Icons.check : Icons.save, color: Colors.white),
                const SizedBox(width: 8),
                Text(_uploadedReceiptUrl != null ? 'Save Receipt Expense' : 'Upload Receipt First'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Model for storing expense entries
class ExpenseEntry {
  final String description;
  final double amount;
  final String category;

  ExpenseEntry({
    required this.description,
    required this.amount,
    required this.category,
  });
}
