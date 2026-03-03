import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/barber_shop_provider.dart';
import '../../../../providers/business_provider.dart';

class BarberShopServicesScreen extends StatefulWidget {
  final bool openCreate;
  const BarberShopServicesScreen({super.key, this.openCreate = false});

  @override
  State<BarberShopServicesScreen> createState() =>
      _BarberShopServicesScreenState();
}

class _BarberShopServicesScreenState extends State<BarberShopServicesScreen> {
  String _categoryFilter = 'all';
  VoidCallback? _businessListener;
  bool _openCreatePending = false;

  @override
  void initState() {
    super.initState();
    _openCreatePending = widget.openCreate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Try to set the business id on the provider if we have a current business
      final bp = context.read<BusinessProvider>();
      final current = bp.currentBusiness;
      final barberProv = context.read<BarberShopProvider>();

      if (current != null) {
        barberProv.setBusinessId(current.id);
        // If route wants to open create, do it now
        if (_openCreatePending) {
          _openCreatePending = false;
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _showServiceDialog(context);
          });
        }
      } else {
        // Listen for business changes and set the id once available
        _businessListener = () {
          final later = bp.currentBusiness;
          if (later != null) {
            barberProv.setBusinessId(later.id);
            if (_openCreatePending) {
              _openCreatePending = false;
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _showServiceDialog(context);
              });
            }
            // remove listener after business is set
            if (_businessListener != null) bp.removeListener(_businessListener!);
          }
        };
        bp.addListener(_businessListener!);
      }
    });
  }

  @override
  void dispose() {
    final bp = context.read<BusinessProvider>();
    if (_businessListener != null) bp.removeListener(_businessListener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Services'),
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
                _showServiceDialog(context);
              })
        ],
      ),
      body: Consumer<BarberShopProvider>(
        builder: (context, provider, _) {
          var services = provider.services;
          if (_categoryFilter != 'all') {
            services =
                services.where((s) => s.category == _categoryFilter).toList();
          }

          final categories = [
            'all',
            'haircut',
            'beard',
            'shaving',
            'coloring',
            'styling'
          ];

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: categories
                      .map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat.toUpperCase()),
                              selected: _categoryFilter == cat,
                              onSelected: (_) =>
                                  setState(() => _categoryFilter = cat),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Expanded(
                child: services.isEmpty
                    ? provider.errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Error: ${provider.errorMessage}', style: AppTextStyles.body2.copyWith(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: provider.loadServices, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : const Center(
                            child: Text('No services', style: AppTextStyles.body2))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
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

  void _showServiceDialog(BuildContext context, [BarberShopService? service]) {
    showDialog(
      context: context,
      builder: (context) => _ServiceDialog(
        provider: context.read<BarberShopProvider>(),
        service: service,
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final BarberShopService service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard(
      {required this.service, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.bold)),
                Text(service.description,
                    style: AppTextStyles.body2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(service.category,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.primary)),
                    ),
                    const SizedBox(width: 8),
                    Text('${service.durationMinutes}min',
                        style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₦${service.price.toStringAsFixed(0)}',
                  style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                      onTap: onEdit,
                      child:
                          const Icon(Icons.edit, size: 18, color: Colors.blue)),
                  const SizedBox(width: 12),
                  GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete,
                          size: 18, color: Colors.red)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  final BarberShopProvider provider;
  final BarberShopService? service;

  const _ServiceDialog({required this.provider, this.service});

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _durationCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.service?.name ?? '');
    _descCtrl = TextEditingController(text: widget.service?.description ?? '');
    _priceCtrl =
        TextEditingController(text: widget.service?.price.toString() ?? '');
    _durationCtrl = TextEditingController(
        text: widget.service?.durationMinutes.toString() ?? '30');
    _category = widget.service?.category ?? 'haircut';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.service == null ? 'New Service' : 'Edit Service'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Service Name')),
          const SizedBox(height: 12),
          TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price')),
          const SizedBox(height: 12),
          TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration (mins)')),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: _category,
            isExpanded: true,
            items: ['haircut', 'beard', 'shaving', 'coloring', 'styling']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            // Basic validation
            final price = double.tryParse(_priceCtrl.text);
            final duration = int.tryParse(_durationCtrl.text);
            if (price == null || duration == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter valid numeric values for price and duration')),
              );
              return;
            }

            final service = BarberShopService(
              id: widget.service?.id ?? 'svc_${DateTime.now().millisecondsSinceEpoch}',
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              price: price,
              durationMinutes: duration,
              category: _category,
              createdAt: widget.service?.createdAt ?? DateTime.now(),
            );

            if (widget.service == null) {
              await widget.provider.addService(service);
            } else {
              await widget.provider.updateService(service);
            }

            // If provider reported an error (e.g., no business selected), show it and keep dialog open
            if (widget.provider.errorMessage != null && widget.provider.errorMessage!.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(widget.provider.errorMessage!)),
              );
              return;
            }

            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

