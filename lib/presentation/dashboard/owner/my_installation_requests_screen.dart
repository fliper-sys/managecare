import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/datetime_utils.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/auth_provider.dart';

class MyInstallationRequestsScreen extends StatelessWidget {
  const MyInstallationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('My Installation Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('product_installation_requests').where('userId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('You have no installation requests')); 

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'pending';
              final createdAt = parseTimestamp(data['createdAt']);

              return ListTile(
                title: Text('Request ${d.id} • ₦${data['total'] ?? 0}'),
                subtitle: Text('Status: ${status.toUpperCase()} • ${createdAt.toLocal()}'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyInstallationRequestDetail(requestId: d.id))),
              );
            },
          );
        },
      ),
    );
  }
}

class MyInstallationRequestDetail extends StatelessWidget {
  final String requestId;
  const MyInstallationRequestDetail({required this.requestId, super.key});

  @override
  Widget build(BuildContext context) {
    final reqRef = FirebaseFirestore.instance.collection('product_installation_requests').doc(requestId);

    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: reqRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};

          final status = data['status'] as String? ?? 'pending';
          final assigned = data['assignedOfficerName'] as String?;
          final evalDate = parseTimestamp(data['evaluationDate']);
          final adminNotes = data['adminNotes'] as String? ?? '';
          final paymentStatus = data['paymentStatus'] as String? ?? 'unpaid';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Request: $requestId', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Status: ${status.toUpperCase()}'),
              if (assigned != null) Text('Assigned officer: $assigned'),
              Text('Evaluation scheduled: ${evalDate.toLocal()}'),
              if (adminNotes.isNotEmpty) Text('Admin notes: $adminNotes'),
              const SizedBox(height: 8),
              Text('Payment status: ${paymentStatus.toUpperCase()}'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.pushNamed(context, Routes.installationReceiptUpload), child: const Text('Upload/Attach Receipt')),
            ]),
          );
        },
      ),
    );
  }
}
