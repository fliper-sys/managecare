import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/salon_provider.dart';

class SalonServicesScreen extends StatefulWidget {
  const SalonServicesScreen({super.key});

  @override
  State<SalonServicesScreen> createState() => _SalonServicesScreenState();
}

class _SalonServicesScreenState extends State<SalonServicesScreen> {
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalonProvider>().loadServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'all',
      'haircut',
      'hair-color',
      'treatment',
      'styling',
      'makeup'
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Services'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showServiceDialog(context),
          ),
        ],
      ),
      body: Consumer<SalonProvider>(
        builder: (context, provider, _) {
          var services = provider.services;
          if (_selectedCategory != 'all') {
            services =
                services.where((s) => s.category == _selectedCategory).toList();
          }

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: categories
                      .map((category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CategoryChip(
                              label: category == 'all'
                                  ? 'All'
                                  : category.replaceAll('-', ' ').toUpperCase(),
                              isActive: _selectedCategory == category,
                              onTap: () =>
                                  setState(() => _selectedCategory = category),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Expanded(
                child: services.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.spa,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text('No services',
                                style: AppTextStyles.body1
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final service = services[index];
                          return _ServiceCard(
                            service: service,
                            onEdit: () => _showServiceDialog(context, service),
                            onDelete: () => provider.deleteService(service.id),
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

  void _showServiceDialog(BuildContext context, [SalonService? service]) {
    showDialog(
      context: context,
      builder: (context) => _ServiceDialog(
        service: service,
        provider: context.read<SalonProvider>(),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final SalonService service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.spa,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style:
                      AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${service.durationMinutes} min',
                  style: AppTextStyles.body2
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  formatCurrency(service.price),
                  style:
                      AppTextStyles.heading4.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.delete,
                            size: 16,
                            color: Colors.red,
                          ),
                        ),
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
}

class _ServiceDialog extends StatefulWidget {
  final SalonService? service;
  final SalonProvider provider;

  const _ServiceDialog({
    this.service,
    required this.provider,
  });

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _durationCtrl;
  String _selectedCategory = 'haircut';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.service?.name ?? '');
    _descriptionCtrl =
        TextEditingController(text: widget.service?.description ?? '');
    _priceCtrl = TextEditingController(
        text: widget.service?.price.toStringAsFixed(0) ?? '');
    _durationCtrl = TextEditingController(
        text: widget.service?.durationMinutes.toString() ?? '30');
    _selectedCategory = widget.service?.category ?? 'haircut';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveService() async {
    final service = SalonService(
      id: widget.service?.id ?? 'svc_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text,
      description: _descriptionCtrl.text,
      price: double.parse(_priceCtrl.text),
      durationMinutes: int.parse(_durationCtrl.text),
      category: _selectedCategory,
      createdAt: widget.service?.createdAt ?? DateTime.now(),
    );

    if (widget.service == null) {
      await widget.provider.addService(service);
    } else {
      await widget.provider.updateService(service);
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Service ${widget.service == null ? 'added' : 'updated'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'haircut',
      'hair-color',
      'treatment',
      'styling',
      'makeup'
    ];

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
                widget.service == null ? 'Add Service' : 'Edit Service',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Service Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price (₦)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Duration (minutes)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Category', style: AppTextStyles.body1),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                items: categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.replaceAll('-', ' ').toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
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
                      text: widget.service == null ? 'Add' : 'Update',
                      backgroundColor: AppColors.primary,
                      onPressed:
                          _nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty
                              ? null
                              : () {
                                  _saveService();
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
