import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../data/models/gym_member_model.dart';

class AttendanceTrackingScreen extends StatefulWidget {
  const AttendanceTrackingScreen({super.key});

  @override
  State<AttendanceTrackingScreen> createState() => _AttendanceTrackingScreenState();
}

class _AttendanceTrackingScreenState extends State<AttendanceTrackingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // All, Active, Completed
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final filteredRecords = _getFilteredRecords(provider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Attendance Tracking'),
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context),
                tooltip: 'Select Date',
              ),
            ],
          ),
          body: Column(
            children: [
              // Date and Filter Header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${filteredRecords.length} records',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search members...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _selectedFilter,
                          items: ['All', 'Active', 'Completed'].map((filter) {
                            return DropdownMenuItem(value: filter, child: Text(filter));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedFilter = value!),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Active Sessions Summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.blue[50],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AttendanceSummary(
                      label: 'Active Now',
                      count: provider.attendanceRecords.where((r) => r.isActive).length,
                      color: Colors.blue,
                    ),
                    _AttendanceSummary(
                      label: 'Completed Today',
                      count: provider.getAttendanceRecordsForDate(_selectedDate)
                          .where((r) => !r.isActive).length,
                      color: Colors.green,
                    ),
                    _AttendanceSummary(
                      label: 'Total Members',
                      count: provider.members.length,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),

              // Attendance Records List
              Expanded(
                child: filteredRecords.isEmpty
                    ? const Center(child: Text('No attendance records found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          final member = provider.members.firstWhere(
                            (m) => m.id == record.memberId,
                            orElse: () => Member(id: 'unknown', name: 'Unknown Member', email: '', phone: ''),
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: record.isActive ? Colors.green : Colors.grey,
                                child: Icon(
                                  record.isActive ? Icons.access_time : Icons.check_circle,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(member.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Check-in: ${DateFormat('h:mm a').format(record.checkInTime)}'),
                                  if (record.checkOutTime != null)
                                    Text('Check-out: ${DateFormat('h:mm a').format(record.checkOutTime!)}'),
                                  if (record.duration != null)
                                    Text('Duration: ${_formatDuration(record.duration!)}'),
                                ],
                              ),
                              trailing: record.isActive
                                  ? ElevatedButton(
                                      onPressed: () => _checkOutMember(context, provider, record),
                                      child: const Text('Check Out'),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.info_outline),
                                      onPressed: () => _showRecordDetails(context, record, member),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCheckInDialog(context, provider),
            icon: const Icon(Icons.login),
            label: const Text('Check In'),
          ),
        );
      },
    );
  }

  List<AttendanceRecord> _getFilteredRecords(GymProvider provider) {
    final dateRecords = provider.getAttendanceRecordsForDate(_selectedDate);
    var filtered = dateRecords;

    // Apply status filter
    switch (_selectedFilter) {
      case 'Active':
        filtered = filtered.where((r) => r.isActive).toList();
        break;
      case 'Completed':
        filtered = filtered.where((r) => !r.isActive).toList();
        break;
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((record) {
        final member = provider.members.firstWhere(
          (m) => m.id == record.memberId,
          orElse: () => Member(id: '', name: '', email: '', phone: ''),
        );
        return member.name.toLowerCase().contains(searchQuery) ||
               member.email.toLowerCase().contains(searchQuery) ||
               member.phone.contains(searchQuery);
      }).toList();
    }

    // Sort by check-in time (most recent first)
    filtered.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

    return filtered;
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showCheckInDialog(BuildContext context, GymProvider provider) {
    final searchController = TextEditingController();
    Member? selectedMember;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Check In Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Member',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView(
                  children: provider.members
                      .where((member) =>
                          searchController.text.isEmpty ||
                          member.name.toLowerCase().contains(searchController.text.toLowerCase()) ||
                          member.email.toLowerCase().contains(searchController.text.toLowerCase()) ||
                          member.phone.contains(searchController.text))
                      .take(10)
                      .map((member) => ListTile(
                            title: Text(member.name),
                            subtitle: Text(member.email),
                            selected: selectedMember?.id == member.id,
                            onTap: () => setState(() => selectedMember = member),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedMember == null
                  ? null
                  : () {
                      provider.checkInMember(selectedMember!.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${selectedMember!.name} checked in successfully')),
                      );
                    },
              child: const Text('Check In'),
            ),
          ],
        ),
      ),
    );
  }

  void _checkOutMember(BuildContext context, GymProvider provider, AttendanceRecord record) {
    final member = provider.members.firstWhere((m) => m.id == record.memberId);
    final duration = DateTime.now().difference(record.checkInTime);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check Out Member'),
        content: Text(
          '${member.name}\n\nSession Duration: ${_formatDuration(duration)}\n\nConfirm check out?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.checkOutMember(record.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${member.name} checked out successfully')),
              );
            },
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
  }

  void _showRecordDetails(BuildContext context, AttendanceRecord record, Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${member.name} - Session Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Check-in: ${DateFormat('MMM d, yyyy h:mm a').format(record.checkInTime)}'),
            if (record.checkOutTime != null)
              Text('Check-out: ${DateFormat('MMM d, yyyy h:mm a').format(record.checkOutTime!)}'),
            if (record.duration != null)
              Text('Duration: ${_formatDuration(record.duration!)}'),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(record.notes!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _AttendanceSummary extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _AttendanceSummary({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}