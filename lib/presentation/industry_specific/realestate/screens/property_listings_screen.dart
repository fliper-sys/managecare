import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/context_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/real_estate_provider.dart';
import 'edit_property_screen.dart';

class PropertyListingsScreen extends StatefulWidget {
  const PropertyListingsScreen({super.key});

  @override
  State<PropertyListingsScreen> createState() => _PropertyListingsScreenState();
}

class _PropertyListingsScreenState extends State<PropertyListingsScreen> {
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.tryRead<RealEstateProvider>();
      if (prov != null) {
        prov.loadProperties();
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          final p2 = context.tryRead<RealEstateProvider>();
          p2?.loadProperties();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Properties'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddPropertyDialog(context)),
        ],
      ),
      body: Consumer<RealEstateProvider>(
        builder: (context, provider, _) {
          var properties = provider.properties;
          if (_statusFilter != 'all') {
            properties =
                properties.where((p) => p.status == _statusFilter).toList();
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
                        label: 'Available',
                        isActive: _statusFilter == 'available',
                        onTap: () =>
                            setState(() => _statusFilter = 'available'),
                        color: Colors.green),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Rented',
                        isActive: _statusFilter == 'rented',
                        onTap: () => setState(() => _statusFilter = 'rented'),
                        color: Colors.blue),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Sold',
                        isActive: _statusFilter == 'sold',
                        onTap: () => setState(() => _statusFilter = 'sold'),
                        color: Colors.red),
                  ],
                ),
              ),
              Expanded(
                child: properties.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Icon(Icons.home_outlined,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text('No properties',
                                style: AppTextStyles.body1
                                    .copyWith(color: AppColors.textSecondary)),
                          ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: properties.length,
                        itemBuilder: (context, index) {
                          final property = properties[index];
                          return _PropertyCard(property: property);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPropertyDialog(BuildContext context) {
    final prov = context.tryRead<RealEstateProvider>();
    if (prov != null) {
      showDialog(
        context: context,
        builder: (context) => _AddPropertyDialog(provider: prov),
      );
      return;
    }

    Future.delayed(const Duration(milliseconds: 150), () {
      final p2 = context.tryRead<RealEstateProvider>();
      if (p2 != null) {
        showDialog(
          context: context,
          builder: (context) => _AddPropertyDialog(provider: p2),
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Service not available. Try again.')));
        }
      }
    });
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
        child: Text(label,
            style: TextStyle(
                color: isActive ? Colors.white : color,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Property property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property Image
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: property.imageUrls.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: property.imageUrls[0],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildPlaceholder(),
                    errorWidget: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          // Property Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(property.title,
                              style: AppTextStyles.body1
                                  .copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(property.location,
                              style: AppTextStyles.body2
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(property.status)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            property.status.toUpperCase(),
                            style: TextStyle(
                                color: _getStatusColor(property.status),
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            final provider = context.tryRead<RealEstateProvider>();
                            if (v == 'edit') {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => EditPropertyScreen(property: property)));
                              return;
                            }

                            if (v == 'delete') {
                              final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                        title: const Text('Confirm delete'),
                                        content: const Text('Delete this property?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete'))
                                        ],
                                      ));
                              if (ok == true) {
                                if (provider == null) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service not available. Try again.')));
                                  return;
                                }
                                await provider.deleteProperty(property.id);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property deleted')));
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Property Specs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SpecItem(
                        icon: Icons.bed,
                        label: '${property.bedrooms}',
                        title: 'Beds'),
                    _SpecItem(
                        icon: Icons.bathtub,
                        label: '${property.bathrooms}',
                        title: 'Baths'),
                    _SpecItem(
                        icon: Icons.directions_car,
                        label: '${property.parking}',
                        title: 'Parking'),
                    _SpecItem(
                        icon: Icons.square_foot,
                        label: '${property.area.toStringAsFixed(0)}m²',
                        title: 'Area'),
                  ],
                ),
                const SizedBox(height: 12),
                // Price and Description
                Text('₦${property.price.toStringAsFixed(0)}',
                    style: AppTextStyles.heading3
                        .copyWith(color: AppColors.primary)),
                const SizedBox(height: 8),
                Text(property.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() => const Center(
        child: Icon(Icons.image_outlined, size: 64, color: AppColors.border),
      );

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'rented':
        return Colors.blue;
      case 'sold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _SpecItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;

  const _SpecItem(
      {required this.icon, required this.label, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold)),
        Text(title,
            style: AppTextStyles.body2
                .copyWith(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _AddPropertyDialog extends StatefulWidget {
  final RealEstateProvider provider;

  const _AddPropertyDialog({required this.provider});

  @override
  State<_AddPropertyDialog> createState() => _AddPropertyDialogState();
}

class _AddPropertyDialogState extends State<_AddPropertyDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _bedroomsCtrl;
  late TextEditingController _bathroomsCtrl;
  late TextEditingController _parkingCtrl;

  String _selectedType = 'residential';
  List<File> _selectedImages = [];
  bool _isUploading = false;
  List<double> _uploadProgress = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _areaCtrl = TextEditingController();
    _bedroomsCtrl = TextEditingController(text: '1');
    _bathroomsCtrl = TextEditingController(text: '1');
    _parkingCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _areaCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _parkingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Property', style: AppTextStyles.heading3),
              const SizedBox(height: 16),
              TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                      labelText: 'Property Title',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _locationCtrl,
                  decoration: InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              const Text('Property Type', style: AppTextStyles.body1),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                items: ['residential', 'commercial', 'land']
                    .map((type) => DropdownMenuItem(
                        value: type, child: Text(type.toUpperCase())))
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Price (₦)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _areaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Area (m²)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _bedroomsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Bedrooms',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _bathroomsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Bathrooms',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _parkingCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Parking Spaces',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 16),
              // Image Upload Section
              const Text('Property Images', style: AppTextStyles.body1),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectImages,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.border, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.image_outlined,
                          size: 48, color: AppColors.primary),
                      const SizedBox(height: 8),
                      const Text('Tap to select images',
                          style: AppTextStyles.body2),
                      if (_selectedImages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                              '${_selectedImages.length} image(s) selected',
                              style: AppTextStyles.body2
                                  .copyWith(color: AppColors.primary)),
                        ),
                      if (_selectedImages.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedImages
                              .asMap()
                              .map((i, f) => MapEntry(
                                    i,
                                    Stack(
                                      children: [
                                        ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.file(f,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover)),
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: GestureDetector(
                                            onTap: () => setState(() {
                                              _selectedImages.removeAt(i);
                                              if (_uploadProgress.length > i)
                                                _uploadProgress.removeAt(i);
                                            }),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: const Icon(Icons.close,
                                                  color: Colors.white,
                                                  size: 14),
                                            ),
                                          ),
                                        ),
                                        if (_uploadProgress.length > i)
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: _uploadProgress[i] > 0 &&
                                                    _uploadProgress[i] < 1
                                                ? Container(
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        color: Colors.black
                                                            .withOpacity(0.35)),
                                                    child: LinearProgressIndicator(
                                                        value:
                                                            _uploadProgress[i],
                                                        minHeight: 6,
                                                        backgroundColor: Colors
                                                            .white
                                                            .withOpacity(0.2),
                                                        valueColor:
                                                            const AlwaysStoppedAnimation(
                                                                AppColors
                                                                    .primary)),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                      ],
                                    ),
                                  ))
                              .values
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.provider.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8)),
                            child: Image.file(_selectedImages[index],
                                fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                        text: 'Cancel',
                        backgroundColor: AppColors.border,
                        onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: 'Create Property',
                      backgroundColor: AppColors.primary,
                      isLoading: _isUploading,
                      onPressed: _isUploading ||
                              _selectedImages.isEmpty ||
                              _titleCtrl.text.isEmpty ||
                              _priceCtrl.text.isEmpty
                          ? null
                          : () => _createProperty(),
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

  Future<void> _selectImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    setState(() {
      _selectedImages = images.map((img) => File(img.path)).toList();
      // Make the progress list growable to avoid Unsupported operation errors when adding uploads
      _uploadProgress = List<double>.filled(_selectedImages.length, 0.0, growable: true);
    });
  }

  Future<void> _createProperty() async {
    if (_titleCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill Title and Price')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      // Upload images first
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await widget.provider.uploadPropertyImages(_selectedImages,
            onProgress: (index, sent, total) {
          if (mounted) {
            setState(() {
              if (_uploadProgress.length > index) {
                _uploadProgress[index] = total > 0 ? (sent / total) : 0.0;
              }
            });
          }
        });
      }

      // Create property
      final property = Property(
        id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleCtrl.text,
        description: _descriptionCtrl.text,
        location: _locationCtrl.text,
        propertyType: _selectedType,
        price: double.parse(_priceCtrl.text),
        area: double.parse(_areaCtrl.text),
        bedrooms: int.parse(_bedroomsCtrl.text),
        bathrooms: int.parse(_bathroomsCtrl.text),
        parking: int.parse(_parkingCtrl.text),
        amenities: [],
        imageUrls: imageUrls,
        status: 'available',
        createdAt: DateTime.now(),
      );

      if (_selectedImages.isNotEmpty && imageUrls.isEmpty) {
        final err = widget.provider.errorMessage.isNotEmpty
            ? widget.provider.errorMessage
            : 'Image upload failed';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        setState(() => _isUploading = false);
        return;
      }
      await widget.provider.addProperty(property);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Property added successfully')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

