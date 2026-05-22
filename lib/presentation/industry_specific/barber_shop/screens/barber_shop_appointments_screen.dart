import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/barber_shop_provider.dart';
import '../../../../providers/business_provider.dart';

class BarberShopAppointmentsScreen extends StatefulWidget {
  const BarberShopAppointmentsScreen({super.key});

  @override
  State<BarberShopAppointmentsScreen> createState() =>
      _BarberShopAppointmentsScreenState();
}

class _BarberShopAppointmentsScreenState
    extends State<BarberShopAppointmentsScreen> {
  String _statusFilter = 'all'; // all, pending, confirmed, completed, cancelled

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarberShopProvider>().loadAppointments();
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
            onPressed: () {
              final business = context.read<BusinessProvider>().currentBusiness;
              if (business == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a business first')));
                return;
              }
              _showCreateAppointmentDialog(context);
            },
          ),
        ],
      ),
      body: Consumer<BarberShopProvider>(
        builder: (context, provider, _) {
          var appointments = provider.appointments;

          if (_statusFilter != 'all') {
            appointments =
                appointments.where((a) => a.status == _statusFilter).toList();
          }

          return Column(
            children: [
              // Status Filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isActive: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending',
                      isActive: _statusFilter == 'pending',
                      onTap: () => setState(() => _statusFilter = 'pending'),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Confirmed',
                      isActive: _statusFilter == 'confirmed',
                      onTap: () => setState(() => _statusFilter = 'confirmed'),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Completed',
                      isActive: _statusFilter == 'completed',
                      onTap: () => setState(() => _statusFilter = 'completed'),
                      color: Colors.green,
                    ),
                  ],
                ),
              ),

              // Appointments List
              Expanded(
                child: appointments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text(
                              'No appointments',
                              style: AppTextStyles.body1
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final apt = appointments[index];
                          return _AppointmentCard(
                            appointment: apt,
                            onStatusChange: (newStatus) {
                              provider.updateAppointmentStatus(
                                  apt.id, newStatus);
                            },
                            onComplete: (amountPaid, paymentMethod) {
                              provider.completeAppointment(
                                  apt.id, amountPaid, paymentMethod);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Appointment completed')),
                              );
                            },
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
        provider: context.read<BarberShopProvider>(),
        onCreate: (appointment) async {
          final ok = await context.read<BarberShopProvider>().createAppointment(appointment);
          Navigator.pop(context);
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Appointment created')),
            );
          } else {
            final msg = context.read<BarberShopProvider>().errorMessage ?? 'Failed to create appointment';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
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

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final BarberShopAppointment appointment;
  final Function(String) onStatusChange;
  final Function(double, String) onComplete;

  const _AppointmentCard({
    required this.appointment,
    required this.onStatusChange,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appointment.status);
    final timeFormat = DateFormat('HH:mm').format(appointment.appointmentTime);
    final dateFormat =
        DateFormat('MMM dd, yyyy').format(appointment.appointmentTime);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
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
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                appointment.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
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
                _InfoRow(label: 'Phone', value: appointment.clientPhone),
                _InfoRow(label: 'Service', value: appointment.serviceName),
                _InfoRow(label: 'Barber', value: appointment.barberName),
                _InfoRow(
                    label: 'Duration',
                    value: '${appointment.durationMinutes} mins'),
                _InfoRow(
                    label: 'Price',
                    value: formatCurrency(appointment.servicePrice)),
                // Show commission earned for completed appointments
                if (appointment.status == 'completed')
                  Builder(builder: (context) {
                    final provider = Provider.of<BarberShopProvider>(context, listen: false);
                    double pct = 0.0;
                    try {
                      final b = provider.barbers.firstWhere((x) => x.id == appointment.barberId);
                      pct = b.commissionPercentage ?? 0.0;
                    } catch (_) {}
                    final amount = (appointment.amountPaid != null && appointment.amountPaid! > 0) ? appointment.amountPaid! : appointment.servicePrice;
                    final commission = amount * (pct / 100.0);
                    return _InfoRow(label: 'Commission', value: formatCurrency(commission));
                  }),
                if (appointment.notes != null && appointment.notes!.isNotEmpty)
                  _InfoRow(label: 'Notes', value: appointment.notes!),
                const SizedBox(height: 12),
                if (appointment.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Confirm',
                          backgroundColor: Colors.blue,
                          onPressed: () => onStatusChange('confirmed'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomButton(
                          text: 'Cancel',
                          backgroundColor: Colors.red,
                          onPressed: () => onStatusChange('cancelled'),
                        ),
                      ),
                    ],
                  )
                else if (appointment.status == 'confirmed')
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Complete & Checkout',
                          backgroundColor: Colors.green,
                          onPressed: () => _showCheckoutDialog(context),
                        ),
                      ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body2),
          Text(value,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final BarberShopAppointment appointment;
  final Function(double, String) onComplete;

  const _CheckoutDialog({
    required this.appointment,
    required this.onComplete,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late TextEditingController _amountCtrl;
  late TextEditingController _taxRateController;
  late TextEditingController _discountController;
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.appointment.servicePrice.toStringAsFixed(0));
    _taxRateController = TextEditingController(text: '0');  // Default 0%
    _discountController = TextEditingController(text: '0');  // Default 0
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount =
        double.tryParse(_amountCtrl.text) ?? widget.appointment.servicePrice;
    final taxRate = double.tryParse(_taxRateController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    final tax = amount * (taxRate / 100);
    final total = amount + tax - discount;

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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Service'),
                    Text(widget.appointment.serviceName,
                        style: AppTextStyles.body2
                            .copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Base Price'),
                    Text(
                        formatCurrency(widget.appointment.servicePrice),
                        style: AppTextStyles.body2),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formatCurrency(total),
                        style: AppTextStyles.body1
                            .copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount Received',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Tax Field
          Row(
            children: [
              Expanded(
                child: Text('Tax (%)',
                    style: AppTextStyles.body2),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _taxRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Text(formatCurrency(tax),
                  style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 12),
          // Discount Field
          Row(
            children: [
              Expanded(
                child: const Text('Discount (NGN)',
                    style: AppTextStyles.body2),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Text('-${formatCurrency(discount)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Payment Method', style: AppTextStyles.body1),
          const SizedBox(height: 8),
          ...['cash', 'card', 'transfer', 'flutterwave'].map(
            (method) => RadioListTile<String>(
              title: Text(method.toUpperCase()),
              value: method,
              groupValue: _paymentMethod,
              onChanged: (value) => setState(() => _paymentMethod = value!),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Pass the amount with tax and discount applied
            final finalAmount = amount + tax - discount;
            widget.onComplete(finalAmount, _paymentMethod);
            Navigator.pop(context);
          },
          child: const Text('Complete'),
        ),
      ],
    );
  }
}

class _CreateAppointmentDialog extends StatefulWidget {
  final BarberShopProvider provider;
  final Function(BarberShopAppointment) onCreate;

  const _CreateAppointmentDialog({
    required this.provider,
    required this.onCreate,
  });

  @override
  State<_CreateAppointmentDialog> createState() =>
      _CreateAppointmentDialogState();
}

class _CreateAppointmentDialogState extends State<_CreateAppointmentDialog> {
  late TextEditingController _clientNameCtrl;
  late TextEditingController _clientPhoneCtrl;
  late TextEditingController _notesCtrl;
  BarberShopService? _selectedService;
  Barber? _selectedBarber;
  DateTime? _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _clientNameCtrl = TextEditingController();
    _clientPhoneCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
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
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientPhoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Client Phone',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButton<BarberShopService>(
                value: _selectedService,
                hint: const Text('Select Service'),
                isExpanded: true,
                items: widget.provider.services
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (service) =>
                    setState(() => _selectedService = service),
              ),
              const SizedBox(height: 12),
              DropdownButton<Barber>(
                value: _selectedBarber,
                hint: const Text('Select Barber'),
                isExpanded: true,
                items: widget.provider.barbers
                    .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                    .toList(),
                onChanged: (barber) => setState(() => _selectedBarber = barber),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() => _selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ));
                    }
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Cancel',
                      backgroundColor: AppColors.border,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: 'Create',
                      backgroundColor: AppColors.primary,
                      onPressed: _selectedService == null ||
                              _selectedBarber == null ||
                              _selectedDateTime == null ||
                              _clientNameCtrl.text.isEmpty
                          ? null
                          : () {
                              final appointment = BarberShopAppointment(
                                id: 'apt_${DateTime.now().millisecondsSinceEpoch}',
                                clientName: _clientNameCtrl.text,
                                clientPhone: _clientPhoneCtrl.text,
                                serviceId: _selectedService!.id,
                                serviceName: _selectedService!.name,
                                servicePrice: _selectedService!.price,
                                barberId: _selectedBarber!.id,
                                barberName: _selectedBarber!.name,
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
                              Navigator.pop(context);
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


