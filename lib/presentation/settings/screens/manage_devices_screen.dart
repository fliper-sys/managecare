import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/loading_indicator.dart';

class ManageDevicesScreen extends StatefulWidget {
  const ManageDevicesScreen({super.key});

  @override
  State<ManageDevicesScreen> createState() => _ManageDevicesScreenState();
}

class _ManageDevicesScreenState extends State<ManageDevicesScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _tokens = [];

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await _firestore.collection('users').doc(user.uid).collection('fcmTokens').get();
    setState(() {
      _tokens = snap.docs;
      _loading = false;
    });
  }

  Future<void> _removeToken(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).collection('fcmTokens').doc(id).delete();
    await _loadTokens();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device removed')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Devices')),
      body: _loading
          ? const Center(child: CustomLoadingIndicator())
          : _tokens.isEmpty
              ? const Center(child: Text('No registered devices'))
              : ListView.separated(
                  itemCount: _tokens.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = _tokens[i].data();
                    final id = _tokens[i].id;
                    final platform = t['platform'] ?? 'unknown';
                    final token = t['token'] ?? '';
                    return ListTile(
                      title: Text(platform.toString()),
                      subtitle: Text('${token.substring(0, token.length > 20 ? 20 : token.length)}...'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                    title: const Text('Remove device'),
                                    content: const Text('Remove this device from receiving push notifications?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                                    ],
                                  ));
                          if (ok == true) await _removeToken(id);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
