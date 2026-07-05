import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/zkteco_lan_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const String _admsFirebaseHost =
      'us-central1-manage-care-1e96b.cloudfunctions.net';
  static const String _admsFirebasePath = 'iclock';
  static const int _admsFirebasePort = 443;
  static const String _zkStoredServerName = 'www.fkweb.com';
  static const String _zkDefaultRelayIp = '';
  static const int _zkDefaultRelayPort = 7005;
  static const int _zkEthernetPort = 5005;

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

  void _lanDebugLog(String message) {
    debugPrint('[AttendanceLAN] $message');
  }

  String? _normalizeIpv4Address(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final parts = trimmed.split('.');
    if (parts.length != 4) return null;

    final octets = <int>[];
    for (final part in parts) {
      if (part.isEmpty) return null;
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) return null;
      octets.add(octet);
    }

    return octets.join('.');
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

  Future<void> _showDeviceDialog([
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  ]) async {
    final devices = _businessCollection('attendance_devices');
    if (devices == null) return;

    final existingData = existing?.data();

    final nameController = TextEditingController(
        text: existingData?['name']?.toString() ?? 'ZKTeco / Hippoint F16');
    final ipController =
        TextEditingController(text: existingData?['ipAddress']?.toString() ?? '');
    final ethernetPortController = TextEditingController(
        text: (existingData?['ethernetPort'] ?? existingData?['port'] ?? _zkEthernetPort)
            .toString());
    final serverIpController = TextEditingController(
        text: existingData?['serverIp']?.toString() ?? _zkDefaultRelayIp);
    final serverPortController = TextEditingController(
        text: (existingData?['serverPort'] ?? _zkDefaultRelayPort).toString());
    final serialController =
        TextEditingController(text: existingData?['serialNumber']?.toString() ?? '');

    final title = existing == null ? 'Add ZKTeco Device' : 'Edit ZKTeco Device';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
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
                    decoration: const InputDecoration(
                      labelText: 'Device LAN IP address',
                      helperText:
                          'Use the IP Address shown under Ethernet/WiFi on the terminal.',
                    ),
                  ),
                  TextField(
                    controller: ethernetPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ethernet Port No',
                      helperText: 'The screen photo shows 5005.',
                    ),
                  ),
                  TextField(
                    controller: serverIpController,
                    decoration: const InputDecoration(
                      labelText: 'Server IP',
                      helperText:
                          'Enter the public IP of the ADMS relay/server.',
                    ),
                  ),
                  TextField(
                    controller: serverPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'SerPortNo',
                      helperText: 'The screen photo shows 7005.',
                    ),
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

    final normalizedIp = _normalizeIpv4Address(ipController.text);
    if (normalizedIp == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid terminal LAN IP address, for example 192.168.0.100.',
          ),
        ),
      );
      return;
    }

    final payload = {
      'name': nameController.text.trim().isEmpty
          ? 'ZKTeco / Hippoint F16'
          : nameController.text.trim(),
      'model': 'F16',
      'ipAddress': normalizedIp,
      'port': int.tryParse(ethernetPortController.text.trim()) ?? _zkEthernetPort,
      'ethernetPort': int.tryParse(ethernetPortController.text.trim()) ??
          _zkEthernetPort,
      'serverIp': serverIpController.text.trim(),
      'serverName': _zkStoredServerName,
      'serverPort': int.tryParse(serverPortController.text.trim()) ??
          _zkDefaultRelayPort,
      'serialNumber': serialController.text.trim(),
      'dnsEnabled': true,
      'serverRequestEnabled': true,
      'protocol': 'zkteco_adms',
      'syncMode': 'adms_push',
      'firebaseAdmsHost': _admsFirebaseHost,
      'firebaseAdmsPort': _admsFirebasePort,
      'firebaseAdmsPath': _admsFirebasePath,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existing == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      await devices.add(payload);
    } else {
      await devices.doc(existing.id).set(payload, SetOptions(merge: true));
    }
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

  String _workerDisplayName(Map<String, dynamic> data, String fallback) {
    return (data['name'] ??
            data['fullName'] ??
            data['displayName'] ??
            data['email'] ??
            fallback)
        .toString();
  }

  String _workerTerminalId(Map<String, dynamic> data) {
    return (data['terminalUserId'] ??
            data['deviceUserId'] ??
            data['attendanceDeviceUserId'] ??
            '')
        .toString()
        .trim();
  }

  Future<void> _showWorkerTerminalIdDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> worker,
  ) async {
    final data = worker.data();
    final name = _workerDisplayName(data, worker.id);
    final terminalIdController =
        TextEditingController(text: _workerTerminalId(data));

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Edit terminal ID'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.heading5),
                const SizedBox(height: 8),
                Text(
                  'Use the ID shown on the device after enrolling or browsing this user.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: terminalIdController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Device terminal ID',
                    hintText: 'Example: 1',
                    prefixIcon: Icon(Icons.badge_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    final terminalId = terminalIdController.text.trim();
    await FirebaseFirestore.instance.collection('workers').doc(worker.id).set({
      'terminalUserId': terminalId,
      'deviceUserId': terminalId,
      'attendanceDeviceUserId': terminalId,
      'attendanceDeviceUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          terminalId.isEmpty
              ? 'Terminal ID cleared for $name'
              : 'Terminal ID $terminalId saved for $name',
        ),
      ),
    );
  }

  String _deviceLanIp(Map<String, dynamic> data) {
    final rawValue = (data['ipAddress'] ?? '').toString().trim();
    final value = _normalizeIpv4Address(rawValue) ?? rawValue;
    _lanDebugLog('resolved device LAN IP="$value"');
    return value;
  }

  int _deviceLanPort(Map<String, dynamic> data) {
    final value = data['ethernetPort'] ?? data['port'] ?? _zkEthernetPort;
    final port = value is num
        ? value.toInt()
        : int.tryParse(value.toString()) ?? _zkEthernetPort;
    _lanDebugLog('resolved device LAN port=$port raw="$value"');
    return port;
  }

  String? _devicePassword(Map<String, dynamic> data) {
    final value = (data['password'] ?? data['commPassword'] ?? '').toString().trim();
    _lanDebugLog('resolved device passwordSet=${value.isNotEmpty}');
    return value.isEmpty ? null : value;
  }

  Future<T?> _runLanOperation<T>(
    String label,
    Future<T> Function() action,
  ) async {
    _lanDebugLog('operation start "$label"');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );

    try {
      final result = await action();
      _lanDebugLog('operation success "$label" resultType=${result.runtimeType}');
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return result;
    } catch (error) {
      _lanDebugLog('operation failed "$label" error=$error');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('LAN operation failed: $error')),
        );
      }
      return null;
    }
  }

  Future<void> _testLanConnection(Map<String, dynamic> device) async {
    _lanDebugLog(
      'Test LAN tapped name=${device['name'] ?? '-'} serial=${device['serialNumber'] ?? '-'} serverIp=${device['serverIp'] ?? '-'}',
    );
    final ip = _deviceLanIp(device);
    final port = _deviceLanPort(device);
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the terminal LAN IP from Ethernet/WiFi settings. Do not use Server IP for LAN tools.',
          ),
        ),
      );
      return;
    }

    final result = await _runLanOperation(
      'Testing LAN connection...',
      () => ZktecoLanService().testConnection(
        ipAddress: ip,
        port: port,
        password: _devicePassword(device),
      ),
    );
    if (!mounted || result == null) return;
    _lanDebugLog(
      'Test LAN result connected=${result.connected} message="${result.message}" serial=${result.serialNumber ?? '-'}',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.connected ? 'Device connected' : 'Connection failed'),
        content: Text(
          [
            result.message,
            if (!result.connected)
              'Use the terminal IP Address from Network -> Ethernet/WiFi, not the Server IP.',
            if (!result.connected)
              'The phone/computer running this app must be on the same LAN as the terminal.',
            if (!result.connected)
              'Try Port No 5005 first. If the device was changed, edit the saved device port.',
            if (result.serialNumber?.isNotEmpty ?? false)
              'Serial: ${result.serialNumber}',
            if (result.deviceName?.isNotEmpty ?? false)
              'Name: ${result.deviceName}',
            if (result.os?.isNotEmpty ?? false) 'OS: ${result.os}',
            if (result.version?.isNotEmpty ?? false)
              'Version: ${result.version}',
            if (result.deviceTime != null) 'Time: ${result.deviceTime}',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pullLanUsers(
    Map<String, dynamic> device,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workers,
  ) async {
    _lanDebugLog(
      'Pull users tapped name=${device['name'] ?? '-'} serial=${device['serialNumber'] ?? '-'}',
    );
    final ip = _deviceLanIp(device);
    final port = _deviceLanPort(device);
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the terminal LAN IP from Ethernet/WiFi settings before pulling users.',
          ),
        ),
      );
      return;
    }

    final users = await _runLanOperation(
      'Pulling terminal users...',
      () => ZktecoLanService().getUsers(
        ipAddress: ip,
        port: port,
        password: _devicePassword(device),
      ),
    );
    if (!mounted || users == null) return;
    _lanDebugLog('Pull users returned count=${users.length}');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terminal users (${users.length})'),
        content: SizedBox(
          width: 520,
          child: users.isEmpty
              ? const Text('No users returned from the terminal.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_rounded),
                      ),
                      title: Text(user.name.isEmpty ? 'Unnamed user' : user.name),
                      subtitle: Text(
                        'ID: ${user.userId}${user.uid == null ? '' : ' | UID: ${user.uid}'} | ${user.role}',
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showMapTerminalUserDialog(user, workers);
                        },
                        child: const Text('Map'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMapTerminalUserDialog(
    ZktecoLanUser terminalUser,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workers,
  ) async {
    _lanDebugLog(
      'Map terminal user requested terminalUserId=${terminalUser.userId} terminalName=${terminalUser.name}',
    );
    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create workers before mapping IDs.')),
      );
      return;
    }

    var selectedWorkerId = workers.first.id;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Map terminal user'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${terminalUser.name.isEmpty ? 'Terminal user' : terminalUser.name} | ID ${terminalUser.userId}',
                    style: AppTextStyles.heading5,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedWorkerId,
                    decoration: const InputDecoration(
                      labelText: 'App worker',
                      border: OutlineInputBorder(),
                    ),
                    items: workers.map((worker) {
                      final data = worker.data();
                      return DropdownMenuItem(
                        value: worker.id,
                        child: Text(_workerDisplayName(data, worker.id)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedWorkerId = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Map ID'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;

    final worker =
        workers.firstWhere((worker) => worker.id == selectedWorkerId);
    await FirebaseFirestore.instance.collection('workers').doc(worker.id).set({
      'terminalUserId': terminalUser.userId,
      'deviceUserId': terminalUser.userId,
      'attendanceDeviceUserId': terminalUser.userId,
      'attendanceDeviceUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    _lanDebugLog(
      'Mapped terminalUserId=${terminalUser.userId} to workerId=${worker.id}',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Mapped terminal ID ${terminalUser.userId} to ${_workerDisplayName(worker.data(), worker.id)}',
        ),
      ),
    );
  }

  Future<void> _pullLanAttendanceLogs(Map<String, dynamic> device) async {
    _lanDebugLog(
      'Pull logs tapped name=${device['name'] ?? '-'} serial=${device['serialNumber'] ?? '-'}',
    );
    final ip = _deviceLanIp(device);
    final port = _deviceLanPort(device);
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the terminal LAN IP from Ethernet/WiFi settings before pulling logs.',
          ),
        ),
      );
      return;
    }

    final logs = await _runLanOperation(
      'Pulling attendance logs...',
      () => ZktecoLanService().getAttendanceLogs(
        ipAddress: ip,
        port: port,
        password: _devicePassword(device),
      ),
    );
    if (!mounted || logs == null) return;
    _lanDebugLog('Pull logs returned count=${logs.length}');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('LAN logs (${logs.length})'),
        content: SizedBox(
          width: 520,
          child: logs.isEmpty
              ? const Text('No attendance logs returned from the terminal.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.take(50).length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text('Terminal ID: ${log.userId}'),
                      subtitle: Text(
                        '${log.timestamp ?? 'No timestamp'}'
                        '${log.state == null ? '' : ' | State: ${log.state}'}'
                        '${log.type == null ? '' : ' | Type: ${log.type}'}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
                            _deviceSetupHero(
                              devices: deviceDocs.length,
                              mappedWorkers: mappedWorkers,
                              workers: workerDocs.length,
                            ),
                            const SizedBox(height: 12),
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
                                final scheme = Theme.of(context).colorScheme;
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const CircleAvatar(
                                          child: Icon(Icons.fingerprint),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['name']?.toString() ??
                                                    'Hippoint F16',
                                                style: AppTextStyles.heading5
                                                    .copyWith(
                                                  color: scheme.onSurface,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Ethernet: ${data['ipAddress'] ?? '-'}:${data['ethernetPort'] ?? data['port'] ?? _zkEthernetPort}\n'
                                                'ADMS: ${data['serverIp'] ?? data['serverHost'] ?? '-'}:${data['serverPort'] ?? _zkDefaultRelayPort}\n'
                                                'Stored name: ${data['serverName'] ?? _zkStoredServerName}\n'
                                                'Serial: ${data['serialNumber'] ?? '-'}\n'
                                                'Firebase test: $_admsFirebaseHost:$_admsFirebasePort/$_admsFirebasePath',
                                                style: _setupBodyStyle(context),
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _testLanConnection(data),
                                                    icon: const Icon(
                                                      Icons.cable_rounded,
                                                    ),
                                                    label: const Text('Test LAN'),
                                                  ),
                                                  OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _pullLanUsers(
                                                      data,
                                                      workerDocs,
                                                    ),
                                                    icon: const Icon(
                                                      Icons.people_alt_rounded,
                                                    ),
                                                    label: const Text('Pull users'),
                                                  ),
                                                  OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _pullLanAttendanceLogs(
                                                      data,
                                                    ),
                                                    icon: const Icon(
                                                      Icons.history_rounded,
                                                    ),
                                                    label: const Text('Pull logs'),
                                                  ),
                                                      OutlinedButton.icon(
                                                        onPressed: () =>
                                                            _showDeviceDialog(doc),
                                                        icon: const Icon(
                                                          Icons.edit_rounded,
                                                        ),
                                                        label: const Text('Edit'),
                                                      ),
                                                      OutlinedButton.icon(
                                                        onPressed: () async {
                                                          final confirmed =
                                                              await showDialog<bool>(
                                                                    context: context,
                                                                    builder:
                                                                        (context) => AlertDialog(
                                                                              title:
                                                                                  const Text('Deactivate device'),
                                                                              content: const Text('Are you sure you want to deactivate this device? This will stop it from accepting punches.'),
                                                                              actions: [
                                                                                TextButton(
                                                                                  onPressed: () => Navigator.pop(context, false),
                                                                                  child: const Text('Cancel'),
                                                                                ),
                                                                                ElevatedButton(
                                                                                  onPressed: () => Navigator.pop(context, true),
                                                                                  child: const Text('Deactivate'),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                  ) ??
                                                                  false;
                                                          if (!confirmed) return;
                                                          final devicesColl =
                                                              _businessCollection('attendance_devices');
                                                          if (devicesColl == null) return;
                                                          await devicesColl.doc(doc.id).set({
                                                            'isActive': false,
                                                            'updatedAt': FieldValue.serverTimestamp(),
                                                          }, SetOptions(merge: true));
                                                          if (!mounted) return;
                                                          ScaffoldMessenger.of(context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Device deactivated'),
                                                            ),
                                                          );
                                                        },
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                        ),
                                                        label: const Text('Deactivate'),
                                                      ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            _workerTerminalIdSection(workerDocs),
                            _endpointGuideCard(),
                            _packageStrategyCard(),
                            _manualGuideSection(),
                            _guideCard(
                              title: 'Device setup guide',
                              children: const [
                                '1. Plug the F16 into Ethernet/LAN and confirm it has internet access.',
                                '2. Set the terminal date/time correctly. Attendance sorting depends on the punch timestamp sent by the device.',
                                '3. Open DevSet -> Set COMM -> Network.',
                                '4. Ethernet: keep DHCP as needed for your LAN, set IP/subnet/gateway, and confirm Port No is 5005.',
                                '5. Network: set Server Req to Yes, then open Server Set.',
                                '6. The stored Server Name on this unit is www.fkweb.com. Leave it as-is if the terminal does not allow editing it.',
                                '7. Enter the public Server IP of the ADMS relay/server and set SerPortNo to 7005. The relay should forward ADMS HTTP requests to the Firebase iclock function.',
                                '8. Save, restart or reconnect the terminal, then register this device in the app with the exact serial number printed on the box/device.',
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

  Widget _deviceSetupHero({
    required int devices,
    required int mappedWorkers,
    required int workers,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primary.withOpacity(
            Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.10,
          ),
          scheme.surface,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withOpacity(0.25)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZKTeco Device Setup',
                style: AppTextStyles.heading4.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Configure ADMS live sync, LAN tools, worker IDs, and the physical terminal manual in one place.',
                style: _setupBodyStyle(context),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroPill(Icons.devices_rounded, '$devices device(s)'),
                  _heroPill(
                    Icons.badge_rounded,
                    '$mappedWorkers/$workers IDs mapped',
                  ),
                  _heroPill(Icons.cloud_done_rounded, 'ADMS + LAN ready'),
                ],
              ),
            ],
          );

          final button = ElevatedButton.icon(
            onPressed: _showDeviceDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add ZKTeco Device'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 14),
                button,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 16),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(color: scheme.onSurface),
          ),
        ],
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

  Color _panelColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      scheme.primary.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.05 : 0.02,
      ),
      scheme.surface,
    );
  }

  TextStyle _setupTitleStyle(BuildContext context) {
    return AppTextStyles.heading5.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );
  }

  TextStyle _setupBodyStyle(BuildContext context) {
    return AppTextStyles.caption.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72),
      height: 1.45,
    );
  }

  Widget _setupPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.18)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSurface),
        child: child,
      ),
    );
  }

  Widget _setupHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _setupTitleStyle(context)),
              const SizedBox(height: 2),
              Text(subtitle, style: _setupBodyStyle(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _workerTerminalIdSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workers,
  ) {
    final mapped = workers
        .where((doc) => _workerTerminalId(doc.data()).isNotEmpty)
        .length;
    return _setupPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _setupHeader(
            icon: Icons.badge_rounded,
            title: 'Worker terminal IDs',
            subtitle:
                '$mapped of ${workers.length} workers mapped. Tap a worker card to add or edit the device ID.',
          ),
          const SizedBox(height: 14),
          if (workers.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.people_outline_rounded),
              title: Text('No workers yet'),
              subtitle: Text('Create worker accounts before mapping device IDs.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 640;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: workers
                      .map(
                        (doc) => SizedBox(
                          width: twoColumns
                              ? (constraints.maxWidth - 10) / 2
                              : constraints.maxWidth,
                          child: _workerTerminalIdCard(doc),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _workerTerminalIdCard(
    QueryDocumentSnapshot<Map<String, dynamic>> worker,
  ) {
    final data = worker.data();
    final name = _workerDisplayName(data, worker.id);
    final email = (data['email'] ?? '').toString();
    final role = (data['role'] ?? 'worker').toString();
    final terminalId = _workerTerminalId(data);
    final isMapped = terminalId.isNotEmpty;
    final color = isMapped ? Colors.green : Colors.deepOrange;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Color.alphaBlend(color.withOpacity(0.08), scheme.surface),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showWorkerTerminalIdDialog(worker),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.32)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.16),
                child: Icon(
                  isMapped ? Icons.fingerprint_rounded : Icons.edit_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email.isEmpty ? role : '$role | $email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _setupBodyStyle(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isMapped ? 'Device ID: $terminalId' : 'No device ID set',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _endpointGuideCard() {
    return _setupPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _setupHeader(
              icon: Icons.cloud_done_rounded,
              title: 'Cloud endpoint details',
              subtitle:
                  'The physical device uses Server IP and SerPortNo; the relay forwards traffic to Firebase.',
              color: Colors.teal,
            ),
            const SizedBox(height: 12),
            SelectableText(
              'https://us-central1-manage-care-1e96b.cloudfunctions.net/iclock',
              style: AppTextStyles.monospace.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This unit stores Server Name as $_zkStoredServerName, but testing should use the editable Server IP and SerPortNo fields. Point Server IP at an IP-based ADMS relay on port $_zkDefaultRelayPort. The relay should forward /iclock/cdata and /iclock/getrequest traffic to https://$_admsFirebaseHost/$_admsFirebasePath.',
              style: _setupBodyStyle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packageStrategyCard() {
    return _setupPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _setupHeader(
              icon: Icons.hub_rounded,
              title: 'Connection strategy',
              subtitle:
                  'ADMS handles live sync; LAN tools are for local admin checks.',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              'Use ADMS push for production attendance. Use flutter_zkteco LAN tools from Android/Windows/native builds to test connection, pull terminal users, and pull logs when this app is on the same network as the device. Flutter web cannot open raw TCP sockets to the terminal.',
              style: _setupBodyStyle(context),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(
                  avatar: Icon(Icons.cloud_done_rounded, size: 18),
                  label: Text('ADMS live sync'),
                ),
                Chip(
                  avatar: Icon(Icons.router_rounded, size: 18),
                  label: Text('LAN admin tools'),
                ),
                Chip(
                  avatar: Icon(Icons.badge_rounded, size: 18),
                  label: Text('Worker ID mapping'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualGuideSection() {
    return _setupPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _setupHeader(
            icon: Icons.menu_book_rounded,
            title: 'Device manual notes',
            subtitle:
                'Quick reference from the fingerprint and facial time attendance guide.',
            color: Colors.indigo,
          ),
          const SizedBox(height: 14),
          _manualInfoTile(
            icon: Icons.keyboard_alt_rounded,
            title: 'Keypad',
            text:
                'MENU opens settings, OK confirms, ESC exits, up/down moves through options, and 0 changes input method while editing.',
          ),
          _manualInfoTile(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Add a user',
            text:
                'MENU -> User -> Enroll. Enter the device ID and name, then register face, finger, card, or password.',
          ),
          _manualInfoTile(
            icon: Icons.manage_accounts_rounded,
            title: 'Browse or modify',
            text:
                'MENU -> User -> Browse opens registered users. Select a user to edit ID, name, card, password, position, or privilege.',
          ),
          _manualInfoTile(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Privileges',
            text:
                'Use Admin for managers who can operate settings. Keep ordinary staff as User so attendance data and setup stay protected.',
          ),
          _manualInfoTile(
            icon: Icons.download_rounded,
            title: 'Download records',
            text:
                'USB download supports Report.xls and Log.txt. The manual recommends FAT32 USB drives under 32GB from common brands.',
          ),
          _manualInfoTile(
            icon: Icons.router_rounded,
            title: 'Network',
            text:
                'For TCP/IP, set Server Req to Yes, Port No to 5005, SerPortNo to 7005, and keep the device time zone correct.',
          ),
          _manualInfoTile(
            icon: Icons.wifi_rounded,
            title: 'WiFi',
            text:
                'For WiFi, enable WiFi, enable DHCP if needed, search for the network, choose it, then enter the password.',
          ),
        ],
      ),
    );
  }

  Widget _manualInfoTile({
    required IconData icon,
    required String title,
    required String text,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary.withOpacity(0.78), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: _setupBodyStyle(context)),
              ],
            ),
          ),
        ],
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
