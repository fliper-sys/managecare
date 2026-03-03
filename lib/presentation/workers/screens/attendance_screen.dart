import 'package:flutter/material.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/repositories/attendance_repository_impl.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/colors.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime? selectedDate;
  late AttendanceRepositoryImpl _repository;
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        AttendanceRepositoryImpl(firestore: FirebaseFirestore.instance);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (business == null || auth.currentUser == null) {
        setState(() {
          _error = 'Business or user not found';
          _isLoading = false;
        });
        return;
      }

      // Get the current user's attendance
      final records = await _repository.getAttendanceRecords(
        business.id,
        auth.currentUser!.id,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      final stats = await _repository.getAttendanceStats(
        business.id,
        auth.currentUser!.id,
      );

      setState(() {
        _records = records;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attendance: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 30)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => selectedDate = date);
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Select Date'),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attendance Summary (Last 30 Days)',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                title: const Text('Present'),
                                trailing: Text(
                                  '${_stats?['presentDays'] ?? 0} days',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              ListTile(
                                title: const Text('Absent'),
                                trailing: Text(
                                  '${_stats?['absentDays'] ?? 0} days',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              ListTile(
                                title: const Text('Late'),
                                trailing: Text(
                                  '${_stats?['lateDays'] ?? 0} days',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              ListTile(
                                title: const Text('Attendance Rate'),
                                trailing: Text(
                                  '${(_stats?['attendanceRate'] ?? 0).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_records.isEmpty)
                        const Center(child: Text('No attendance records'))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            final date = parseTimestamp(record['date']);
                            final status =
                                record['status'] as String? ?? 'absent';
                            final isPresent = status == 'present';
                            final isLate = status == 'late';

                            return ListTile(
                              title: Text(
                                '${date.day}/${date.month}/${date.year}',
                              ),
                              trailing: Chip(
                                label: Text(
                                  status.replaceFirst(
                                      status[0], status[0].toUpperCase()),
                                ),
                                backgroundColor: isPresent
                                    ? Colors.green
                                    : isLate
                                        ? Colors.orange
                                        : Colors.red,
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}

