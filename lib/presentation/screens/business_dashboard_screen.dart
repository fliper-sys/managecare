import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/business_logic_provider.dart';
import '../../providers/business_provider.dart';

// Industry providers used for refresh and logout actions
import '../../providers/pharmacy_provider.dart';
import '../../providers/retail_provider.dart';
import '../../providers/drink_provider.dart';
import '../../providers/hotel_provider.dart';
import '../../providers/agri_provider.dart';
import 'package:business_manager/presentation/industry_specific/salon/providers/salon_provider.dart';
import '../../providers/gym_provider.dart';
import '../../providers/auto_provider.dart';
import '../../providers/apartment_provider.dart';
import '../industry_specific/realestate/providers/real_estate_provider.dart';
import '../../core/utils/context_extensions.dart';
import '../industry_specific/realestate/providers/real_estate_provider.dart' as re;
import '../industry_specific/restaurant/providers/restaurant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/routes.dart';

/// Main Business Dashboard - Shows all industry operations
class BusinessDashboardScreen extends StatefulWidget {
  final String businessId;
  final String businessType;

  const BusinessDashboardScreen({
    required this.businessId,
    required this.businessType,
    super.key,
  });

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize business logic provider with current business
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusinessLogicProvider>().setBusinessContext(
            widget.businessId,
            widget.businessType,
          );
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await context.read<AuthProvider>().logout();
      if (context.mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  Future<void> _refreshAll(BusinessLogicProvider provider) async {
    final type = provider.currentIndustryType.toLowerCase();
    try {
      switch (type) {
        case 'pharmacy':
          await Future.sync(() => context.read<PharmacyProvider>().setBusinessId(widget.businessId));
          break;
        case 'retail':
          await Future.sync(() => context.read<RetailProvider>().setBusinessId(widget.businessId));
          break;
        case 'drink':
        case 'bar':
          await Future.sync(() => context.read<DrinkProvider>().setBusinessId(widget.businessId));
          break;
        case 'restaurant':
          await Future.sync(() => context.read<RestaurantProvider>().setBusinessId(widget.businessId));
          break;
        case 'hotel':
          await Future.sync(() => context.read<HotelProvider>().setBusinessId(widget.businessId));
          break;
        case 'agriculture':
        case 'agri':
          await Future.sync(() => context.read<AgriProvider>().setBusinessId(widget.businessId));
          break;
        case 'salon':
          await Future.sync(() => context.read<SalonProvider>().setBusinessId(widget.businessId));
          break;
        case 'gym':
          await Future.sync(() => context.read<GymProvider>().setBusinessId(widget.businessId));
          break;
        case 'auto':
        case 'autorepair':
          await Future.sync(() => context.read<AutoProvider>().setBusinessId(widget.businessId));
          break;
        case 'realestate':
        case 'real_estate':
          final prov = context.tryRead<RealEstateProvider>();
          if (prov != null) {
            await Future.sync(() => prov.setBusinessId(widget.businessId));
          }
          // no-op for unknown industry
          break;
        case 'apartment':
          await Future.sync(
            () => context.read<ApartmentProvider>().loadApartments(widget.businessId),
          );
          break;
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Dashboard'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Consumer<BusinessLogicProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => _refreshAll(provider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Business Info Header
                  _buildBusinessHeader(context, provider),
                  // Industry-specific operations
                  _buildIndustryContent(context, provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusinessHeader(
      BuildContext context, BusinessLogicProvider provider) {
    final business = context.read<BusinessProvider>().currentBusiness;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            business?.name ?? 'Business',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  provider.currentIndustryType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (provider.isLoading) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndustryContent(
      BuildContext context, BusinessLogicProvider provider) {
    final industryType = provider.currentIndustryType.toLowerCase();

    switch (industryType) {
      case 'pharmacy':
        return _buildPharmacyContent(context, provider);
      case 'restaurant':
      case 'bar':
      case 'drink':
        return _buildRestaurantContent(context, provider);
      case 'salon':
        return _buildSalonContent(context, provider);
      case 'realestate':
      case 'real_estate':
        return _buildRealEstateContent(context, provider);
      case 'auto':
      case 'autorepair':
      case 'auto_repair':
        return _buildAutoRepairContent(context, provider);
      case 'agriculture':
      case 'farm':
      case 'farming':
        return _buildAgricultureContent(context, provider);
      case 'retail':
      case 'shop':
      case 'store':
        return _buildRetailContent(context, provider);
      case 'gym':
      case 'fitness':
      case 'health':
        return _buildGymContent(context, provider);
      default:
        return _buildGenericContent(context, provider);
    }
  }

  // ==================== PHARMACY DASHBOARD ====================
  Widget _buildPharmacyContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Drug Management'),
          _buildActionCard(
            title: 'Check Drug Interactions',
            icon: Icons.health_and_safety,
            onTap: () async {
              final interactions = await provider
                  .checkDrugInteractions(['aspirin', 'ibuprofen']);
              if (interactions.isNotEmpty) {
                _showSnackbar(
                    'Found ${interactions.length} potential interactions');
              }
            },
          ),
          _buildActionCard(
            title: 'Expiring Medications (30 days)',
            icon: Icons.schedule,
            onTap: () async {
              final expiring = await provider.getExpiringMedications(30);
              _showSnackbar('${expiring.length} medications expiring soon');
            },
          ),
          _buildActionCard(
            title: 'Generate Prescription Report',
            icon: Icons.description,
            onTap: () async {
              final report = await provider.generatePrescriptionReport();
              if (report != null) {
                _showSnackbar(
                    'Report generated: ${report.totalPrescriptions} records');
              }
            },
          ),
        ],
      ),
    );
  }

  // ==================== RESTAURANT DASHBOARD ====================
  Widget _buildRestaurantContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Operations'),
          _buildActionCard(
            title: 'Check Queue Status',
            icon: Icons.people,
            onTap: () async {
              final queue = await provider.getQueueStatus();
              if (queue != null) {
                _showSnackbar(
                    'Queue: ${queue.estimatedWaitTimeMinutes} min (${queue.totalInQueue} waiting)');
              }
            },
          ),
          _buildActionCard(
            title: 'Analyze Peak Hours',
            icon: Icons.bar_chart,
            onTap: () async {
              final startDate =
                  DateTime.now().subtract(const Duration(days: 7));
              final endDate = DateTime.now();
              final analysis =
                  await provider.analyzePeakHours(startDate, endDate);
              if (analysis != null && analysis.peakHours.isNotEmpty) {
                final peakHour = analysis.peakHours.first;
                _showSnackbar(
                    'Peak hour: ${peakHour.hour}:00 (${peakHour.orderCount} orders)');
              }
            },
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Menu'),
          _buildActionCard(
            title: 'Get Menu Recommendations',
            icon: Icons.restaurant_menu,
            onTap: () async {
              final recommendations =
                  await provider.getMenuRecommendations('customer-123');
              _showSnackbar('${recommendations.length} recommendations');
            },
          ),
        ],
      ),
    );
  }

  // ==================== SALON DASHBOARD ====================
  Widget _buildSalonContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Appointments'),
          _buildActionCard(
            title: 'View Available Slots',
            icon: Icons.calendar_today,
            onTap: () async {
              final slots = await provider.getAvailableTimeSlots(
                  DateTime.now(), 'service-1');
              _showSnackbar('${slots.length} slots available today');
            },
          ),
          _buildActionCard(
            title: 'Check Stylist Availability',
            icon: Icons.person_2,
            onTap: () async {
              final availability = await provider.getStylistAvailability(
                  'service-1', DateTime.now());
              if (availability.isNotEmpty) {
                final availableStylists =
                    availability.where((a) => a.isAvailable).length;
                _showSnackbar('Stylists available: $availableStylists');
              }
            },
          ),
        ],
      ),
    );
  }

  // ==================== REAL ESTATE DASHBOARD ====================
  Widget _buildRealEstateContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Properties'),
          _buildActionCard(
            title: 'View Lease Status',
            icon: Icons.apartment,
            onTap: () async {
              try {
                final reProv = context.tryRead<re.RealEstateProvider>();
                if (reProv == null) {
                  _showSnackbar('Service not available. Try again.');
                  return;
                }
                if (reProv.properties.isEmpty) {
                  _showSnackbar('No properties available. Please add a property first.');
                  return;
                }
                final property = reProv.properties.first;
                final lease = await provider.getLeaseStatus(property.id);
                if (lease != null) {
                  _showSnackbar('Lease status for "${property.title}": ${lease.status}');
                } else {
                  _showSnackbar('No lease information for "${property.title}"');
                }
              } catch (e) {
                _showSnackbar('Could not load lease status: $e');
              }
            },
          ),
          _buildActionCard(
            title: 'Maintenance Requests',
            icon: Icons.build,
            onTap: () async {
              try {
                final reProv = context.tryRead<re.RealEstateProvider>();
                if (reProv == null) {
                  _showSnackbar('Service not available. Try again.');
                  return;
                }
                if (reProv.properties.isEmpty) {
                  _showSnackbar('No properties available. Please add a property first.');
                  return;
                }
                final propertyId = reProv.properties.first.id;
                final requests = await provider.getMaintenanceRequests(propertyId);
                _showSnackbar('${requests.length} requests pending');
              } catch (e) {
                _showSnackbar('Could not load maintenance requests: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  // ==================== AUTO REPAIR DASHBOARD ====================
  Widget _buildAutoRepairContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Service Management'),
          _buildActionCard(
            title: 'View Active Jobs',
            icon: Icons.settings,
            onTap: () async {
              final jobs = await provider.getActiveJobs();
              _showSnackbar('${jobs.length} jobs in progress');
            },
          ),
          _buildActionCard(
            title: 'Service History',
            icon: Icons.history,
            onTap: () async {
              final history =
                  await provider.getVehicleServiceHistory('vehicle-123');
              _showSnackbar('${history.length} previous services');
            },
          ),
          _buildActionCard(
            title: 'Maintenance Schedule',
            icon: Icons.schedule,
            onTap: () async {
              final schedule =
                  await provider.getMaintenanceSchedule('vehicle-123');
              if (schedule != null) {
                _showSnackbar(
                    'Days until oil change: ${schedule.daysUntilOilChange}');
              }
            },
          ),
        ],
      ),
    );
  }

  // ==================== AGRICULTURE DASHBOARD ====================
  Widget _buildAgricultureContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Farm Operations'),
          _buildActionCard(
            title: 'Crop Health Status',
            icon: Icons.grass,
            onTap: () async {
              final healthList = await provider.getCropHealthStatus('farm-123');
              if (healthList.isNotEmpty) {
                double sum = 0.0;
                for (final h in healthList) {
                  sum += h.healthScore;
                }
                final avgHealth = sum / healthList.length;
                _showSnackbar('Avg Health: ${avgHealth.toStringAsFixed(1)}%');
              }
            },
          ),
          _buildActionCard(
            title: 'Harvest Prediction',
            icon: Icons.calendar_today,
            onTap: () async {
              final prediction = await provider.predictHarvestTime('crop-123');
              if (prediction != null) {
                _showSnackbar(
                    'Ready: ${prediction.readiness.toStringAsFixed(1)}%');
              }
            },
          ),
          _buildActionCard(
            title: 'Livestock Records',
            icon: Icons.pets,
            onTap: () async {
              final records = await provider.getLivestockRecords('animal-123');
              _showSnackbar('${records.length} health records');
            },
          ),
        ],
      ),
    );
  }

  // ==================== RETAIL DASHBOARD ====================
  Widget _buildRetailContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Inventory Management'),
          _buildActionCard(
            title: 'Supplier Performance',
            icon: Icons.local_shipping,
            onTap: () async {
              final performance = await provider.getSupplierPerformance();
              _showSnackbar('${performance.length} suppliers tracked');
            },
          ),
          _buildActionCard(
            title: 'Wholesale Orders',
            icon: Icons.inventory_2,
            onTap: () async {
              final orders = await provider.getWholesaleOrders();
              _showSnackbar('${orders.length} orders');
            },
          ),
          _buildActionCard(
            title: 'Inventory Turnover',
            icon: Icons.analytics,
            onTap: () async {
              final turnover = await provider.calculateInventoryTurnover(
                DateTime.now().subtract(const Duration(days: 90)),
                DateTime.now(),
              );
              if (turnover != null) {
                _showSnackbar(
                    'Ratio: ${turnover.turnoverRatio.toStringAsFixed(2)}');
              }
            },
          ),
          _buildActionCard(
            title: 'Store Traffic Analysis',
            icon: Icons.bar_chart,
            onTap: () async {
              final traffic = await provider.analyzeStoreTraffic(
                DateTime.now().subtract(const Duration(days: 30)),
                DateTime.now(),
              );
              if (traffic != null) {
                _showSnackbar(
                    'Peak: ${traffic.peakHour}:00 (${traffic.totalTransactions} transactions)');
              }
            },
          ),
        ],
      ),
    );
  }

  // ==================== GYM DASHBOARD ====================
  Widget _buildGymContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Member Management'),
          _buildActionCard(
            title: 'Member Details',
            icon: Icons.person,
            onTap: () async {
              final details = await provider.getMembershipDetails('member-123');
              if (details != null) {
                _showSnackbar(
                    '${details.memberName}: ${details.membershipType}');
              }
            },
          ),
          _buildActionCard(
            title: 'Class Schedule',
            icon: Icons.schedule,
            onTap: () async {
              final classes = await provider.getClassSchedule(
                DateTime.now(),
                DateTime.now().add(const Duration(days: 7)),
              );
              _showSnackbar('${classes.length} classes this week');
            },
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Billing'),
          _buildActionCard(
            title: 'Member Billing',
            icon: Icons.receipt,
            onTap: () async {
              final billing = await provider.calculateMemberBilling(
                  'member-123', DateTime.now());
              if (billing != null) {
                _showSnackbar(
                    'Total: \$${billing.totalBilling.toStringAsFixed(2)}');
              }
            },
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Analytics'),
          _buildActionCard(
            title: 'Member Engagement',
            icon: Icons.trending_up,
            onTap: () async {
              final analysis =
                  await provider.analyzeMemberEngagement('member-123', 3);
              if (analysis != null) {
                _showSnackbar(
                    'Score: ${analysis.engagementScore}/100 - ${analysis.retentionStatus}');
              }
            },
          ),
        ],
      ),
    );
  }

  // ==================== GENERIC DASHBOARD ====================
  Widget _buildGenericContent(
      BuildContext context, BusinessLogicProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.business,
            size: 64,
            color: Colors.blue.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Industry: ${provider.currentIndustryType}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          Text(
            'Select an action from the menu to get started',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.blue.shade700,
          size: 28,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward, size: 20, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

