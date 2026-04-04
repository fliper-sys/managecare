import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/salon_provider.dart';

class SalonStaffManagementScreen extends StatefulWidget {
  const SalonStaffManagementScreen({super.key});

  @override
  State<SalonStaffManagementScreen> createState() =>
      _SalonStaffManagementScreenState();
}

class _SalonStaffManagementScreenState
    extends State<SalonStaffManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SalonProvider>();
      provider.loadStylists();
      provider.loadServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stylists'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showStylistDialog(context),
          ),
        ],
      ),
      body: Consumer<SalonProvider>(
        builder: (context, provider, _) {
          final stylists = provider.stylists;

          return stylists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 64, color: AppColors.border),
                      const SizedBox(height: 16),
                      Text('No stylists',
                          style: AppTextStyles.body1
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: 'Add Stylist',
                        backgroundColor: AppColors.primary,
                        onPressed: () => _showStylistDialog(context),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: stylists.length,
                  itemBuilder: (context, index) {
                    final stylist = stylists[index];
                    return _StylistCard(
                      stylist: stylist,
                      onEdit: () => _showStylistDialog(context, stylist),
                    );
                  },
                );
        },
      ),
    );
  }

  void _showStylistDialog(BuildContext context, [Stylist? stylist]) {
    showDialog(
      context: context,
      builder: (context) => _StylistDialog(
        stylist: stylist,
        provider: context.read<SalonProvider>(),
      ),
    );
  }
}

class _StylistCard extends StatelessWidget {
  final Stylist stylist;
  final VoidCallback onEdit;

  const _StylistCard({
    required this.stylist,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stylist.name,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${stylist.id}',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit,
                      size: 18, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('Specialization', style: AppTextStyles.body2),
                      const SizedBox(height: 4),
                      Text(
                        stylist.specialization,
                        style: AppTextStyles.body1
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('Commission %', style: AppTextStyles.body2),
                      const SizedBox(height: 4),
                      Text(
                        '${stylist.commissionPercentage?.toStringAsFixed(0) ?? '0'}%',
                        style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stylist.serviceIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Services', style: AppTextStyles.body2),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stylist.serviceIds
                        .map((serviceId) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                serviceId,
                                style: AppTextStyles.body2
                                    .copyWith(color: AppColors.primary),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StylistDialog extends StatefulWidget {
  final Stylist? stylist;
  final SalonProvider provider;

  const _StylistDialog({
    this.stylist,
    required this.provider,
  });

  @override
  State<_StylistDialog> createState() => _StylistDialogState();
}

class _StylistDialogState extends State<_StylistDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _specializationCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _commissionCtrl;
  List<String> _selectedServices = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.stylist?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.stylist?.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.stylist?.phone ?? '');
    _specializationCtrl =
        TextEditingController(text: widget.stylist?.specialization ?? '');
    _commissionCtrl = TextEditingController(
        text: widget.stylist?.commissionPercentage?.toStringAsFixed(0) ?? '15');
    _selectedServices = widget.stylist?.serviceIds ?? [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _specializationCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStylist() async {
    final stylist = Stylist(
      id: widget.stylist?.id ??
          'stylist_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
      specialization: _specializationCtrl.text,
      serviceIds: _selectedServices,
      commissionPercentage: double.parse(_commissionCtrl.text),
      createdAt: widget.stylist?.createdAt ?? DateTime.now(),
    );

    if (widget.stylist == null) {
      await widget.provider.addStylist(stylist);
    } else {
      await widget.provider.updateStylist(stylist);
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Stylist ${widget.stylist == null ? 'added' : 'updated'}')),
      );
    }
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
              Text(
                widget.stylist == null ? 'Add Stylist' : 'Edit Stylist',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _specializationCtrl,
                decoration: InputDecoration(
                  labelText:
                      'Specialization (e.g., Braiding, Coloring, Extensions)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commissionCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Commission %',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Assign Services', style: AppTextStyles.body1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.provider.services
                    .map((service) => FilterChip(
                          label: Text(service.name),
                          selected: _selectedServices.contains(service.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedServices.add(service.id);
                              } else {
                                _selectedServices.remove(service.id);
                              }
                            });
                          },
                        ))
                    .toList(),
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
                      text: widget.stylist == null ? 'Add' : 'Update',
                      backgroundColor: AppColors.primary,
                      onPressed: _nameCtrl.text.isEmpty ||
                              _emailCtrl.text.isEmpty ||
                              _specializationCtrl.text.isEmpty
                          ? null
                          : () {
                              _saveStylist();
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
