import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/empty_state.dart';
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
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Devices'),
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CustomLoadingIndicator())
          : _tokens.isEmpty
              ? const EmptyState(
                  title: 'No registered devices',
                  subtitle:
                      'Once this account signs in on a device and accepts push permissions, it will appear here.',
                  icon: Icons.devices_other_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _tokens.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final t = _tokens[i].data();
                    final id = _tokens[i].id;
                    final platform = t['platform'] ?? 'unknown';
                    final token = t['token'] ?? '';
                    final previewLength = token.length > 28 ? 28 : token.length;

                    return Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outline.withOpacity(0.65),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            platform.toString().toLowerCase().contains('ios')
                                ? Icons.phone_iphone
                                : Icons.android,
                            color: scheme.primary,
                          ),
                        ),
                        title: Text(
                          platform.toString().toUpperCase(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${token.substring(0, previewLength)}...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withOpacity(0.68),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: scheme.error),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove device'),
                                content: const Text(
                                  'Remove this device from receiving push notifications?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) await _removeToken(id);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
