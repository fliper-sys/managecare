import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/theme/colors.dart';


class AddEditDrugScreen extends StatefulWidget {
  final Drug? drug;
  final String? drugId;
  const AddEditDrugScreen({super.key, this.drug, this.drugId});

  @override
  State<AddEditDrugScreen> createState() => _AddEditDrugScreenState();
}

class _AddEditDrugScreenState extends State<AddEditDrugScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _batchController;
  late TextEditingController _stockController;
  late TextEditingController _priceController;
  DateTime _expiry = DateTime.now().add(const Duration(days: 365));

  @override
  void initState() {
    super.initState();
    var d = widget.drug;
    if (d == null && widget.drugId != null) {
      // Try to resolve drug from provider by id
      try {
        final provider = context.read<PharmacyProvider>();
        d = provider.drugs.firstWhere((x) => x.id == widget.drugId);
      } catch (_) {
        d = null;
      }
    }

    _nameController = TextEditingController(text: d?.name ?? '');
    _batchController = TextEditingController(text: d?.batch ?? '');
    _stockController = TextEditingController(text: d?.stock.toString() ?? '0');
    _priceController = TextEditingController(
        text: d != null ? d.price.toStringAsFixed(2) : '0.00');
    _expiry = d?.expiry ?? _expiry;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _batchController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<PharmacyProvider>();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;

    final name = _nameController.text.trim();
    final batch = _batchController.text.trim();
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    if (widget.drug == null) {
      final newDrug = Drug(
        id: 'D${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        batch: batch,
        expiry: _expiry,
        stock: stock,
        price: price,
      );

      provider.addDrug(newDrug, persist: provider.hasRemote, businessId: businessId);
    } else {
      final existing = widget.drug!;
      final updated = Drug(
        id: existing.id,
        name: name,
        batch: batch,
        expiry: _expiry,
        stock: stock,
        price: price,
      );
      await provider.updateDrug(updated, persist: provider.hasRemote, businessId: businessId);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.drug != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Drug' : 'Add Drug'),
        backgroundColor: AppColors.pharmacy,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Drug Name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _batchController,
                decoration: const InputDecoration(labelText: 'Batch / Manufacturer'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock Quantity'),
                validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price per Unit'),
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a valid price' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Expiry: '),
                  TextButton(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _expiry,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) setState(() => _expiry = selected);
                    },
                    child: Text(_expiry.toString().split(' ')[0]),
                  )
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.pharmacy),
                onPressed: _save,
                child: Text(isEdit ? 'Save Changes' : 'Add Drug'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
