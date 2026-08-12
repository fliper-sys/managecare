// ═══════════════════════════════════════════════════════════════════════════
// HOTEL EXPENSES SCREEN
// ═══════════════════════════════════════════════════════════════════════════
//
// Hotel-specific expenses management. Sits on top of the existing
// ReportsProvider expense API — no backend/schema changes needed. What this
// screen adds over the generic ExpenseReportScreen:
//
//   * Hospitality-relevant categories with icons (housekeeping, laundry,
//     F&B, guest amenities, utilities, maintenance, staff wages, marketing,
//     licences & permits, other)
//   * Compact hotel-tinted UI: KPI row (MTD total, this-week, transactions
//     count), category breakdown card with % of total per hospitality
//     category, chronological list with quick-delete
//   * Add-expense dialog with the hospitality category picker + optional
//     receipt URL field
//
// The generic ExpenseReportScreen is left untouched. Users navigate here
// via the hotel dashboard's "Expenses" tile (routed to Routes.hotelExpenses).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/reports_provider.dart';

class HotelExpensesScreen extends StatefulWidget {
  const HotelExpensesScreen({super.key});

  @override
  State<HotelExpensesScreen> createState() => _HotelExpensesScreenState();
}

class _HotelExpensesScreenState extends State<HotelExpensesScreen> {
  String _filterCategory = 'all';
  bool _initialLoaded = false;

