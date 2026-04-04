import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';

import '../../../../providers/business_provider.dart';
import '../../../../providers/hotel_provider.dart';
import 'create_room_screen.dart'; // Assumed import based on previous context

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  String _filterType = 'all'; // all, available, occupied, maintenance
  String _sortBy = 'number'; // number, price, status

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
    final access = await businessProvider.canAccessFeatureEnhanced(
      'basic_sales',
      context: 'hotel_room_list_add_room',
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

    final roomCount = context.read<HotelProvider>().rooms.length;
    if (!businessProvider.isWithinLimit('rooms', roomCount)) {
      await _showBlockedDialog(
        title: 'Room limit reached',
        message: businessProvider.getLimitReachedMessage('rooms'),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HotelProvider>(context);
    List<Room> rooms = provider.rooms;

    // Apply filters
    if (_filterType != 'all') {
      rooms = rooms.where((r) => r.status == _filterType).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'price':
        rooms.sort((a, b) => a.pricePerNight.compareTo(b.pricePerNight));
        break;
      case 'status':
        rooms.sort((a, b) => a.status.compareTo(b.status));
        break;
      default:
        rooms.sort((a, b) => a.number.compareTo(b.number));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Room Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'number', child: Text('Sort by Number')),
              const PopupMenuItem(value: 'price', child: Text('Sort by Price')),
              const PopupMenuItem(value: 'status', child: Text('Sort by Status')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill('All Rooms', 'all'),
                  _buildFilterPill('Available', 'available'),
                  _buildFilterPill('Occupied', 'occupied'),
                  _buildFilterPill('Maintenance', 'maintenance'),
                ],
              ),
            ),
          ),
          
          // Room List
          Expanded(
            child: rooms.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _buildRoomCard(context, room, provider);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!await _ensureCanCreateRoom()) return;
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final isSelected = _filterType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _filterType = value),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No rooms found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, Room room, HotelProvider provider) {
    final statusColor = _getStatusColor(room.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showRoomDetails(context, room, provider),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top Row: Number & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            (room.emoji?.isNotEmpty ?? false) ? room.emoji! : '🛏️',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Room ${room.number}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              room.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),

                // Bottom Row: Details & Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${room.capacity}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.layers_outlined, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          'Fl. ${room.floor}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.star_rate_rounded, size: 16, color: Colors.amber),
                        Text(
                          ' ${room.rating}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      formatCurrency(room.pricePerNight),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available': return Colors.green;
      case 'occupied': return Colors.blue;
      case 'maintenance': return Colors.red;
      case 'reserved': return Colors.orange;
      default: return Colors.grey;
    }
  }

  void _showRoomDetails(BuildContext context, Room room, HotelProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, 
                height: 4, 
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            
            // Header
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Room ${room.number}', 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                   IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      // Navigate to Edit Room (pass room object)
                    },
                   )
                ],
              ),
            ),
            
            const Divider(),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Info Grid
                    Row(
                      children: [
                        Expanded(child: _buildDetailBox('Type', room.type.toUpperCase(), Icons.category_outlined)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDetailBox('Status', room.status.toUpperCase(), Icons.info_outline, color: _getStatusColor(room.status))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDetailBox('Price', formatCurrency(room.pricePerNight), Icons.attach_money)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDetailBox('Capacity', '${room.capacity} Guests', Icons.group_outlined)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Amenities
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Amenities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: room.amenities.map((amenity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!)
                          ),
                          child: Text(amenity, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Quick Actions
                    if(room.status == 'available')
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: () {
                          // Logic to mark as maintenance
                          provider.updateRoomStatus(room.id, 'maintenance');
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.build_circle_outlined),
                        label: const Text('Mark for Maintenance'),
                      ),
                    ),
                     if(room.status == 'maintenance')
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[50],
                          foregroundColor: Colors.green,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: () {
                          // Logic to mark as available
                           provider.updateRoomStatus(room.id, 'available');
                           Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark Available'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBox(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[600]),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}
