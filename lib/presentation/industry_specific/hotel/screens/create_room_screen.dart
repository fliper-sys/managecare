import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/worker_permissions.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
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
  final _halfDayPriceCtrl = TextEditingController(text: '0');
  final _floorCtrl = TextEditingController(text: '1');
  final _amenitiesCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _bedSizeCtrl = TextEditingController();
  final _extraDetailsCtrl = TextEditingController();
  final _halfDayHoursCtrl = TextEditingController(text: '12');
  final _fullDayCheckoutCtrl = TextEditingController(text: '12:00');
  
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
    _halfDayPriceCtrl.dispose();
    _floorCtrl.dispose();
    _amenitiesCtrl.dispose();
    _sizeCtrl.dispose();
    _bedSizeCtrl.dispose();
    _extraDetailsCtrl.dispose();
    _halfDayHoursCtrl.dispose();
    _fullDayCheckoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _showBlockedDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureCanCreateRoom() async {
    final businessProvider = context.read<BusinessProvider>();
    final hotelProvider = context.read<HotelProvider>();
    final access = await businessProvider.canAccessFeatureEnhanced(
      'basic_sales',
      context: 'hotel_create_room_submit',
    );

    if (!mounted) return false;
    if (!(access['ok'] as bool? ?? false)) {
      await _showBlockedDialog(
        title: 'Subscription required',
        message: businessProvider.getSubscriptionBlockedMessage(
          feature: 'basic_sales',
        ),
      );
      return false;
    }

    final roomCount = hotelProvider.rooms.length;
    if (!businessProvider.isWithinLimit('rooms', roomCount)) {
      await _showBlockedDialog(
        title: 'Room limit reached',
        message: businessProvider.getLimitReachedMessage('rooms'),
      );
      return false;
    }

    if (_selectedType == 'suite') {
      final suiteCount = hotelProvider.rooms
          .where((room) => room.type.toLowerCase() == 'suite')
          .length;
      if (!businessProvider.isWithinLimit('suites', suiteCount)) {
        await _showBlockedDialog(
          title: 'Suite limit reached',
          message: businessProvider.getLimitReachedMessage('suites'),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<HotelProvider>();
    final roomNumber = _numberCtrl.text.trim();
    final capacity = int.tryParse(_capacityCtrl.text.trim()) ?? 0;
    final pricePerNight = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final halfDayPrice =
        double.tryParse(_halfDayPriceCtrl.text.trim()) ?? 0.0;
    final halfDayHours = int.tryParse(_halfDayHoursCtrl.text.trim()) ?? 12;

    if (roomNumber.isEmpty) return;
    if (capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room capacity must be greater than zero')),
      );
      return;
    }
    if (pricePerNight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room price must be greater than zero')),
      );
      return;
    }
    if (halfDayHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Half day hours must be greater than zero')),
      );
      return;
    }
    final duplicateNumber = provider.rooms.any(
      (room) => room.number.trim().toLowerCase() == roomNumber.toLowerCase(),
    );
    if (duplicateNumber) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room $roomNumber already exists')),
      );
      return;
    }
    if (!await _ensureCanCreateRoom()) return;

    setState(() => _isCreating = true);

    try {
      await provider.createRoom(
        number: roomNumber,
        type: _selectedType, // Uses the dropdown value
        capacity: capacity,
        pricePerNight: pricePerNight,
        halfDayPrice: halfDayPrice,
        floor: int.tryParse(_floorCtrl.text.trim()) ?? 1,
        amenities: _amenitiesCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        size: _sizeCtrl.text.trim(),
        bedSize: _bedSizeCtrl.text.trim(),
        extraDetails: {
          if (_extraDetailsCtrl.text.trim().isNotEmpty)
            'notes': _extraDetailsCtrl.text.trim(),
        },
        halfDayHours: halfDayHours,
        fullDayCheckoutTime: _fullDayCheckoutCtrl.text.trim().isEmpty
            ? '12:00'
            : _fullDayCheckoutCtrl.text.trim(),
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
    final auth = context.watch<AuthProvider>();
    final canManageRooms = auth.isOwnerUser ||
        WorkerPermissions.canManageRooms(auth.currentUser?.role ?? '');

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
                              label: 'Full Day Price',
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
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Half Day Price',
                              controller: _halfDayPriceCtrl,
                              prefixIcon: Icons.payments_outlined,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              label: 'Half Day Hours',
                              controller: _halfDayHoursCtrl,
                              prefixIcon: Icons.timer_outlined,
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
                      CustomTextField(
                        label: 'Full Day Checkout Time (HH:mm)',
                        controller: _fullDayCheckoutCtrl,
                        prefixIcon: Icons.schedule_outlined,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Room Size',
                              controller: _sizeCtrl,
                              prefixIcon: Icons.square_foot_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              label: 'Bed Size',
                              controller: _bedSizeCtrl,
                              prefixIcon: Icons.bed_outlined,
                            ),
                          ),
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
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Extra Details (optional)',
                        controller: _extraDetailsCtrl,
                        prefixIcon: Icons.notes_outlined,
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
                onPressed: !canManageRooms || _isCreating ? null : _createRoom,
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
            if (!canManageRooms)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Your role cannot create or edit rooms.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
