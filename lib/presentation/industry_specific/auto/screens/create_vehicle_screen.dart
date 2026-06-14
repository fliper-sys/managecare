import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/routes.dart';
import '../../../../providers/auto_provider.dart';
import '../../../../providers/business_provider.dart';

class CreateVehicleScreen extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final String? customerPhone;

  const CreateVehicleScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.customerPhone,
  });

  @override
  State<CreateVehicleScreen> createState() => _CreateVehicleScreenState();
}

class _CreateVehicleScreenState extends State<CreateVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _vinController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.customerName != null && widget.customerName!.isNotEmpty) {
      _ownerNameController.text = widget.customerName!;
    }
    if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty) {
      _ownerPhoneController.text = widget.customerPhone!;
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _licensePlateController.dispose();
    _vinController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final autoProvider = context.read<AutoProvider>();
      final businessProvider = context.read<BusinessProvider>();

      final vehicle = Vehicle(
        id: const Uuid().v4(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        licensePlate: _licensePlateController.text.trim(),
        vin: _vinController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        ownerName: _ownerNameController.text.trim(),
        ownerPhone: _ownerPhoneController.text.trim(),
        customerId: widget.customerId,
      );

      final ok = await autoProvider.addVehicle(vehicle);

      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle added successfully')),
          );
          Navigator.of(context).pop(vehicle);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save vehicle. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding vehicle: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vehicle'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.customerId != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Adding a car for ${widget.customerName ?? 'this customer'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Vehicle Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Make
                TextFormField(
                  controller: _makeController,
                  decoration: const InputDecoration(
                    labelText: 'Make *',
                    hintText: 'e.g., Toyota, Honda, Ford',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Make is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Model
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model *',
                    hintText: 'e.g., Camry, Civic, F-150',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Model is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Year
                TextFormField(
                  controller: _yearController,
                  decoration: const InputDecoration(
                    labelText: 'Year *',
                    hintText: 'e.g., 2020',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Year is required';
                    }
                    final year = int.tryParse(value.trim());
                    if (year == null) {
                      return 'Please enter a valid year';
                    }
                    if (year < 1900 || year > DateTime.now().year + 1) {
                      return 'Please enter a valid year';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // License Plate
                TextFormField(
                  controller: _licensePlateController,
                  decoration: const InputDecoration(
                    labelText: 'License Plate *',
                    hintText: 'e.g., ABC-123',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'License plate is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // VIN
                TextFormField(
                  controller: _vinController,
                  decoration: const InputDecoration(
                    labelText: 'VIN',
                    hintText: 'Vehicle Identification Number (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 24),

                if (widget.customerId == null) ...[
                  const Text(
                    'Owner Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Owner Name
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Owner Name',
                      hintText: 'Vehicle owner\'s full name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Owner Phone
                  TextFormField(
                    controller: _ownerPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Owner Phone',
                      hintText: 'Owner\'s contact number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[900],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Add Vehicle',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}