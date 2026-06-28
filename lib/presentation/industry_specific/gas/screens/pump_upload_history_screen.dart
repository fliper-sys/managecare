import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';

class PumpUploadHistoryScreen extends StatefulWidget {
  const PumpUploadHistoryScreen({super.key});

  @override
  State<PumpUploadHistoryScreen> createState() =>
      _PumpUploadHistoryScreenState();
}

class _PumpUploadHistoryScreenState extends State<PumpUploadHistoryScreen> {
  String? _selectedPumpId;

  CollectionReference<Map<String, dynamic>>? _collection(String name) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection(name);
  }

  @override
  Widget build(BuildContext context) {
    final pumps = _collection('pump_configurations');
    final uploads = _collection('pump_daily_uploads');
    final role = WorkerPermissions.normalizeRole(
      context.watch<AuthProvider>().currentUser?.role ?? '',
    );
    final mustFilterOnePump = role == 'pump_operator';

    return Scaffold(
      appBar: AppBar(title: const Text('Pump Upload History')),
      body: pumps == null || uploads == null
          ? const Center(child: Text('No business selected'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: pumps
                        .where('isActive', isEqualTo: true)
                        .orderBy('pumpNumber')
                        .snapshots(includeMetadataChanges: true),
                    builder: (context, snapshot) {
                      final pumpDocs = snapshot.data?.docs ?? [];
                      return DropdownButtonFormField<String>(
                        value: _selectedPumpId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by pump',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          if (!mustFilterOnePump)
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All pumps'),
                            ),
                          ...pumpDocs.map(
                            (doc) => DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                'Pump ${doc.data()['pumpNumber']} - ${doc.data()['productName']}',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedPumpId = value);
                        },
                      );
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _uploadStream(uploads),
                    builder: (context, snapshot) {
                      if (mustFilterOnePump &&
                          (_selectedPumpId == null ||
                              _selectedPumpId!.isEmpty)) {
                        return const Center(
                          child: Text('Select one pump to view uploads'),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          docs.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (docs.isEmpty) {
                        return const Center(child: Text('No pump uploads yet'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final uploadedAt = data['uploadedAt'] is Timestamp
                              ? (data['uploadedAt'] as Timestamp).toDate()
                              : null;
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.upload_file_rounded),
                              ),
                              title: Text(
                                'Pump ${data['pumpNumber'] ?? ''} - ${data['productName'] ?? ''}',
                              ),
                              subtitle: Text(
                                '${uploadedAt == null ? '' : DateFormat.yMd().add_jm().format(uploadedAt)}\n'
                                'Operator: ${data['workerName'] ?? 'N/A'}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${((data['soldVolume'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${((data['expectedAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _uploadStream(
    CollectionReference<Map<String, dynamic>> uploads,
  ) {
    Query<Map<String, dynamic>> query = uploads;
    if (_selectedPumpId != null && _selectedPumpId!.isNotEmpty) {
      query = query.where('pumpId', isEqualTo: _selectedPumpId);
    }
    return query
        .orderBy('uploadedAt', descending: true)
        .limit(200)
        .snapshots(includeMetadataChanges: true);
  }
}
