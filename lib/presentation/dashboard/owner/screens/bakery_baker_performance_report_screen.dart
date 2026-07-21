import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../providers/business_provider.dart';
import '../../../../presentation/inventory/utils/bakery_assignment_analytics.dart';

class BakeryBakerPerformanceReportScreen extends StatefulWidget {
  const BakeryBakerPerformanceReportScreen({super.key});

  @override
  State<BakeryBakerPerformanceReportScreen> createState() => _BakeryBakerPerformanceReportScreenState();
}

class _BakeryBakerPerformanceReportScreenState extends State<BakeryBakerPerformanceReportScreen> {
  final _searchController = TextEditingController();
  DateTimeRange? _range;
  bool _isLoading = true;
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
    if (businessId.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('bakery_resupplies')
          .orderBy('createdAt', descending: true)
          .get();

      final assignments = snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      if (!mounted) return;
      setState(() {
        _assignments = assignments.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  DateTime? _readAssignmentDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  List<Map<String, dynamic>> _filteredAssignments() {
    final searchText = _searchController.text.trim().toLowerCase();
    return _assignments.where((entry) {
      final baker = (entry['bakerName'] ?? entry['bakerId'] ?? '').toString().toLowerCase();
      final ingredient = (entry['productionItemName'] ?? entry['inventoryName'] ?? '').toString().toLowerCase();
      final notes = (entry['notes'] ?? '').toString().toLowerCase();
      final matchesSearch = searchText.isEmpty || baker.contains(searchText) || ingredient.contains(searchText) || notes.contains(searchText);

      final createdAt = _readAssignmentDate(entry['createdAt']);
      var matchesDate = true;
      if (createdAt != null && _range != null) {
        final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
        final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
        matchesDate = !createdAt.isBefore(start) && !createdAt.isAfter(end);
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  void _clearDateRange() {
    setState(() => _range = null);
  }

  Map<String, List<Map<String, dynamic>>> _groupByBaker(List<Map<String, dynamic>> assignments) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final assignment in assignments) {
      final bakerId = (assignment['bakerId'] ?? '').toString().trim();
      final bakerName = (assignment['bakerName'] ?? 'Unassigned baker').toString().trim();
      final key = bakerId.isNotEmpty ? bakerId : bakerName;
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(assignment);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final filteredAssignments = _filteredAssignments();
    final overallAnalytics = BakeryAssignmentAnalytics.summarize(filteredAssignments);
    final groupedByBaker = _groupByBaker(filteredAssignments);
    final bakerEntries = groupedByBaker.entries.toList()
      ..sort((a, b) {
        final aAnalytics = BakeryAssignmentAnalytics.summarize(a.value);
        final bAnalytics = BakeryAssignmentAnalytics.summarize(b.value);
        return bAnalytics.actualTotal.compareTo(aAnalytics.actualTotal);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Baker Performance Report'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Search baker or ingredient',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDateRange,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                _range == null
                                    ? 'Filter by date'
                                    : '${DateFormat.yMMMd().format(_range!.start)} → ${DateFormat.yMMMd().format(_range!.end)}',
                              ),
                            ),
                          ),
                          if (_range != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _clearDateRange,
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear date filter',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overall bakery trend', style: AppTextStyles.heading4),
                            const SizedBox(height: 8),
                            Text('Assignments: ${overallAnalytics.assignmentCount}'),
                            Text('Expected total: ${overallAnalytics.expectedTotal.toStringAsFixed(0)}'),
                            Text('Actual total: ${overallAnalytics.actualTotal.toStringAsFixed(0)}'),
                            Text('Variance: ${overallAnalytics.variance >= 0 ? '+' : ''}${overallAnalytics.variance.toStringAsFixed(0)}'),
                            Text('Completion rate: ${overallAnalytics.completionRate.toStringAsFixed(1)}%'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredAssignments.isEmpty
                      ? const Center(child: Text('No baker assignments found for the selected filters.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: bakerEntries.length,
                          itemBuilder: (context, index) {
                            final entry = bakerEntries[index];
                            final bakerName = entry.key.isEmpty ? 'Unassigned baker' : entry.key;
                            final bakerAssignments = entry.value;
                            final analytics = BakeryAssignmentAnalytics.summarize(bakerAssignments);
                            final dailyGroups = <String, List<Map<String, dynamic>>>{};
                            for (final assignment in bakerAssignments) {
                              final date = _readAssignmentDate(assignment['createdAt']);
                              final dayLabel = date == null ? 'Unknown date' : DateFormat.yMMMd().format(date);
                              dailyGroups.putIfAbsent(dayLabel, () => <Map<String, dynamic>>[]).add(assignment);
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            bakerName,
                                            style: AppTextStyles.subtitle1,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '${analytics.completionRate.toStringAsFixed(1)}% done',
                                            style: AppTextStyles.caption,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Expected ${analytics.expectedTotal.toStringAsFixed(0)} • Actual ${analytics.actualTotal.toStringAsFixed(0)} • Variance ${analytics.variance >= 0 ? '+' : ''}${analytics.variance.toStringAsFixed(0)}'),
                                    const SizedBox(height: 8),
                                    ...dailyGroups.entries.toList()
                                        .map((group) {
                                          final groupAssignments = group.value;
                                          final dayAnalytics = BakeryAssignmentAnalytics.summarize(groupAssignments);
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(group.key, style: AppTextStyles.body2),
                                                ),
                                                Text(
                                                  'Exp ${dayAnalytics.expectedTotal.toStringAsFixed(0)} / Act ${dayAnalytics.actualTotal.toStringAsFixed(0)}',
                                                  style: AppTextStyles.caption,
                                                ),
                                              ],
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
