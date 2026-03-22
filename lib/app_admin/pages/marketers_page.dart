import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/marketer_provider.dart';
import '../../models/marketer_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class MarketersPage extends StatefulWidget {
  const MarketersPage({Key? key}) : super(key: key);

  @override
  State<MarketersPage> createState() => _MarketersPageState();
}

class _MarketersPageState extends State<MarketersPage> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketerProvider>().fetchMarketers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search marketers by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() {
                _searchQuery = value;
              }),
            ),
          ),
          Expanded(
            child: Consumer<MarketerProvider>(
              builder: (context, marketerProv, _) {
                if (marketerProv.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final marketers = marketerProv.marketers.where((m) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return m.fullName.toLowerCase().contains(q) ||
                      m.email.toLowerCase().contains(q);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: marketers.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: _showCreateDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create marketer'),
                        ),
                      );
                    }
                    final marketer = marketers[index - 1];
                    return _buildMarketerCard(marketer);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketerCard(MarketerModel marketer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(marketer.fullName),
        subtitle: Text(marketer.email),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditDialog(marketer);
            } else if (value == 'delete') {
              _confirmDelete(marketer);
            } else if (value == 'details') {
              _showDetails(marketer);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'details', child: Text('View details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New marketer'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              CustomTextField(label: 'Full Name', controller: nameCtrl),
              const SizedBox(height: 8),
              CustomTextField(label: 'Email', controller: emailCtrl),
              const SizedBox(height: 8),
              CustomTextField(label: 'Phone', controller: phoneCtrl, keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              CustomTextField(label: 'Password', controller: passwordCtrl, obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final provider = context.read<MarketerProvider>();
              final id = await provider.createMarketer(
                  email: emailCtrl.text.trim(),
                  fullName: nameCtrl.text.trim(),
                  password: passwordCtrl.text,
                  phoneNumber: phoneCtrl.text.trim());
              if (id != null) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(MarketerModel marketer) {
    final nameCtrl = TextEditingController(text: marketer.fullName);
    final phoneCtrl = TextEditingController(text: marketer.phoneNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit marketer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(label: 'Full Name', controller: nameCtrl),
            const SizedBox(height: 8),
            CustomTextField(label: 'Phone', controller: phoneCtrl, keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await context.read<MarketerProvider>().updateMarketer(
                    marketer.id,
                    fullName: nameCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(MarketerModel marketer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${marketer.fullName}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<MarketerProvider>().deleteMarketer(marketer.id);
    }
  }

  void _showDetails(MarketerModel marketer) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MarketerDetailPage(marketer: marketer)));
  }
}

class MarketerDetailPage extends StatefulWidget {
  final MarketerModel marketer;
  const MarketerDetailPage({required this.marketer, Key? key}) : super(key: key);

  @override
  State<MarketerDetailPage> createState() => _MarketerDetailPageState();
}

class _MarketerDetailPageState extends State<MarketerDetailPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<MarketerProvider>()
        .fetchMarketerReferrals(widget.marketer.email);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketerProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.marketer.fullName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${widget.marketer.email}'),
            Text('Phone: ${widget.marketer.phoneNumber ?? "-"}'),
            Text('Balance: ₦${widget.marketer.balance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('Referrals', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: provider.referrals.isEmpty
                  ? const Center(child: Text('No referrals yet'))
                  : ListView.builder(
                      itemCount: provider.referrals.length,
                      itemBuilder: (ctx, i) {
                        final r = provider.referrals[i];
                        return ListTile(
                          title: Text(r.userEmail),
                          subtitle: Text('Status: ${r.status}'),
                          trailing: Text('₦${r.commissionAmount.toStringAsFixed(0)}'),
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
