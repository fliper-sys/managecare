import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../services/prescription_print_service.dart';

class AddPrescriptionScreen extends StatefulWidget {
  final String? patientId;
  final String? patientName;

  const AddPrescriptionScreen({super.key, this.patientId, this.patientName});

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final Map<String, int> _selected = {};
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _attachmentController = TextEditingController();
  String? _patientId;
  String? _patientName;

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    _patientName = widget.patientName;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  Patient? _selectedPatient(PharmacyProvider provider) {
    if (_patientId == null || _patientId!.isEmpty) return null;
    return provider.getPatientById(_patientId!);
  }

  List<Map<String, dynamic>> _recommendedRules(Drug drug, int? patientAge) {
    if (drug.prescriptions.isEmpty) return const [];
    if (patientAge == null) return drug.prescriptions;
    final matched = drug.prescriptions.where((rule) {
      final raw = (rule['ageRange'] ?? '').toString().trim();
      if (raw.isEmpty) return true;
      final parts = raw.split('-').map((e) => e.trim()).toList();
      if (parts.length != 2) return true;
      final min = int.tryParse(parts[0]);
      final max = int.tryParse(parts[1]);
      if (min == null || max == null) return true;
      return patientAge >= min && patientAge <= max;
    }).toList();
    return matched.isEmpty ? drug.prescriptions : matched;
  }

  Future<void> _createPatient() async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    DateTime? selectedDob;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: const Text('Create Patient'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneC,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime(now.year - 18, now.month, now.day),
                        firstDate: DateTime(1930),
                        lastDate: now,
                      );
                      if (picked == null) return;
                      setDialogState(() => selectedDob = picked);
                    },
                    icon: const Icon(Icons.cake_outlined),
                    label: Text(
                      selectedDob == null
                          ? 'Select date of birth'
                          : 'DOB: ${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final name = nameC.text.trim();
    final phone = phoneC.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a patient name')),
      );
      return;
    }

    final provider = context.read<PharmacyProvider>();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final id = 'P${DateTime.now().millisecondsSinceEpoch}';
    final newPatient = Patient(
      id: id,
      name: name,
      phone: phone,
      dateOfBirth: selectedDob,
    );

    await provider.addPatient(
      newPatient,
      persist: true,
      businessId: businessId,
    );

    if (!mounted) return;
    setState(() {
      _patientId = id;
      _patientName = name;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Patient created')),
    );
  }

  Future<void> _savePrescription({required bool printAfterSave}) async {
    final provider = context.read<PharmacyProvider>();
    final business = context.read<BusinessProvider>().currentBusiness;
    final auth = context.read<AuthProvider>();
    final selectedPatient = _selectedPatient(provider);
    final items = _selected.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'drugId': entry.key, 'qty': entry.value})
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one drug')),
      );
      return;
    }

    final requiresAttachment =
        provider.requiresAttachmentForPatient(selectedPatient);
    final attachmentReference = _attachmentController.text.trim();
    if (requiresAttachment && attachmentReference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A prescription attachment/reference is required for minors.',
          ),
        ),
      );
      return;
    }

    try {
      final prescription = await provider.addPrescription(
        _patientId ?? 'WALKIN',
        items,
        patientName: _patientName,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        attachmentReference:
            attachmentReference.isEmpty ? null : attachmentReference,
        attachmentRequired: requiresAttachment,
        patientDateOfBirth: selectedPatient?.dateOfBirth,
        persist: true,
        businessId: business?.id,
        userId: auth.currentUser?.id,
      );

      if (printAfterSave && mounted) {
        final rows = prescription.items.map((item) {
          final drug = provider.drugs.cast<Drug?>().firstWhere(
                (candidate) => candidate?.id == item['drugId'],
                orElse: () => null,
              );
          return <String, dynamic>{
            'name': drug?.name ?? item['drugId']?.toString() ?? 'Unknown drug',
            'qty': item['qty'] ?? 1,
          };
        }).toList();

        await PrescriptionPrintService.printPrescription(
          context,
          businessName: business?.name ?? 'Pharmacy',
          prescription: prescription,
          patientName: prescription.patientName ?? 'Walk-in Patient',
          itemRows: rows,
          patientAge: provider.calculateAge(selectedPatient?.dateOfBirth),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printAfterSave
                ? 'Prescription saved and ready to print'
                : 'Prescription added',
          ),
        ),
      );
      Navigator.pop(context, prescription.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    final selectedPatient = _selectedPatient(provider);
    final patientAge = provider.calculateAge(selectedPatient?.dateOfBirth);
    final requiresAttachment =
        provider.requiresAttachmentForPatient(selectedPatient);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _patientName != null
              ? 'Add Rx for $_patientName'
              : 'Add Prescription',
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _patientId ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Patient',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Walk-in patient'),
                      ),
                      ...provider.patients.map(
                        (patient) => DropdownMenuItem<String>(
                          value: patient.id,
                          child: Text(patient.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        if (value == null || value.isEmpty) {
                          _patientId = null;
                          _patientName = null;
                        } else {
                          final patient = provider.getPatientById(value);
                          _patientId = patient?.id;
                          _patientName = patient?.name;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _patientName != null
                              ? 'Patient: $_patientName'
                              : 'Patient: Walk-in',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _createPatient,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Create Patient'),
                      ),
                    ],
                  ),
                  if (patientAge != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Patient age: $patientAge',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Prescription notes / directions',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _attachmentController,
                    decoration: InputDecoration(
                      labelText: requiresAttachment
                          ? 'Required prescription attachment/reference'
                          : 'Attachment/reference (optional)',
                      hintText: 'e.g. Doctor note ID, paper Rx ref',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (requiresAttachment) ...[
                    const SizedBox(height: 8),
                    Text(
                      'This patient is under 18, so an attachment/reference is required before saving.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: provider.drugs.length,
                itemBuilder: (context, idx) {
                  final drug = provider.drugs[idx];
                  final qty = _selected[drug.id] ?? 0;
                  final recommendations =
                      _recommendedRules(drug, patientAge).take(2).toList();
                  return ListTile(
                    leading: recommendations.isNotEmpty
                        ? const Icon(Icons.medical_information_outlined)
                        : null,
                    title: Text(drug.name),
                    subtitle: Text(
                      'Stock: ${drug.stock} • ₦${drug.price.toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: qty > 0
                              ? () => setState(() {
                                    _selected[drug.id] =
                                        (qty - 1) <= 0 ? 0 : qty - 1;
                                  })
                              : null,
                        ),
                        Text('$qty'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: drug.stock > qty
                              ? () => setState(() {
                                    _selected[drug.id] = qty + 1;
                                  })
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _savePrescription(printAfterSave: false),
                    child: const Text('Save Prescription'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _savePrescription(printAfterSave: true),
                    icon: const Icon(Icons.print_outlined),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Save & Print'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
