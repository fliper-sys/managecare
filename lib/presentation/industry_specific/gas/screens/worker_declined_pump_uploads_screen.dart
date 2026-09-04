import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/pump_row_mapper.dart';

class WorkerDeclinedPumpUploadsScreen extends StatefulWidget {
  const WorkerDeclinedPumpUploadsScreen({super.key});

  @override
  State<WorkerDeclinedPumpUploadsScreen> createState() =>
      _WorkerDeclinedPumpUploadsScreenState();
}

class _WorkerDeclinedPumpUploadsScreenState
    extends State<WorkerDeclinedPumpUploadsScreen> {
  static const _pollInterval = Duration(seconds: 15);

  Stream<List<Map<String, dynamic>>> _uploadStatuses(
    String businessId,
    String workerId,
  ) async* {
    while (true) {
      try {
        final pending =
            await _fetchByStatus(businessId, workerId, 'pending_review');
        final approved = await _fetchByStatus(businessId, workerId, 'approved');
        final declined = await _fetchByStatus(businessId, workerId, 'declined');
        final faulty = await _fetchByStatus(businessId, workerId, 'faulty');
        yield [...pending, ...approved, ...declined, ...faulty]
          ..sort((a, b) => (b['reviewedAt'] ?? b['uploadedAt'] ?? '')
              .toString()
              .compareTo((a['reviewedAt'] ?? a['uploadedAt'] ?? '').toString()));
      } catch (_) {}
      await Future.delayed(_pollInterval);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchByStatus(
    String businessId,
    String workerId,
    String status,
  ) async {
    final response = await ManagecareApiClient.instance.get(
      '/api/pumps/$businessId/uploads',
      query: {'status': status, 'workerId': workerId, 'limit': '100'},
    );
    final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    return rows.map(pumpUploadRowToJson).toList();
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  void _reregister(Map<String, dynamic> upload) {
    Navigator.pushNamed(
      context,
      Routes.petroleumPumpUpload,
      arguments: {'prefillUpload': upload},
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final user = context.watch<AuthProvider>().currentUser;
    final workerId = user?.id ?? '';
    final role = WorkerPermissions.normalizeRole(user?.role ?? '');
    final canViewStatus = role == 'pump_operator';
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: const Text('Pump Upload Status')),
      body: !canViewStatus
          ? const Center(
              child: Text('Only pump operators can view upload status'),
            )
          : businessId == null || businessId.isEmpty || workerId.isEmpty
          ? const Center(child: Text('No worker/business selected'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _uploadStatuses(businessId, workerId),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    rows.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rows.isEmpty) {
                  return const Center(child: Text('No pump uploads found'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final upload = rows[index];
                    final reviewed = _readDate(upload['reviewedAt']);
                    final status = upload['status']?.toString() ?? 'declined';
                    final canReregister =
                        status == 'declined' || status == 'faulty';
                    final reason =
                        upload['declineReason']?.toString().trim() ?? '';
                    final note = upload['reviewNote']?.toString().trim() ?? '';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          status == 'approved'
                              ? Icons.check_circle_outline
                              : status == 'pending_review'
                                  ? Icons.pending_actions_outlined
                                  : status == 'faulty'
                                      ? Icons.report_problem_outlined
                                      : Icons.cancel_outlined,
                          color: status == 'approved'
                              ? Colors.green.shade700
                              : status == 'pending_review'
                                  ? Colors.orange.shade800
                                  : Colors.red.shade700,
                        ),
                        title: Text(
                          'Pump ${upload['pumpNumber'] ?? ''} - ${upload['productName'] ?? 'Fuel'}',
                        ),
                        subtitle: Text(
                          [
                            'Status: $status',
                            if (reviewed != null)
                              'Reviewed: ${dateFormat.format(reviewed)}',
                            if (reason.isNotEmpty) 'Reason: $reason',
                            if (note.isNotEmpty) 'Note: $note',
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: canReregister
                            ? ElevatedButton(
                                onPressed: () => _reregister(upload),
                                child: const Text('Reregister'),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
