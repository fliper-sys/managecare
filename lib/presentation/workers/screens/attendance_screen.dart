import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _timeFormat = DateFormat('h:mm a');

  String? _selectedWorkerId;
  DateTime _selectedDate = DateTime.now();

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  CollectionReference<Map<String, dynamic>>? _businessCollection(String name) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection(name);
  }

  bool _canManageAttendance(AuthProvider auth) {
    final user = auth.currentUser;
    if (auth.isOwnerUser || auth.isAdminUser) return true;
    if (user == null) return false;
    return WorkerPermissions.canAttendanceForUser(user.role, user.permissions) ||
        WorkerPermissions.canManageStaffForUser(user.role, user.permissions);
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int _timeToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _durationText(DateTime? start, DateTime? end) {
    if (start == null || end == null || end.isBefore(start)) return '-';
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  bool _isScheduledForDate(Map<String, dynamic> schedule, DateTime date) {
    final days = (schedule['daysOfWeek'] as List<dynamic>?)
            ?.map((day) => day.toString().toLowerCase())
            .toSet() ??
        const <String>{};
    final weekday = DateFormat('EEE').format(date).toLowerCase();
    if (days.isNotEmpty && !days.contains(weekday)) return false;

    final weeks = (schedule['weeksOfMonth'] as List<dynamic>?)
            ?.map((week) => (week as num?)?.toInt())
            .whereType<int>()
            .toSet() ??
        const <int>{};
    final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
    return weeks.isEmpty || weeks.contains(weekOfMonth);
  }

  String _statusFor(Map<String, dynamic>? schedule, Map<String, dynamic>? log) {
    if (log == null) return 'Absent';
    final checkIn = _asDate(log['checkInAt']);
    final checkOut = _asDate(log['checkOutAt']);
    if (checkIn == null) return 'Absent';
    if (schedule == null) return checkOut == null ? 'Checked in' : 'Present';

    final startMinutes = _timeToMinutes(schedule['startTime']?.toString() ?? '');
    final grace = (schedule['graceMinutes'] as num?)?.toInt() ?? 10;
    final actualMinutes = checkIn.hour * 60 + checkIn.minute;
    if (actualMinutes > startMinutes + grace) return 'Late';
    return checkOut == null ? 'Checked in' : 'Present';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
      case 'checked in':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _recordManualAttendance({
    required bool checkout,
  }) async {
    final auth = context.read<AuthProvider>().currentUser;
    final business = context.read<BusinessProvider>().currentBusiness;
    final logs = _businessCollection('attendance_logs');
    if (auth == null || business == null || logs == null) return;

    final query = await logs
        .where('workerId', isEqualTo: auth.id)
        .where('dateKey', isEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()))
        .limit(1)
        .get();

    if (checkout) {
      if (query.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have not checked in today')),
        );
        return;
      }
      await logs.doc(query.docs.first.id).set({
        'checkOutAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (query.docs.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already checked in today')),
      );
      return;
    }

    await logs.add({
      'businessId': business.id,
      'workerId': auth.id,
      'workerName': auth.fullName.isNotEmpty ? auth.fullName : auth.email,
      'workerEmail': auth.email,
      'dateKey': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'checkInAt': FieldValue.serverTimestamp(),
      'source': 'app_manual',
      'status': 'pending_device_verification',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _showDeviceDialog() async {
    final devices = _businessCollection('attendance_devices');
    if (devices == null) return;

    final nameController = TextEditingController(text: 'Hippoint F16');
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '4370');
    final serialController = TextEditingController();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add Attendance Device'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Device name'),
                  ),
                  TextField(
                    controller: ipController,
                    decoration: const InputDecoration(labelText: 'LAN IP address'),
                  ),
                  TextField(
                    controller: portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'TCP port'),
                  ),
                  TextField(
                    controller: serialController,
                    decoration: const InputDecoration(labelText: 'Serial number'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await devices.add({
      'name': nameController.text.trim().isEmpty
          ? 'Hippoint F16'
          : nameController.text.trim(),
      'model': 'F16',
      'ipAddress': ipController.text.trim(),
      'port': int.tryParse(portController.text.trim()) ?? 4370,
      'serialNumber': serialController.text.trim(),
      'protocol': 'zkteco_tcp_ip',
      'syncMode': 'backend_required',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _showScheduleDialog(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workers,
  ) async {
    final schedules = _businessCollection('attendance_schedules');
    if (schedules == null || workers.isEmpty) return;

    String workerId = workers.first.id;
    final startController = TextEditingController(text: '08:00');
    final endController = TextEditingController(text: '17:00');
    final deviceUserController = TextEditingController();
    final graceController = TextEditingController(text: '10');
    final selectedDays = <String>{'mon', 'tue', 'wed', 'thu', 'fri'};
    final selectedWeeks = <int>{};

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Create Worker Schedule'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: workerId,
                        decoration: const InputDecoration(labelText: 'Worker'),
                        items: workers.map((doc) {
                          final data = doc.data();
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              (data['name'] ?? data['fullName'] ?? data['email'] ?? doc.id)
                                  .toString(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => workerId = value);
                          }
                        },
                      ),
                      TextField(
                        controller: deviceUserController,
                        decoration: const InputDecoration(
                          labelText: 'Device user ID',
                          helperText: 'Must match the ID enrolled on the terminal.',
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startController,
                              decoration: const InputDecoration(
                                labelText: 'Start HH:mm',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: endController,
                              decoration: const InputDecoration(
                                labelText: 'End HH:mm',
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: graceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Late grace minutes',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Days of week'),
                      Wrap(
                        spacing: 6,
                        children: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
                            .map(
                              (day) => FilterChip(
                                label: Text(day.toUpperCase()),
                                selected: selectedDays.contains(day),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    selected
                                        ? selectedDays.add(day)
                                        : selectedDays.remove(day);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text('Weeks of month (optional)'),
                      Wrap(
                        spacing: 6,
                        children: [1, 2, 3, 4, 5]
                            .map(
                              (week) => FilterChip(
                                label: Text('Week $week'),
                                selected: selectedWeeks.contains(week),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    selected
                                        ? selectedWeeks.add(week)
                                        : selectedWeeks.remove(week);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: selectedDays.isEmpty
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (!confirmed) return;
    final worker = workers.firstWhere((doc) => doc.id == workerId).data();
    await schedules.add({
      'workerId': workerId,
      'workerName':
          (worker['name'] ?? worker['fullName'] ?? worker['email'] ?? workerId)
              .toString(),
      'deviceUserId': deviceUserController.text.trim(),
      'startTime': startController.text.trim(),
      'endTime': endController.text.trim(),
      'daysOfWeek': selectedDays.toList()..sort(),
      'weeksOfMonth': selectedWeeks.toList()..sort(),
      'graceMinutes': int.tryParse(graceController.text.trim()) ?? 10,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final business = context.watch<BusinessProvider>().currentBusiness;
    final user = auth.currentUser;
    final canManage = _canManageAttendance(auth);

    if (business == null || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: const Center(child: Text('No business or user selected')),
      );
    }

    return DefaultTabController(
      length: canManage ? 5 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          backgroundColor: AppColors.primary,
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Today'),
              const Tab(text: 'My History'),
              if (canManage) const Tab(text: 'Analytics'),
              if (canManage) const Tab(text: 'Schedules'),
              if (canManage) const Tab(text: 'Device Setup'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTodayTab(canManage: canManage, currentWorkerId: user.id),
            _buildWorkerHistory(workerId: user.id),
            if (canManage) _buildAnalyticsTab(),
            if (canManage) _buildSchedulesTab(),
            if (canManage) _buildDeviceSetupTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab({
    required bool canManage,
    required String currentWorkerId,
  }) {
    final logs = _businessCollection('attendance_logs');
    final schedules = _businessCollection('attendance_schedules');
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (logs == null || schedules == null) {
      return const Center(child: Text('No business selected'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logs
          .where('dateKey', isEqualTo: _dateKey)
          .snapshots(includeMetadataChanges: true),
      builder: (context, logSnapshot) {
        final logDocs = logSnapshot.data?.docs ?? [];
        final myLog = logDocs
            .where((doc) => doc.data()['workerId'] == currentWorkerId)
            .map((doc) => doc.data())
            .cast<Map<String, dynamic>?>()
            .firstWhere((log) => log != null, orElse: () => null);
        final checkedIn = myLog?['checkInAt'] != null;
        final checkedOut = myLog?['checkOutAt'] != null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Checked In',
                    '${logDocs.where((doc) => doc.data()['checkInAt'] != null).length}',
                    Icons.login_rounded,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    'Still On Duty',
                    '${logDocs.where((doc) => doc.data()['checkInAt'] != null && doc.data()['checkOutAt'] == null).length}',
                    Icons.timelapse_rounded,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      (checkedIn && !checkedOut ? Colors.green : Colors.grey)
                          .withOpacity(0.14),
                  child: Icon(
                    checkedIn && !checkedOut
                        ? Icons.verified_user_rounded
                        : Icons.fingerprint_rounded,
                    color: checkedIn && !checkedOut ? Colors.green : Colors.grey,
                  ),
                ),
                title: Text(
                  checkedIn
                      ? checkedOut
                          ? 'You checked out today'
                          : 'You are checked in today'
                      : 'You have not checked in today',
                ),
                subtitle: Text(
                  checkedIn
                      ? 'In: ${_timeFormat.format(_asDate(myLog?['checkInAt']) ?? DateTime.now())}'
                      : 'Use the F16 device. Manual fallback is available below.',
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        checkedIn ? null : () => _recordManualAttendance(checkout: false),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Manual Check In'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: checkedIn && !checkedOut
                        ? () => _recordManualAttendance(checkout: true)
                        : null,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Manual Check Out'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (canManage)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: schedules
                    .where('isActive', isEqualTo: true)
                    .snapshots(includeMetadataChanges: true),
                builder: (context, scheduleSnapshot) {
                  final scheduleDocs = scheduleSnapshot.data?.docs ?? [];
                  final todaySchedules = scheduleDocs
                      .where((doc) => _isScheduledForDate(doc.data(), _selectedDate))
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today Overview', style: AppTextStyles.heading5),
                      const SizedBox(height: 8),
                      if (todaySchedules.isEmpty)
                        const Card(
                          child: ListTile(
                            title: Text('No schedules for today'),
                          ),
                        )
                      else
                        ...todaySchedules.map((scheduleDoc) {
                          final schedule = scheduleDoc.data();
                          final log = logDocs
                              .where((doc) =>
                                  doc.data()['workerId'] == schedule['workerId'])
                              .map((doc) => doc.data())
                              .cast<Map<String, dynamic>?>()
                              .firstWhere((item) => item != null,
                                  orElse: () => null);
                          final status = _statusFor(schedule, log);
                          return Card(
                            child: ListTile(
                              title: Text(schedule['workerName']?.toString() ??
                                  'Worker'),
                              subtitle: Text(
                                '${schedule['startTime']} - ${schedule['endTime']}'
                                ' | Device ID: ${schedule['deviceUserId'] ?? '-'}',
                              ),
                              trailing: Chip(
                                label: Text(status),
                                backgroundColor: _statusColor(status),
                                labelStyle: const TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            Text('Live Device Punches', style: AppTextStyles.heading5),
            const SizedBox(height: 8),
            if (businessId == null || businessId.isEmpty)
              const Card(child: ListTile(title: Text('No business selected')))
            else
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('attendance_punches')
                    .where('businessId', isEqualTo: businessId)
                    .where('dateKey', isEqualTo: _dateKey)
                    .orderBy('punchTime', descending: true)
                    .limit(50)
                    .snapshots(includeMetadataChanges: true),
                builder: (context, snapshot) {
                  final punches = snapshot.data?.docs ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      punches.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (punches.isEmpty) {
                    return const Card(
                      child: ListTile(title: Text('No device punches today')),
                    );
                  }
                  return Column(
                    children: punches.map((doc) {
                      final data = doc.data();
                      final punchTime = _asDate(data['punchTime']);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              data['direction'] == 'check_out'
                                  ? Icons.logout_rounded
                                  : Icons.login_rounded,
                            ),
                          ),
                          title: Text(data['workerName']?.toString() ??
                              data['workerId']?.toString() ??
                              'Worker'),
                          subtitle: Text(
                            '${data['direction'] ?? 'punch'} | Terminal ID: ${data['terminalUserId'] ?? '-'}',
                          ),
                          trailing: Text(
                            punchTime == null ? '-' : _timeFormat.format(punchTime),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildWorkerHistory({required String workerId}) {
    final logs = _businessCollection('attendance_logs');
    if (logs == null) return const Center(child: Text('No business selected'));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logs
          .where('workerId', isEqualTo: workerId)
          .orderBy('dateKey', descending: true)
          .limit(60)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) return const Center(child: Text('No attendance yet'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final checkIn = _asDate(data['checkInAt']);
            final checkOut = _asDate(data['checkOutAt']);
            return Card(
              child: ListTile(
                title: Text(data['dateKey']?.toString() ?? ''),
                subtitle: Text(
                  'In: ${checkIn == null ? '-' : _timeFormat.format(checkIn)}'
                  ' | Out: ${checkOut == null ? '-' : _timeFormat.format(checkOut)}',
                ),
                trailing: Text(_durationText(checkIn, checkOut)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSchedulesTab() {
    final schedules = _businessCollection('attendance_schedules');
    if (schedules == null) return const Center(child: Text('No business selected'));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('workers')
          .where('businessId',
              isEqualTo: context.read<BusinessProvider>().currentBusiness?.id)
          .snapshots(includeMetadataChanges: true),
      builder: (context, workerSnapshot) {
        final workerDocs = workerSnapshot.data?.docs ?? [];
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed:
                workerDocs.isEmpty ? null : () => _showScheduleDialog(workerDocs),
            icon: const Icon(Icons.add),
            label: const Text('Schedule'),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: schedules
                .where('isActive', isEqualTo: true)
                .snapshots(includeMetadataChanges: true),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No worker schedules yet'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final days = ((data['daysOfWeek'] as List<dynamic>?) ?? [])
                      .join(', ')
                      .toUpperCase();
                  final weeks = ((data['weeksOfMonth'] as List<dynamic>?) ?? [])
                      .join(', ');
                  return Card(
                    child: ListTile(
                      title: Text(data['workerName']?.toString() ?? 'Worker'),
                      subtitle: Text(
                        '${data['startTime']} - ${data['endTime']} | $days'
                        '${weeks.isEmpty ? '' : '\nWeeks: $weeks'}'
                        '\nDevice user ID: ${data['deviceUserId'] ?? '-'}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => schedules.doc(doc.id).set(
                          {
                            'isActive': false,
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    final logs = _businessCollection('attendance_logs');
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (logs == null || businessId == null || businessId.isEmpty) {
      return const Center(child: Text('No business selected'));
    }

    final start = DateTime.now().subtract(const Duration(days: 30));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('workers')
          .where('businessId', isEqualTo: businessId)
          .snapshots(includeMetadataChanges: true),
      builder: (context, workerSnapshot) {
        final workers = workerSnapshot.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: logs
              .where('dateKey',
                  isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(start))
              .snapshots(includeMetadataChanges: true),
          builder: (context, logSnapshot) {
            final allLogs = logSnapshot.data?.docs
                    .map((doc) => doc.data())
                    .where((data) =>
                        _selectedWorkerId == null ||
                        data['workerId'] == _selectedWorkerId)
                    .toList() ??
                [];
            final workerNames = {
              for (final doc in workers)
                doc.id: (doc.data()['name'] ??
                        doc.data()['fullName'] ??
                        doc.data()['email'] ??
                        doc.id)
                    .toString(),
            };
            final checkedIn =
                allLogs.where((log) => log['checkInAt'] != null).length;
            final checkedOut =
                allLogs.where((log) => log['checkOutAt'] != null).length;
            final active = allLogs
                .where((log) =>
                    log['checkInAt'] != null && log['checkOutAt'] == null)
                .length;
            final workerTotals = <String, int>{};
            for (final log in allLogs) {
              final workerId = log['workerId']?.toString() ?? 'unknown';
              workerTotals[workerId] = (workerTotals[workerId] ?? 0) + 1;
            }
            final rankedWorkers = workerTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedWorkerId,
                  decoration: const InputDecoration(
                    labelText: 'Worker filter',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All workers'),
                    ),
                    ...workers.map(
                      (doc) => DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(workerNames[doc.id] ?? doc.id),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedWorkerId = value);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'Check-ins',
                        '$checkedIn',
                        Icons.login_rounded,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        'Check-outs',
                        '$checkedOut',
                        Icons.logout_rounded,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        'On Duty',
                        '$active',
                        Icons.timelapse_rounded,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Worker Summary', style: AppTextStyles.heading5),
                const SizedBox(height: 8),
                if (rankedWorkers.isEmpty)
                  const Card(
                    child: ListTile(title: Text('No attendance logs yet')),
                  )
                else
                  ...rankedWorkers.map(
                    (entry) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_rounded),
                        ),
                        title: Text(workerNames[entry.key] ?? entry.key),
                        subtitle: const Text('Last 30 days'),
                        trailing: Text('${entry.value} log(s)'),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceSetupTab() {
    final devices = _businessCollection('attendance_devices');
    final schedules = _businessCollection('attendance_schedules');
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (devices == null ||
        schedules == null ||
        businessId == null ||
        businessId.isEmpty) {
      return const Center(child: Text('No business selected'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: devices
          .where('isActive', isEqualTo: true)
          .snapshots(includeMetadataChanges: true),
      builder: (context, deviceSnapshot) {
        final deviceDocs = deviceSnapshot.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('workers')
              .where('businessId', isEqualTo: businessId)
              .snapshots(includeMetadataChanges: true),
          builder: (context, workerSnapshot) {
            final workerDocs = workerSnapshot.data?.docs ?? [];
            final mappedWorkers = workerDocs.where((doc) {
              final data = doc.data();
              return (data['terminalUserId']?.toString().trim().isNotEmpty ??
                      false) ||
                  (data['deviceUserId']?.toString().trim().isNotEmpty ??
                      false) ||
                  (data['attendanceDeviceUserId']
                          ?.toString()
                          .trim()
                          .isNotEmpty ??
                      false);
            }).length;
            final unmappedWorkers = workerDocs.length - mappedWorkers;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: schedules
                  .where('isActive', isEqualTo: true)
                  .snapshots(includeMetadataChanges: true),
              builder: (context, scheduleSnapshot) {
                final scheduleDocs = scheduleSnapshot.data?.docs ?? [];
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('attendance_punches')
                      .where('businessId', isEqualTo: businessId)
                      .where('dateKey', isEqualTo: _dateKey)
                      .limit(20)
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, punchSnapshot) {
                    final punchDocs = punchSnapshot.data?.docs ?? [];
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('attendance_punches_unmatched')
                          .where('businessId', isEqualTo: businessId)
                          .limit(20)
                          .snapshots(includeMetadataChanges: true),
                      builder: (context, unmatchedSnapshot) {
                        final unmatchedDocs =
                            unmatchedSnapshot.data?.docs ?? [];
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _attendanceStatusPanel(
                              devices: deviceDocs.length,
                              workers: workerDocs.length,
                              mappedWorkers: mappedWorkers,
                              unmappedWorkers: unmappedWorkers,
                              schedules: scheduleDocs.length,
                              punchesToday: punchDocs.length,
                              unmatchedPunches: unmatchedDocs.length,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _showDeviceDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add F16 Device'),
                            ),
                            const SizedBox(height: 12),
                            if (deviceDocs.isEmpty)
                              const Card(
                                child: ListTile(
                                  leading: Icon(Icons.warning_amber_rounded),
                                  title: Text('No active device registered'),
                                  subtitle: Text(
                                    'Add the Hippoint F16 serial number before the backend can accept live punches.',
                                  ),
                                ),
                              )
                            else
                              ...deviceDocs.map((doc) {
                                final data = doc.data();
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.fingerprint),
                                    ),
                                    title: Text(
                                      data['name']?.toString() ??
                                          'Hippoint F16',
                                    ),
                                    subtitle: Text(
                                      'IP: ${data['ipAddress'] ?? '-'}:${data['port'] ?? 4370}\n'
                                      'Serial: ${data['serialNumber'] ?? '-'}\n'
                                      'Endpoint: /iclock/cdata',
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              }),
                            if (unmappedWorkers > 0)
                              _guideCard(
                                title: 'Workers needing terminal IDs',
                                children: workerDocs
                                    .where((doc) {
                                      final data = doc.data();
                                      return !(data['terminalUserId']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ??
                                              false) &&
                                          !(data['deviceUserId']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ??
                                              false) &&
                                          !(data['attendanceDeviceUserId']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ??
                                              false);
                                    })
                                    .take(8)
                                    .map((doc) {
                                      final data = doc.data();
                                      final name = data['name'] ??
                                          data['fullName'] ??
                                          data['email'] ??
                                          doc.id;
                                      return '$name has no F16 terminal user ID yet.';
                                    })
                                    .toList(),
                              ),
                            _endpointGuideCard(),
                            _guideCard(
                              title: 'Device setup guide',
                              children: const [
                                '1. Plug the F16 into Ethernet/LAN and confirm it has internet access.',
                                '2. Set the terminal date/time correctly. Attendance sorting depends on the punch timestamp sent by the device.',
                                '3. Open Comm -> Cloud Server Setting on the terminal.',
                                '4. Server address: us-central1-manage-care-1e96b.cloudfunctions.net',
                                '5. Server port: 443 for the deployed HTTPS function.',
                                '6. Path/function: iclock if the firmware has a separate path field. If it asks for URL path, use /iclock.',
                                '7. Enable ADMS/cloud push mode, save, then restart or reconnect the terminal.',
                                '8. Register this device in the app with the exact serial number printed on the box/device.',
                              ],
                            ),
                            _guideCard(
                              title: 'App setup guide',
                              children: const [
                                '1. Create or confirm each worker account in the app.',
                                '2. Enroll each worker on the F16 using face/fingerprint and write down the terminal user ID.',
                                '3. Open Workers -> Edit Permissions and set Attendance terminal user ID to the same F16 user ID.',
                                '4. Open Attendance -> Schedules and create the worker schedule: start time, end time, days, optional weeks, and grace minutes.',
                                '5. Ask the worker to punch once on the F16.',
                                '6. Check Attendance -> Today -> Live Device Punches. A matched punch should show the worker name.',
                                '7. If it does not show, check the unmatched punch count here and correct the worker terminal user ID.',
                              ],
                            ),
                            _guideCard(
                              title: 'How attendance is retrieved and sorted',
                              children: const [
                                'The F16 uploads ATTLOG rows to the Firebase iclock function using ADMS push.',
                                'The backend matches the device serial number to this business and matches terminal user ID to a worker.',
                                'Every raw punch is stored in attendance_punches for audit history.',
                                'The app listens to Firestore snapshots, so Today, History, Analytics, and Device Setup update in real time.',
                                'For each worker and date, the first punch becomes check-in and the next punch becomes check-out. Additional punches alternate direction for breaks and re-entry.',
                                'Schedules are used to calculate absent, late, checked-in, and present states.',
                              ],
                            ),
                            _guideCard(
                              title: 'Troubleshooting status',
                              children: const [
                                'No device registered: add the F16 serial number exactly as printed.',
                                'Workers unmapped: enter the F16 terminal user ID on each worker profile.',
                                'No schedules: create active schedules so late and absent status can be calculated.',
                                'No punches today: confirm LAN/internet, cloud server settings, and that the function URL is reachable.',
                                'Unmatched punches: the device is sending logs, but the terminal user ID does not match any worker.',
                                'Wrong check-in time: correct the date/time on the physical terminal.',
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _attendanceStatusPanel({
    required int devices,
    required int workers,
    required int mappedWorkers,
    required int unmappedWorkers,
    required int schedules,
    required int punchesToday,
    required int unmatchedPunches,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance System Status', style: AppTextStyles.heading5),
            const SizedBox(height: 4),
            Text(
              'Use this checklist before relying on biometric attendance.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip(
                  label: devices > 0 ? 'Device registered' : 'No device',
                  ok: devices > 0,
                ),
                _statusChip(
                  label: mappedWorkers > 0
                      ? '$mappedWorkers worker IDs mapped'
                      : 'No worker IDs mapped',
                  ok: mappedWorkers > 0,
                ),
                _statusChip(
                  label: schedules > 0 ? '$schedules schedules' : 'No schedules',
                  ok: schedules > 0,
                ),
                _statusChip(
                  label: punchesToday > 0
                      ? '$punchesToday punches today'
                      : 'No punches today',
                  ok: punchesToday > 0,
                  warningOnly: true,
                ),
                _statusChip(
                  label: unmatchedPunches == 0
                      ? 'No unmatched punches'
                      : '$unmatchedPunches unmatched punches',
                  ok: unmatchedPunches == 0,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _setupMetric(
                    'Devices',
                    '$devices',
                    Icons.devices_rounded,
                    devices > 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _setupMetric(
                    'Workers',
                    '$mappedWorkers/$workers',
                    Icons.badge_rounded,
                    unmappedWorkers == 0 && workers > 0
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _setupMetric(
                    'Schedules',
                    '$schedules',
                    Icons.calendar_month_rounded,
                    schedules > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required bool ok,
    bool warningOnly = false,
  }) {
    final color = ok ? Colors.green : (warningOnly ? Colors.orange : Colors.red);
    return Chip(
      avatar: Icon(
        ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
        color: Colors.white,
        size: 18,
      ),
      label: Text(label),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }

  Widget _setupMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.heading5),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _endpointGuideCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cloud endpoint details', style: AppTextStyles.heading5),
            const SizedBox(height: 8),
            const SelectableText(
              'https://us-central1-manage-care-1e96b.cloudfunctions.net/iclock',
            ),
            const SizedBox(height: 8),
            Text(
              'Use this as the ADMS/cloud server endpoint. Some F16 firmware splits this into host, port, and path fields.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.heading4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _guideCard({
    required String title,
    required List<String> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.heading5),
            const SizedBox(height: 8),
            ...children.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
