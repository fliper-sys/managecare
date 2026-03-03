import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';

class AddPrescriptionScreen extends StatefulWidget {
  final String? patientId;
  final String? patientName;

  const AddPrescriptionScreen({super.key, this.patientId, this.patientName});

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final Map<String, int> _selected = {}; // drugId -> qty
  String? _patientId;
  String? _patientName;

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    _patientName = widget.patientName;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
          title: Text(_patientName != null ? 'Add Rx for $_patientName' : 'Add Prescription'),
          backgroundColor: AppColors.primary),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Patient selector / creator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_patientName != null ? 'Patient: $_patientName' : 'Patient: Walk-in',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final nameC = TextEditingController();
                      final phoneC = TextEditingController();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Create Patient'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
                              const SizedBox(height: 8),
                              TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Phone')),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
                          ],
                        ),
                      ) ?? false;
                      if (!confirmed) return;
                      final name = nameC.text.trim();
                      final phone = phoneC.text.trim();
                      if (name.isEmpty) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
                        return;
                      }
                      final provider = context.read<PharmacyProvider>();
                      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
                      final id = 'P${DateTime.now().millisecondsSinceEpoch}';
                      final newPatient = Patient(id: id, name: name, phone: phone);
                      await provider.addPatient(newPatient, persist: true, businessId: businessId);
                      setState(() {
                        _patientId = id;
                        _patientName = name;
                      });
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient created')));
                    },
                    child: const Text('Create Patient'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: provider.drugs.length,
                itemBuilder: (context, idx) {
                  final d = provider.drugs[idx];
                  final qty = _selected[d.id] ?? 0;
                  return ListTile(
                    title: Text(d.name),
                    subtitle: Text('Stock: ${d.stock} • ₦${d.price.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty > 0
                                ? () => setState(() => _selected[d.id] = (qty - 1) <= 0 ? 0 : qty - 1)
                                : null),
                        Text('$qty'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: d.stock > qty ? () => setState(() => _selected[d.id] = qty + 1) : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final items = _selected.entries.where((e) => e.value > 0).map((e) => {'drugId': e.key, 'qty': e.value}).toList();
                  if (items.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one item')));
                    return;
                  }

                  try {
                    await provider.addPrescription(
                      _patientId ?? 'WALKIN',
                      items,
                      patientName: _patientName,
                      persist: true,
                      businessId: businessId,
                      userId: auth.currentUser?.id,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription added')));
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save Prescription'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

