import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/unit_model.dart';
import '../../../../providers/apartment_provider.dart';
import '../../../../providers/business_provider.dart';

class AddEditUnitScreen extends StatefulWidget {
  final String apartmentId;
  final Unit? unit;
  const AddEditUnitScreen({Key? key, required this.apartmentId, this.unit}) : super(key: key);

  @override
  State<AddEditUnitScreen> createState() => _AddEditUnitScreenState();
}

class _AddEditUnitScreenState extends State<AddEditUnitScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _capacity = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.unit;
    if (u != null) {
      _name.text = u.name;
      _price.text = u.pricePerNight.toString();
      _capacity.text = u.capacity.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) return;

    setState(() => _isSaving = true);

    final unit = Unit(
      id: widget.unit?.id ?? '',
      name: _name.text.trim(),
      capacity: int.tryParse(_capacity.text) ?? 1,
      pricePerNight: double.tryParse(_price.text) ?? 0.0,
    );

    try {
      if (widget.unit == null) {
        await context.read<ApartmentProvider>().addUnit(businessId, widget.apartmentId, unit);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit added')));
      } else {
        await context.read<ApartmentProvider>().updateUnit(businessId, widget.apartmentId, unit.id, {
          'name': unit.name,
          'capacity': unit.capacity,
          'pricePerNight': unit.pricePerNight,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit updated')));
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save unit: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.unit == null ? 'Add Unit' : 'Edit Unit')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Unit name'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _price, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price per night'), validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid price' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity'), validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter valid capacity' : null),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
