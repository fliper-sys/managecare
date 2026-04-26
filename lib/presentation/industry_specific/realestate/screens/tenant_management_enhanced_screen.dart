import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/context_extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../core/constants/routes.dart';
import '../providers/real_estate_provider.dart';

class TenantManagementScreenEnhanced extends StatefulWidget {
  const TenantManagementScreenEnhanced({super.key});

  @override
  State<TenantManagementScreenEnhanced> createState() =>
      _TenantManagementScreenEnhancedState();
}

class _TenantManagementScreenEnhancedState
    extends State<TenantManagementScreenEnhanced> {
  final _searchController = TextEditingController();
  String _filterStatus = 'all'; // all, active, inactive

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.tryRead<RealEstateProvider>();
      if (prov != null) {
        prov.loadTenants();
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          final p2 = context.tryRead<RealEstateProvider>();
          p2?.loadTenants();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Tenant Management'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTenantDialog(context),
          ),
        ],
      ),
      body: Consumer<RealEstateProvider>(
        builder: (context, provider, _) {
          var tenants = provider.tenants;

          // Apply filters
          if (_filterStatus != 'all') {
            tenants = tenants.where((t) => t.status == _filterStatus).toList();
          }

          // Apply search
          if (_searchController.text.isNotEmpty) {
            tenants = tenants
                .where((t) =>
                    t.name
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase()) ||
                    t.email
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase()))
                .toList();
          }

          return Column(
            children: [
              // Search and Filter
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tenants...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Filter Chips
                    Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _filterStatus == 'all',
                          onTap: () => setState(() => _filterStatus = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Active',
                          isSelected: _filterStatus == 'active',
                          onTap: () => setState(() => _filterStatus = 'active'),
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Inactive',
                          isSelected: _filterStatus == 'inactive',
                          onTap: () =>
                              setState(() => _filterStatus = 'inactive'),
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Tenant List
              Expanded(
                child: tenants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_off,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text(
                              'No tenants found',
                              style: AppTextStyles.body1.copyWith(color: scheme.onSurface),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tenants.length,
                        itemBuilder: (context, index) => _TenantCard(
                          tenant: tenants[index],
                          onEdit: () =>
                              _showEditTenantDialog(context, tenants[index]),
                          onDelete: () => _showDeleteDialog(
                              context, tenants[index], provider),
                          onViewDocuments: () =>
                              _showDocumentsDialog(context, tenants[index]),
                          onViewRentHistory: () => _navigateToRentHistory(context, tenants[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTenantDialog(BuildContext context) {
    final provider = context.tryRead<RealEstateProvider>();
    if (provider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service not available. Try again.')));
      return;
    }
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final whatsappController = TextEditingController();
    File? selectedDocument;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Tenant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: whatsappController,
                  decoration: InputDecoration(
                    labelText: 'WhatsApp (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload Document',
                          style: AppTextStyles.body2
                              .copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (selectedDocument == null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Select Document'),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'doc', 'docx'],
                            );
                            if (result != null) {
                              setState(() => selectedDocument =
                                  File(result.files.single.path!));
                            }
                          },
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(selectedDocument!.path.split('/').last,
                                style: AppTextStyles.body2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Change Document'),
                              onPressed: () async {
                                final result =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf', 'doc', 'docx'],
                                );
                                if (result != null) {
                                  setState(() => selectedDocument =
                                      File(result.files.single.path!));
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CustomButton(
              text: 'Add Tenant',
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                String? documentUrl;
                if (selectedDocument != null) {
                  documentUrl =
                      await provider.uploadPropertyDocument(selectedDocument!);
                }

                final tenant = Tenant(
                  id: '', // Let provider generate a unique id
                  name: nameController.text,
                  email: emailController.text,
                  phone: phoneController.text,
                  whatsapp: whatsappController.text.isNotEmpty ? whatsappController.text : null,
                  propertyId: '', // Will be set when creating lease
                  leaseId: '',
                  status: 'active',
                  documentUrl: documentUrl,
                  createdAt: DateTime.now(),
                );

                await provider.addTenant(tenant);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tenant added successfully')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTenantDialog(BuildContext context, Tenant tenant) {
    final provider = context.tryRead<RealEstateProvider>();
    if (provider == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service not available. Try again.')));
      return;
    }

    final nameController = TextEditingController(text: tenant.name);
    final emailController = TextEditingController(text: tenant.email);
    final phoneController = TextEditingController(text: tenant.phone);
    final whatsappController = TextEditingController(text: tenant.whatsapp ?? '');
    String selectedStatus = tenant.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Tenant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: whatsappController,
                  decoration: InputDecoration(
                    labelText: 'WhatsApp (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedStatus = value ?? 'active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CustomButton(
              text: 'Update',
              onPressed: () async {
                final updatedTenant = Tenant(
                  id: tenant.id,
                  name: nameController.text,
                  email: emailController.text,
                  phone: phoneController.text,
                  whatsapp: whatsappController.text.isNotEmpty ? whatsappController.text : null,
                  propertyId: tenant.propertyId,
                  leaseId: tenant.leaseId,
                  status: selectedStatus,
                  documentUrl: tenant.documentUrl,
                  createdAt: tenant.createdAt,
                );

                await provider.updateTenant(updatedTenant);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Tenant updated successfully')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, Tenant tenant, RealEstateProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text('Are you sure you want to delete ${tenant.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CustomButton(
            text: 'Delete',
            onPressed: () async {
              await provider.deleteTenant(tenant.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tenant deleted successfully')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDocumentsDialog(BuildContext context, Tenant tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tenant Documents'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${tenant.name}', style: AppTextStyles.body2),
              const SizedBox(height: 8),
              Text('Email: ${tenant.email}', style: AppTextStyles.body2),
              const SizedBox(height: 8),
              Text('Phone: ${tenant.phone}', style: AppTextStyles.body2),
              const SizedBox(height: 16),
              if (tenant.documentUrl != null &&
                  tenant.documentUrl!.isNotEmpty) ...[
                Text('Documents',
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    // Open document URL
                    // In production, implement document viewer
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tenant.documentUrl!.split('/').last,
                            style: AppTextStyles.body2
                                .copyWith(color: AppColors.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Text('No documents uploaded',
                    style: AppTextStyles.body2
                        .copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72))),
            ],
          ),
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

  void _navigateToRentHistory(BuildContext context, Tenant tenant) {
    Navigator.pushNamed(
      context,
      Routes.realEstateTenantRentHistory,
      arguments: {'tenantId': tenant.id},
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FilterChip(
      label: Text(label, style: TextStyle(color: scheme.onSurface)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: theme.cardColor,
      selectedColor: (color ?? AppColors.primary).withOpacity(0.1),
      side: BorderSide(
        color: isSelected
            ? (color ?? AppColors.primary)
            : scheme.outline.withOpacity(0.28),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDocuments;
  final VoidCallback onViewRentHistory;

  const _TenantCard({
    required this.tenant,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDocuments,
    required this.onViewRentHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenant.name,
                        style: AppTextStyles.body1
                            .copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            )),
                    Text(tenant.email,
                        style: AppTextStyles.body2
                            .copyWith(color: scheme.onSurface.withOpacity(0.72))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tenant.status == 'active'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tenant.status.toUpperCase(),
                  style: TextStyle(
                    color:
                        tenant.status == 'active' ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tenant.phone,
            style: AppTextStyles.body2.copyWith(color: scheme.onSurface),
          ),
          if (tenant.documentUrl != null && tenant.documentUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.description,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Documents attached',
                    style:
                        AppTextStyles.body2.copyWith(color: AppColors.primary)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onViewRentHistory,
                icon: const Icon(Icons.history),
                label: const Text('Rent History'),
              ),
              const SizedBox(width: 4),
              if (tenant.documentUrl != null)
                TextButton.icon(
                  onPressed: onViewDocuments,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Documents'),
                ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

