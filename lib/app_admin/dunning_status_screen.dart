import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../widgets/loading_indicator.dart';

// Runner configuration
const _RUNNER_URL =
    'https://globalthrivealliance.com/emailtemplate/run_dunning.php';
const _API_KEY = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';

class DunningStatusScreen extends StatelessWidget {
  const DunningStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('system').doc('dunning');
    final eventsRef = FirebaseFirestore.instance
        .collection('dunning_events')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dunning Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Trigger'),
            const SizedBox(height: 8),
            StreamBuilder<DocumentSnapshot>(
              stream: docRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CustomLoadingIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Text('No dunning runs recorded yet.');
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Last Trigger: ${data['last_trigger_ts'] ?? data['last_run_at'] ?? 'N/A'}'),
                        const SizedBox(height: 8),
                        Text('Last Run At: ${data['last_run_at'] ?? 'N/A'}'),
                        const SizedBox(height: 8),
                        Text('Report: ${data['report'] ?? 'No report stored'}'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Run Dunning Now button (admin action)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run Dunning Now'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Run Dunning'),
                      content: const Text(
                          'This will trigger the dunning runner on the server. Proceed?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel')),
                        ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Run')),
                      ],
                    ),
                  );

                  if (confirmed != true) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) =>
                        const Center(child: CustomLoadingIndicator()),
                  );

                  try {
                    final uri =
                        Uri.parse('$_RUNNER_URL?api_key=$_API_KEY&force=true');
                    final resp = await http
                        .get(uri)
                        .timeout(const Duration(seconds: 20));
                    Navigator.of(context).pop(); // remove progress dialog

                    String message = 'Runner returned ${resp.statusCode}';
                    try {
                      final body = resp.body;
                      message = body;
                    } catch (_) {}

                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Runner Result'),
                        content: SingleChildScrollView(child: Text(message)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('OK'))
                        ],
                      ),
                    );
                  } catch (e) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error running dunning: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Recent Dunning Events'),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: eventsRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CustomLoadingIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No recent dunning events'));
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final d = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(d['eventType'] ?? 'event'),
                        subtitle: Text(
                            'Business: ${d['businessId'] ?? '-'} • Days: ${d['daysOverdue'] ?? '-'}'),
                        trailing: Text(d['timestamp'] != null
                            ? (d['timestamp'] as Timestamp).toDate().toString()
                            : ''),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

