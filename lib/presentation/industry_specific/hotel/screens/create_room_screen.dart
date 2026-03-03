import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';

import '../../../../widgets/custom_text_field.dart';
import '../../../../providers/hotel_provider.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _numberCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '0');
  final _floorCtrl = TextEditingController(text: '1');
  final _amenitiesCtrl = TextEditingController();
  
  // State variables
  bool _isCreating = false;
  String _selectedType = 'single'; // Default value for dropdown
  
  // Available room types
  final List<String> _roomTypes = ['single', 'double', 'suite', 'deluxe', 'family'];

  @override
  void dispose() {
    _numberCtrl.dispose();
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    _floorCtrl.dispose();
    _amenitiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);
    final provider = context.read<HotelProvider>();

    try {
      await provider.createRoom(
        number: _numberCtrl.text.trim(),
        type: _selectedType, // Uses the dropdown value
        capacity: int.tryParse(_capacityCtrl.text.trim()) ?? 1,
        pricePerNight: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        floor: int.tryParse(_floorCtrl.text.trim()) ?? 1,
        amenities: _amenitiesCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('Add New Room', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Icon
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hotel, size: 40, color: AppColors.primary),
            ),

            // Form Card
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Basic Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // Room Number
                      CustomTextField(
                        label: 'Room Number',
                        controller: _numberCtrl,
                        prefixIcon: Icons.door_front_door_outlined,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Room Type Dropdown (Better UX than text field)
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Room Type',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _roomTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type[0].toUpperCase() + type.substring(1)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text("Details & Pricing", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      // Row for Price and Capacity
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Price / Night',
                              controller: _priceCtrl,
                              prefixIcon: Icons.attach_money,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              label: 'Capacity',
                              controller: _capacityCtrl,
                              prefixIcon: Icons.people_outline,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row for Floor
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Floor Number',
                              controller: _floorCtrl,
                              prefixIcon: Icons.layers_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Spacer or another field could go here
                          const Spacer(), 
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Amenities
                      CustomTextField(
                        label: 'Amenities (e.g. WiFi, AC, TV)',
                        controller: _amenitiesCtrl,
                        prefixIcon: Icons.featured_play_list_outlined,
                        // Adding a helper text if your CustomTextField supports it, otherwise ignore
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Separate items with a comma",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Large Action Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text(
                        'Create Room',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}