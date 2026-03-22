import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/routes.dart';
import '../providers/real_estate_provider.dart';
import '../widgets/property_form.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;

  const PropertyDetailsScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  Property? _property;
  bool _isLoading = true;
  String _errorMessage = '';
  List<RentPayment> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadProperty();
  }

  Future<void> _loadProperty() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final provider = context.read<RealEstateProvider>();
      _property = await provider.getPropertyById(widget.propertyId);

      // Load payment history for this property
      if (_property != null) {
        await _loadPaymentHistory();
      }

      if (_property == null) {
        _errorMessage = 'Property not found';
      }
    } catch (e) {
      _errorMessage = 'Error loading property: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPaymentHistory() async {
    try {
      final provider = context.read<RealEstateProvider>();
      final payments = provider.rentPayments.where((payment) {
        // Find lease for this property and check if payment belongs to it
        final lease = provider.leases.firstWhere(
          (lease) => lease.propertyId == widget.propertyId && lease.id == payment.leaseId,
          orElse: () => Lease.empty(),
        );
        return lease.id.isNotEmpty;
      }).toList();

      payments.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      _paymentHistory = payments;
    } catch (e) {
      // Ignore payment history loading errors
    }
  }

  Future<void> _editProperty() async {
    if (_property == null) return;

    final provider = context.read<RealEstateProvider>();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Property',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PropertyForm(
                  initial: _property,
                  provider: provider,
                  submitText: 'Update Property',
                  onSubmit: (property) async {
                    try {
                      await provider.updateProperty(property);
                      if (mounted) {
                        Navigator.pop(context);
                        // Reload property details
                        await _loadProperty();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Property updated successfully'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating property: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareProperty() async {
    if (_property == null) return;

    // Format property details for sharing
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final propertyDetails = '''
🏠 *${_property!.title}*

📍 *Location:* ${_property!.location}
🏷️ *Price:* ${currencyFormatter.format(_property!.price)}
🏠 *Type:* ${_property!.propertyType.toUpperCase()}
📐 *Area:* ${_property!.area.toStringAsFixed(0)} m²

🛏️ *Bedrooms:* ${_property!.bedrooms}
🚿 *Bathrooms:* ${_property!.bathrooms}
🅿️ *Parking:* ${_property!.parking}

${_property!.description.isNotEmpty ? '📝 *Description:*\n${_property!.description}\n' : ''}

${_property!.amenities.isNotEmpty ? '✨ *Amenities:* ${_property!.amenities.join(', ')}\n' : ''}

${_property!.imageUrls.isNotEmpty ? '🖼️ *Property Image:* ${_property!.imageUrls.first}\n' : ''}

📞 Contact us for more details!
    '''.trim();

    // Show share options
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share via...'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await Share.share(
                    propertyDetails,
                    subject: 'Check out this property: ${_property!.title}',
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to share: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Share to WhatsApp'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final encodedMessage = Uri.encodeComponent(propertyDetails);
                  final whatsappUrl = 'whatsapp://send?text=$encodedMessage';

                  if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                    await launchUrl(Uri.parse(whatsappUrl));
                  } else {
                    // Fallback to general share
                    await Share.share(
                      propertyDetails,
                      subject: 'Check out this property: ${_property!.title}',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to share to WhatsApp: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Property Details'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty || _property == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Property Details'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage.isNotEmpty ? _errorMessage : 'Property not found',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProperty,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _buildPropertyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: _property!.imageUrls.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _property!.imageUrls.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 50),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _property!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _property!.location,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Container(
                color: AppColors.primary,
                child: const Center(
                  child: Icon(Icons.home, size: 80, color: Colors.white),
                ),
              ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareProperty,
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: _editProperty,
        ),
      ],
    );
  }

  Widget _buildPropertyContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                NumberFormat.currency(symbol: '₦', decimalDigits: 0)
                    .format(_property!.price),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(_property!.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _property!.status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Property Type and Area
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _property!.propertyType.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_property!.area.toStringAsFixed(0)} m²',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Key Features
          _buildKeyFeatures(),

          const SizedBox(height: 24),

          // Description
          if (_property!.description.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _property!.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Amenities
          if (_property!.amenities.isNotEmpty) ...[
            const Text(
              'Amenities',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _property!.amenities.map((amenity) {
                return Chip(
                  label: Text(amenity),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  labelStyle: TextStyle(color: AppColors.primary),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Agent Information
          if (_property!.agentName != null) ...[
            const Text(
              'Listed by',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _property!.agentName![0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _property!.agentName!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Real Estate Agent',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone),
                    onPressed: () {
                      // TODO: Implement call functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Call functionality coming soon')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.message),
                    onPressed: () {
                      // TODO: Implement message functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message functionality coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Property Images Gallery
          if (_property!.imageUrls.length > 1) ...[
            const Text(
              'Property Images',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _property!.imageUrls.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: _property!.imageUrls[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.realEstateLeases);
                  },
                  icon: const Icon(Icons.assignment),
                  label: const Text('Create Lease'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to maintenance screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Maintenance scheduling coming soon')),
                    );
                  },
                  icon: const Icon(Icons.build),
                  label: const Text('Schedule Maintenance'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Payment History Section
          if (_paymentHistory.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      Routes.realEstatePropertyRentHistory,
                      arguments: {'propertyId': widget.propertyId},
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paymentHistory.length,
              itemBuilder: (context, index) {
                final payment = _paymentHistory[index];
                final provider = context.watch<RealEstateProvider>();
                final tenant = provider.tenants.firstWhere(
                  (t) => t.id == payment.tenantId,
                  orElse: () => Tenant.empty(),
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPaymentStatusColor(payment.status),
                      child: Icon(
                        _getPaymentStatusIcon(payment.status),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      '₦${payment.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Due: ${DateFormat('MMM dd, yyyy').format(payment.dueDate)}',
                          style: TextStyle(
                            color: payment.status == 'overdue' ? Colors.red : Colors.grey[600],
                          ),
                        ),
                        if (payment.paidDate != null)
                          Text(
                            'Paid: ${DateFormat('MMM dd, yyyy').format(payment.paidDate!)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        if (tenant.id.isNotEmpty)
                          Text(
                            'Tenant: ${tenant.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPaymentStatusColor(payment.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment.status.toUpperCase(),
                        style: TextStyle(
                          color: _getPaymentStatusColor(payment.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          // Summary Statistics
          if (_paymentHistory.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Total Received',
                        '₦${_paymentHistory.where((p) => p.status == 'paid').fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(0)}',
                        Colors.green,
                      ),
                      _buildSummaryItem(
                        'Pending',
                        '₦${_paymentHistory.where((p) => p.status == 'pending').fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(0)}',
                        Colors.orange,
                      ),
                      _buildSummaryItem(
                        'Overdue',
                        '${_paymentHistory.where((p) => p.status == 'overdue').length}',
                        Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'overdue':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  Widget _buildKeyFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFeatureItem(
            icon: Icons.king_bed,
            label: '${_property!.bedrooms}',
            subtitle: 'Bedrooms',
          ),
          _buildFeatureItem(
            icon: Icons.bathtub,
            label: '${_property!.bathrooms}',
            subtitle: 'Bathrooms',
          ),
          _buildFeatureItem(
            icon: Icons.directions_car,
            label: '${_property!.parking}',
            subtitle: 'Parking',
          ),
          _buildFeatureItem(
            icon: Icons.square_foot,
            label: '${_property!.area.toStringAsFixed(0)}',
            subtitle: 'm²',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return Column(
      children: [
        Icon(icon, size: 28, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'rented':
        return Colors.blue;
      case 'sold':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

