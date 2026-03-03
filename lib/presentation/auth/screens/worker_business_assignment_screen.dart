import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/repositories/business_repository_impl.dart';
import '../../../data/models/business_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/routes.dart';

class WorkerBusinessAssignmentScreen extends StatefulWidget {
  final String userId;

  const WorkerBusinessAssignmentScreen({super.key, required this.userId});

  @override
  State<WorkerBusinessAssignmentScreen> createState() => _WorkerBusinessAssignmentScreenState();
}

class _WorkerBusinessAssignmentScreenState extends State<WorkerBusinessAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerIdController = TextEditingController();
  bool _loading = false;
  String? _error;

  final BusinessRepository _repo = BusinessRepository();

  Future<void> _assignByOwnerId(String ownerInput) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? ownerId = ownerInput.trim();

      // First, try to interpret input as an ownerId and query businesses
      var businesses = await _repo.getUserBusinesses(ownerId);

      // If no businesses found and input looks like an email, try to resolve owner by email
      if (businesses.isEmpty && ownerInput.contains('@')) {
        final uquery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: ownerInput.trim())
            .limit(1)
            .get();
        if (uquery.docs.isNotEmpty) {
          ownerId = uquery.docs.first.id;
          businesses = await _repo.getUserBusinesses(ownerId);
        }
      }

      if (businesses.isEmpty) {
        setState(() {
          _error = 'No business found for that owner id/email.';
          _loading = false;
        });
        return;
      }

      // If multiple businesses found, pick the first or allow the user to choose
      BusinessModel chosen;
      if (businesses.length == 1) {
        chosen = businesses.first;
      } else {
        // Ask user to pick one
        final picked = await showDialog<BusinessModel?>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Select business to join'),
            children: businesses
                .map((b) => SimpleDialogOption(
                      onPressed: () => Navigator.of(ctx).pop(b),
                      child: Text('${b.name} (${b.id})'),
                    ))
                .toList(),
          ),
        );

        if (picked == null) {
          setState(() {
            _loading = false;
          });
          return;
        }
        chosen = picked;
      }

      // Persist assignment to the logged-in user via AuthProvider
      final auth = context.read<AuthProvider>();
      final current = auth.currentUser;
      if (current == null) throw Exception('No logged-in user');

      final merged = List<String>.from({...current.businessIds, chosen.id});
      final updated = current.copyWith(
        businessIds: merged,
        currentBusinessId: chosen.id,
        businessType: chosen.businessType,
      );

      await auth.updateUserModel(updated);

      // Navigate to worker dashboard
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully linked to business')));
      Navigator.of(context).pushReplacementNamed(Routes.workerDashboard);
    } catch (e) {
      setState(() {
        _error = 'Failed to assign business: ${e.toString()}';
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    _ownerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link to Owner Business'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the business owner\'s ID or email to link your account to their business. If the owner has multiple businesses, you will be asked to choose.',
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _ownerIdController,
                decoration: const InputDecoration(
                  labelText: 'Owner ID or email',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter owner id or email' : null,
                enabled: !_loading,
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _assignByOwnerId(_ownerIdController.text.trim());
                      }
                    },
              child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Link Business'),
            ),
          ],
        ),
      ),
    );
  }
}
