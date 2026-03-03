import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/text_styles.dart';

import '../providers/restaurant_provider.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RestaurantProvider>(context, listen: false);
      provider.initializeReservations();
      provider.initializeTables();
      provider.initializeServers();
    });
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    int guestCount = 2;
    DateTime? dateTime = DateTime.now().add(const Duration(hours: 1));
    String? selectedTableId;
    String? selectedServerId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final prov = Provider.of<RestaurantProvider>(ctx, listen: false);
          final availableTables = prov.tables;
          final servers = prov.servers;

          return AlertDialog(
            title: const Text('Create Reservation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer name')),
                  const SizedBox(height: 8),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Guests: '),
                    IconButton(onPressed: () => setState(() => guestCount = guestCount - 1 < 1 ? 1 : guestCount - 1), icon: const Icon(Icons.remove)),
                    Text('$guestCount', style: AppTextStyles.body1),
                    IconButton(onPressed: () => setState(() => guestCount = guestCount + 1), icon: const Icon(Icons.add)),
                  ]),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(context: ctx, initialDate: dateTime ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) {
                        final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(dateTime ?? DateTime.now()));
                        if (t != null) {
                          setState(() => dateTime = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute));
                        }
                      }
                    },
                    child: Text(dateTime != null ? dateTime!.toLocal().toString() : 'Pick date/time'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: selectedTableId,
                    hint: const Text('Assign table (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No table')),
                      ...availableTables.map((t) => DropdownMenuItem<String?>(value: t.id, child: Text('Table ${t.tableNumber} (cap ${t.capacity})'))),
                    ],
                    onChanged: (v) => setState(() => selectedTableId = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: selectedServerId,
                    hint: const Text('Assign server (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No server')),
                      ...servers.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setState(() => selectedServerId = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final prov = Provider.of<RestaurantProvider>(context, listen: false);
    final table = prov.tables.firstWhere((t) => t.id == selectedTableId, orElse: () => TableInfo(id: '', tableNumber: 0, capacity: 0));
    final server = prov.servers.firstWhere((s) => s.id == selectedServerId, orElse: () => Server(id: '', name: '', phone: '', role: 'waiter'));

    final reservation = Reservation(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}',
      businessId: '',
      customerName: nameCtrl.text.trim(),
      customerPhone: phoneCtrl.text.trim(),
      guestCount: guestCount,
      reservationDateTime: dateTime ?? DateTime.now(),
      status: 'pending',
      specialRequests: null,
      tableId: table.id.isNotEmpty ? table.id : null,
      tableNumber: table.tableNumber != 0 ? table.tableNumber : null,
      assignedWaiterId: server.id.isNotEmpty ? server.id : null,
      assignedWaiterName: server.name.isNotEmpty ? server.name : null,
    );

    await prov.createReservation(reservation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservations')),
      body: Consumer<RestaurantProvider>(builder: (ctx, prov, _) {
        final list = prov.reservations;
        if (list.isEmpty) return const Center(child: Text('No reservations'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final r = list[i];
            return ListTile(
              title: Text('${r.customerName} • ${r.guestCount} guests', style: AppTextStyles.subtitle1),
              subtitle: Text('${r.reservationDateTime.toLocal()} • Table ${r.tableNumber ?? '-'} • ${r.status}'),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(onPressed: _showCreateDialog, child: const Icon(Icons.add)),
    );
  }
}