  // Hospitality-relevant category set, ordered by likely frequency of use
  // in a working hotel. Each entry: id -> (display label, icon, colour).
  static const Map<String, _HotelCategory> _categories = {
    'housekeeping': _HotelCategory(
        'Housekeeping', Icons.cleaning_services_outlined, Colors.teal),
    'laundry': _HotelCategory(
        'Laundry', Icons.local_laundry_service_outlined, Colors.indigo),
    'food_and_beverage': _HotelCategory(
        'Food & beverage', Icons.restaurant_outlined, Colors.orange),
    'guest_amenities': _HotelCategory(
        'Guest amenities', Icons.spa_outlined, Colors.pink),
    'utilities': _HotelCategory(
        'Utilities', Icons.bolt_outlined, Colors.amber),
    'maintenance': _HotelCategory(
        'Maintenance & repairs', Icons.build_outlined, Colors.blueGrey),
    'staff_wages': _HotelCategory(
        'Staff wages', Icons.badge_outlined, Colors.purple),
    'marketing': _HotelCategory(
        'Marketing', Icons.campaign_outlined, Colors.deepPurple),
    'licences_permits':
        _HotelCategory('Licences & permits', Icons.gavel_outlined, Colors.brown),
    'other': _HotelCategory('Other', Icons.more_horiz, Colors.grey),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOnce());
  }

  Future<void> _loadOnce() async {
    if (_initialLoaded) return;
    final auth = context.read<AuthProvider>();
    final biz = context.read<BusinessProvider>();
    final businessId =
        biz.currentBusiness?.id ?? auth.currentUser?.businessId;
    if (businessId == null || businessId.isEmpty) return;
    try {
      await context
          .read<ReportsProvider>()
          .generateExpenseReport(businessId: businessId);
    } catch (_) {
      // Non-fatal: existing cached expenses will still render
    }
    if (mounted) setState(() => _initialLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final all = reports.expenses;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    double sumInRange(bool Function(DateTime) predicate) {
      double t = 0;
      for (final e in all) {
        final d = _dateOf(e);
        if (predicate(d)) t += _amountOf(e);
      }
      return t;
    }

    final mtdTotal = sumInRange((d) => !d.isBefore(monthStart));
    final weekTotal = sumInRange((d) => !d.isBefore(weekStart));
    final displayed = _filterCategory == 'all'
        ? all
        : all
            .where((e) =>
                (e['category']?.toString().toLowerCase() ?? '') ==
                _filterCategory)
            .toList();
    displayed.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Hotel Expenses',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _initialLoaded = false;
          await _loadOnce();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _kpiRow(mtdTotal, weekTotal, all.length),
            const SizedBox(height: 20),
            _sectionTitle('Category breakdown', 'This month\'s spending'),
            const SizedBox(height: 10),
            _categoryBreakdown(all, monthStart),
            const SizedBox(height: 20),
            _sectionTitle(
              'All expenses',
              _filterCategory == 'all'
                  ? '${all.length} record${all.length == 1 ? '' : 's'}'
                  : '${displayed.length} in ${_categories[_filterCategory]?.label ?? _filterCategory}',
            ),
            const SizedBox(height: 8),
            _filterChips(),
            const SizedBox(height: 10),
            if (displayed.isEmpty)
              _emptyList()
            else
              ...displayed.map(_expenseRow),
            const SizedBox(height: 80), // padding under FAB
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── UI pieces ─────────────────────────────

  Widget _kpiRow(double mtd, double week, int count) {
    Widget card({
      required IconData icon,
      required Color color,
      required String label,
      required String value,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          icon: Icons.calendar_month,
          color: Colors.blue,
          label: 'Month to date',
          value: formatCurrency(mtd, decimalDigits: 0),
        ),
        card(
          icon: Icons.view_week_outlined,
          color: Colors.green,
          label: 'This week',
          value: formatCurrency(week, decimalDigits: 0),
        ),
        card(
          icon: Icons.receipt_long_outlined,
          color: Colors.orange,
          label: 'Transactions',
          value: '$count',
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _categoryBreakdown(
      List<Map<String, dynamic>> all, DateTime monthStart) {
    // Aggregate MTD only
    final byCat = <String, double>{};
    double total = 0;
    for (final e in all) {
      final d = _dateOf(e);
      if (d.isBefore(monthStart)) continue;
      final cat = (e['category']?.toString().toLowerCase() ?? 'other');
      final amt = _amountOf(e);
      byCat[cat] = (byCat[cat] ?? 0) + amt;
      total += amt;
    }

    if (byCat.isEmpty || total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text('No expenses this month yet.',
              style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++)
            _categoryRow(
              key: sorted[i].key,
              amount: sorted[i].value,
              total: total,
              isLast: i == sorted.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _categoryRow({
    required String key,
    required double amount,
    required double total,
    required bool isLast,
  }) {
    final meta = _categories[key] ??
        _HotelCategory(_prettify(key), Icons.label_outline, Colors.grey);
    final pct = total == 0 ? 0.0 : (amount / total) * 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(meta.icon, color: meta.color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(meta.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Text(formatCurrency(amount, decimalDigits: 0),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 8),
              Text('${pct.toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(meta.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('all', 'All'),
          for (final e in _categories.entries) _chip(e.key, e.value.label),
        ],
      ),
    );
  }

  Widget _chip(String key, String label) {
    final selected = _filterCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterCategory = key),
        selectedColor: AppColors.primary.withOpacity(0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _expenseRow(Map<String, dynamic> e) {
    final cat = (e['category']?.toString().toLowerCase() ?? 'other');
    final meta = _categories[cat] ??
        _HotelCategory(_prettify(cat), Icons.label_outline, Colors.grey);
    final d = _dateOf(e);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: meta.color.withOpacity(0.15),
          child: Icon(meta.icon, color: meta.color, size: 18),
        ),
        title: Text(
          (e['description'] ?? 'Untitled expense').toString(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${meta.label} • ${DateFormat('d MMM y').format(d)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatCurrency(_amountOf(e), decimalDigits: 0),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade300, size: 20),
              onPressed: () => _confirmDelete(e),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyList() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No expenses recorded yet.',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text('Tap "Add Expense" to record your first one.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  // ─────────────────────────── actions ───────────────────────────────

  Future<void> _openAddExpenseDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddHotelExpenseDialog(
        categories: _categories,
        onSubmit: (description, amount, category, receiptUrl) async {
          try {
            await context.read<ReportsProvider>().addExpense(
                  description: description,
                  amount: amount,
                  category: category,
                  receiptUrl: receiptUrl,
                );
            if (!mounted) return;
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense recorded'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> e) async {
    final id = e['id']?.toString();
    if (id == null || id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
            '"${(e['description'] ?? '').toString()}" (${formatCurrency(_amountOf(e), decimalDigits: 0)}) — this cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<ReportsProvider>().removeExpense(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense removed')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Add expense dialog
// ═══════════════════════════════════════════════════════════════════════════

class _AddHotelExpenseDialog extends StatefulWidget {
  final Map<String, _HotelCategory> categories;
  final Future<void> Function(
      String description, double amount, String category, String? receiptUrl)
      onSubmit;

  const _AddHotelExpenseDialog({
    required this.categories,
    required this.onSubmit,
  });

  @override
  State<_AddHotelExpenseDialog> createState() => _AddHotelExpenseDialogState();
}

class _AddHotelExpenseDialogState extends State<_AddHotelExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();
  String _category = 'housekeeping';
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    await widget.onSubmit(
      _descCtrl.text.trim(),
      amount,
      _category,
      _receiptCtrl.text.trim().isEmpty ? null : _receiptCtrl.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.receipt_long, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Add Hotel Expense'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'e.g. Cleaning supplies for June',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₦) *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: widget.categories.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(entry.value.icon,
                                    size: 16, color: entry.value.color),
                                const SizedBox(width: 8),
                                Text(entry.value.label),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _category = v ?? 'housekeeping'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _receiptCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Receipt URL (optional)',
                    hintText: 'Paste a link to a receipt image if you have one',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? 'Saving...' : 'Add'),
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

class _HotelCategory {
  final String label;
  final IconData icon;
  final Color color;
  const _HotelCategory(this.label, this.icon, this.color);
}

DateTime _dateOf(Map<String, dynamic> expense) {
  final raw = expense['date'];
  if (raw is DateTime) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  final ts = expense['timestamp'];
  if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
  return DateTime.now();
}

double _amountOf(Map<String, dynamic> expense) {
  final v = expense['amount'];
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? 0}') ?? 0;
}

String _prettify(String key) {
  if (key.isEmpty) return 'Other';
  return key
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
      .join(' ');
}
