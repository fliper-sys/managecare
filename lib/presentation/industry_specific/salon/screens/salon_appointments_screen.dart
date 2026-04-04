import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/salon_provider.dart';

class SalonAppointmentsScreen extends StatefulWidget {
  const SalonAppointmentsScreen({super.key});

  @override
  State<SalonAppointmentsScreen> createState() =>
      _SalonAppointmentsScreenState();
}

class _SalonAppointmentsScreenState extends State<SalonAppointmentsScreen> {
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SalonProvider>();
      provider.loadAppointments();
      provider.loadServices();
      provider.loadStylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appointments'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateAppointmentDialog(context)),
        ],
      ),
      body: Consumer<SalonProvider>(
        builder: (context, provider, _) {
          var appointments = provider.appointments;
          if (_statusFilter != 'all') {
            appointments =
                appointments.where((a) => a.status == _statusFilter).toList();
          }

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _FilterChip(
                        label: 'All',
                        isActive: _statusFilter == 'all',
                        onTap: () => setState(() => _statusFilter = 'all')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Pending',
                        isActive: _statusFilter == 'pending',
                        onTap: () => setState(() => _statusFilter = 'pending'),
                        color: Colors.orange),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Confirmed',
                        isActive: _statusFilter == 'confirmed',
                        onTap: () =>
                            setState(() => _statusFilter = 'confirmed'),
                        color: Colors.blue),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Completed',
                        isActive: _statusFilter == 'completed',
                        onTap: () =>
                            setState(() => _statusFilter = 'completed'),
                        color: Colors.green),
                  ],
                ),
              ),
              Expanded(
                child: appointments.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Icon(Icons.event_busy,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text('No appointments',
                                style: AppTextStyles.body1
                                    .copyWith(color: AppColors.textSecondary)),
                          ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final apt = appointments[index];
                          return _AppointmentCard(
                            appointment: apt,
                            onStatusChange: (newStatus) => provider
                                .updateAppointmentStatus(apt.id, newStatus),
                            onComplete:
                                (amountPaid, paymentMethod, tipAmount) =>
                                    provider.completeAppointment(apt.id,
                                        amountPaid, paymentMethod, tipAmount),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateAppointmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateAppointmentDialog(
        provider: context.read<SalonProvider>(),
        onCreate: (appointment) {
          context.read<SalonProvider>().createAppointment(appointment);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Appointment created')));
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip(
      {required this.label,
      required this.isActive,
      required this.onTap,
      this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: isActive ? color : Colors.white,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: isActive ? Colors.white : color,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final SalonAppointment appointment;
  final Function(String) onStatusChange;
  final Function(double, String, double?) onComplete;

  const _AppointmentCard(
      {required this.appointment,
      required this.onStatusChange,
      required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appointment.status);
    final timeFormat = DateFormat('HH:mm').format(appointment.appointmentTime);
    final dateFormat =
        DateFormat('MMM dd, yyyy').format(appointment.appointmentTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border)),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$timeFormat - ${appointment.clientName}',
                      style: AppTextStyles.body1
                          .copyWith(fontWeight: FontWeight.bold)),
                  Text(appointment.serviceName,
                      style: AppTextStyles.body2
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(appointment.status.toUpperCase(),
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Date', value: dateFormat),
                _InfoRow(label: 'Time', value: timeFormat),
                _InfoRow(label: 'Client', value: appointment.clientName),
                _InfoRow(label: 'Email', value: appointment.clientEmail),
                _InfoRow(label: 'Phone', value: appointment.clientPhone),
                _InfoRow(label: 'Service', value: appointment.serviceName),
                _InfoRow(label: 'Stylist', value: appointment.stylistName),
                _InfoRow(
                    label: 'Price',
                    value: formatCurrency(appointment.servicePrice)),
                // Show commission earned for completed appointments
                if (appointment.status == 'completed')
                  Builder(builder: (context) {
                    final provider =
                        Provider.of<SalonProvider>(context, listen: false);
                    double pct = 0.0;
                    try {
                      final s = provider.stylists
                          .firstWhere((x) => x.id == appointment.stylistId);
                      pct = s.commissionPercentage ?? 0.0;
                    } catch (_) {}
                    final amount = (appointment.amountPaid != null &&
                            appointment.amountPaid! > 0)
                        ? appointment.amountPaid!
                        : appointment.servicePrice;
                    final commission = amount * (pct / 100.0);
                    return _InfoRow(
                        label: 'Commission', value: formatCurrency(commission));
                  }),
                const SizedBox(height: 12),
                if (appointment.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                          child: CustomButton(
                              text: 'Confirm',
                              backgroundColor: Colors.blue,
                              onPressed: () => onStatusChange('confirmed'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: CustomButton(
                              text: 'Cancel',
                              backgroundColor: Colors.red,
                              onPressed: () => onStatusChange('cancelled'))),
                    ],
                  )
                else if (appointment.status == 'confirmed')
                  Row(
                    children: [
                      Expanded(
                          child: CustomButton(
                              text: 'Complete & Checkout',
                              backgroundColor: Colors.green,
                              onPressed: () => _showCheckoutDialog(context))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CheckoutDialog(
        appointment: appointment,
        onComplete: onComplete,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTextStyles.body2),
        Text(value,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final SalonAppointment appointment;
  final Function(double, String, double?) onComplete;

  const _CheckoutDialog({required this.appointment, required this.onComplete});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late TextEditingController _amountCtrl;
  late TextEditingController _tipCtrl;
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.appointment.servicePrice.toStringAsFixed(0));
    _tipCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount =
        double.tryParse(_amountCtrl.text) ?? widget.appointment.servicePrice;
    final tip = double.tryParse(_tipCtrl.text) ?? 0;
    final total = amount + tip;

    return AlertDialog(
      title: const Text('Checkout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Service'),
                      Text(widget.appointment.serviceName)
                    ]),
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount'),
                      Text(formatCurrency(amount)),
                    ]),
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tip'),
                      Text(formatCurrency(tip)),
                    ]),
                const Divider(),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(formatCurrency(total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount Received'),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          TextField(
              controller: _tipCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tip Amount'),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          const Text('Payment Method', style: AppTextStyles.body1),
          ...[
            'cash',
            'card',
            'transfer',
            'flutterwave'
          ].map((method) => RadioListTile<String>(
                title: Text(method.toUpperCase()),
                value: method,
                groupValue: _paymentMethod,
                onChanged: (value) => setState(() => _paymentMethod = value!),
              )),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            widget.onComplete(amount, _paymentMethod, tip);
            Navigator.pop(context);
          },
          child: const Text('Complete'),
        ),
      ],
    );
  }
}

class _CreateAppointmentDialog extends StatefulWidget {
  final SalonProvider provider;
  final Function(SalonAppointment) onCreate;

  const _CreateAppointmentDialog(
      {required this.provider, required this.onCreate});

  @override
  State<_CreateAppointmentDialog> createState() =>
      _CreateAppointmentDialogState();
}

class _CreateAppointmentDialogState extends State<_CreateAppointmentDialog> {
  late TextEditingController _clientNameCtrl;
  late TextEditingController _clientPhoneCtrl;
  late TextEditingController _clientEmailCtrl;
  late TextEditingController _notesCtrl;
  SalonService? _selectedService;
  Stylist? _selectedStylist;
  DateTime? _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _clientNameCtrl = TextEditingController();
    _clientPhoneCtrl = TextEditingController();
    _clientEmailCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    widget.provider.loadServices();
    widget.provider.loadStylists();
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientEmailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Appointment', style: AppTextStyles.heading3),
              const SizedBox(height: 16),
              TextField(
                  controller: _clientNameCtrl,
                  decoration: InputDecoration(
                      labelText: 'Client Name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              TextField(
                  controller: _clientEmailCtrl,
                  decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              TextField(
                  controller: _clientPhoneCtrl,
                  decoration: InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              DropdownButton<SalonService>(
                value: _selectedService,
                hint: const Text('Select Service'),
                isExpanded: true,
                items: widget.provider.services
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (service) => setState(() {
                  _selectedService = service;
                  // Auto-select first stylist who can perform the service
                  if (_selectedService != null) {
                    final candidates = widget.provider.stylists
                        .where((st) =>
                            st.serviceIds.contains(_selectedService!.id))
                        .toList();
                    _selectedStylist =
                        candidates.isNotEmpty ? candidates.first : null;
                  } else {
                    _selectedStylist = null;
                  }
                }),
              ),
              const SizedBox(height: 12),
              DropdownButton<Stylist>(
                value: _selectedStylist,
                hint: const Text('Select Stylist'),
                isExpanded: true,
                items: widget.provider.stylists
                    .where((s) =>
                        _selectedService == null ||
                        s.serviceIds.contains(_selectedService!.id))
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (stylist) =>
                    setState(() => _selectedStylist = stylist),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (date != null) {
                    final time = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (time != null)
                      setState(() => _selectedDateTime = DateTime(date.year,
                          date.month, date.day, time.hour, time.minute));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDateTime == null
                            ? 'Select Date & Time'
                            : DateFormat('MMM dd, HH:mm')
                                .format(_selectedDateTime!),
                        style: AppTextStyles.body2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: CustomButton(
                          text: 'Cancel',
                          backgroundColor: AppColors.border,
                          onPressed: () => Navigator.pop(context))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: 'Create',
                      backgroundColor: AppColors.primary,
                      onPressed: _selectedService == null ||
                              _selectedStylist == null ||
                              _selectedDateTime == null ||
                              _clientNameCtrl.text.isEmpty
                          ? null
                          : () {
                              final appointment = SalonAppointment(
                                id: 'apt_${DateTime.now().millisecondsSinceEpoch}',
                                clientName: _clientNameCtrl.text,
                                clientPhone: _clientPhoneCtrl.text,
                                clientEmail: _clientEmailCtrl.text,
                                serviceId: _selectedService!.id,
                                serviceName: _selectedService!.name,
                                servicePrice: _selectedService!.price,
                                stylistId: _selectedStylist!.id,
                                stylistName: _selectedStylist!.name,
                                appointmentTime: _selectedDateTime!,
                                durationMinutes:
                                    _selectedService!.durationMinutes,
                                status: 'pending',
                                notes: _notesCtrl.text.isEmpty
                                    ? null
                                    : _notesCtrl.text,
                                createdAt: DateTime.now(),
                              );
                              widget.onCreate(appointment);
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
