import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../services/snackbar_service.dart';
import '../../providers/auth_provider.dart';

class InstallationRequestsAdminScreen extends StatefulWidget {
  const InstallationRequestsAdminScreen({super.key});

  @override
  State<InstallationRequestsAdminScreen> createState() => _InstallationRequestsAdminScreenState();
}

class _InstallationRequestsAdminScreenState extends State<InstallationRequestsAdminScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Installation Requests (Admin)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('product_installation_requests').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No installation requests found'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'pending';
              final bizName = data['businessName'] as String? ?? '';
              final createdAt = parseTimestamp(data['createdAt']);

              return ListTile(
                title: Text('$bizName • ${data['total'] ?? '₦0'}'),
                subtitle: Text('Status: ${status.toUpperCase()} • ${createdAt.toLocal()}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstallationRequestDetailScreen(requestId: d.id))),
              );
            },
          );
        },
      ),
    );
  }
}

class InstallationRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const InstallationRequestDetailScreen({required this.requestId, super.key});

  @override
  State<InstallationRequestDetailScreen> createState() => _InstallationRequestDetailScreenState();
}

class _InstallationRequestDetailScreenState extends State<InstallationRequestDetailScreen> {
  final _adminNotesController = TextEditingController();
  final _officerController = TextEditingController();
  DateTime? _selectedEvalDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _adminNotesController.dispose();
    _officerController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges(DocumentSnapshot doc) async {
    setState(() => _isSaving = true);
    try {

      await FirebaseFirestore.instance.collection('product_installation_requests').doc(widget.requestId).set({
        'assignedOfficerName': _officerController.text.trim().isEmpty ? null : _officerController.text.trim(),
        'assignedOfficerId': null,
        'adminNotes': _adminNotesController.text.trim(),
        'evaluationDate': _selectedEvalDate != null ? Timestamp.fromDate(_selectedEvalDate!) : null,
      }, SetOptions(merge: true));

      // Optionally change status to 'scheduled' if an evaluation date is picked
      if (_selectedEvalDate != null) {
        await FirebaseFirestore.instance.collection('product_installation_requests').doc(widget.requestId).set({
          'status': 'scheduled',
        }, SetOptions(merge: true));
      }

      SnackBarService.showSnackBar(context: context, message: 'Saved changes');
    } catch (e) {
      SnackBarService.showError(context, 'Failed to save: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('product_installation_requests').doc(widget.requestId).set({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      SnackBarService.showSnackBar(context: context, message: 'Status changed to $status');
    } catch (e) {
      SnackBarService.showError(context, 'Failed to change status: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmPayment(String paymentId) async {
    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      await FirebaseFirestore.instance.collection('installation_payments').doc(paymentId).set({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': auth.currentUser?.id ?? 'admin',
      }, SetOptions(merge: true));

      // Update request to mark payment confirmed
      await FirebaseFirestore.instance.collection('product_installation_requests').doc(widget.requestId).set({
        'paymentStatus': 'confirmed',
        'receiptConfirmed': true,
        'paymentApprovedAt': FieldValue.serverTimestamp(),
        'paymentApprovedBy': auth.currentUser?.id ?? 'admin',
      }, SetOptions(merge: true));

      SnackBarService.showSnackBar(context: context, message: 'Payment confirmed');
    } catch (e) {
      SnackBarService.showError(context, 'Failed to confirm payment: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reqRef = FirebaseFirestore.instance.collection('product_installation_requests').doc(widget.requestId);

    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: reqRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};

          _adminNotesController.text = data['adminNotes'] as String? ?? '';
          _officerController.text = data['assignedOfficerName'] as String? ?? '';
          _selectedEvalDate = parseTimestamp(data['evaluationDate']);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Request: ${widget.requestId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('User: ${data['userName'] ?? data['userId'] ?? ''}'),
                Text('Business: ${data['businessName'] ?? ''}'),
                const SizedBox(height: 12),
                Text('Products: ${data['numberOfProducts'] ?? ''} • Locations: ${data['numberOfLocations'] ?? ''}'),
                Text('Total: ₦${data['total'] ?? 0} • Status: ${data['status'] ?? 'pending'}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _officerController,
                  decoration: const InputDecoration(labelText: 'Assign officer (name)'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final dt = await showDatePicker(context: context, initialDate: _selectedEvalDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (dt != null) setState(() => _selectedEvalDate = dt);
                      },
                      child: Text(_selectedEvalDate == null ? 'Pick evaluation date' : 'Eval: ${_selectedEvalDate!.toLocal().toString().split(' ').first}'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _adminNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Admin notes'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => _saveChanges(snap.data!), child: _isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save changes')),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  ElevatedButton(onPressed: () => _changeStatus('evaluated'), child: const Text('Mark Evaluated')),
                  ElevatedButton(onPressed: () => _changeStatus('approved'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Approve')),
                  ElevatedButton(onPressed: () => _changeStatus('rejected'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Reject')),
                ]),
                const SizedBox(height: 16),
                const Text('Payments', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('installation_payments').where('requestId', isEqualTo: widget.requestId).snapshots(),
                  builder: (context, paySnap) {
                    if (!paySnap.hasData) return const SizedBox.shrink();
                    final payments = paySnap.data!.docs;
                    if (payments.isEmpty) return const Text('No receipts uploaded');

                    return Column(
                      children: payments.map((p) {
                        final pdata = p.data() as Map<String, dynamic>;
                        final receiptUrl = pdata['receiptUrl'] as String?;
                        return ListTile(
                          title: Text(pdata['uploadId'] ?? p.id),
                          subtitle: Text('Status: ${pdata['status'] ?? ''} • Created: ${parseTimestamp(pdata['createdAt']).toLocal()}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (receiptUrl != null)
                                IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () async {
                                    try {
                                      await launchUrlString(receiptUrl);
                                    } catch (e) {
                                      SnackBarService.showError(context, 'Could not open receipt URL');
                                    }
                                  },
                                ),
                              pdata['status'] == 'approved'
                                  ? const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check_circle, color: Colors.green))
                                  : ElevatedButton(onPressed: () => _confirmPayment(p.id), child: const Text('Confirm')),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
