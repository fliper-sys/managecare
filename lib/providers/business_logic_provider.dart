import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/business_logic/business_logic_registry.dart';
import '../services/business_logic/pharmacy_logic.dart';
import '../services/business_logic/restaurant_logic.dart';
import '../services/business_logic/salon_logic.dart';
import '../services/business_logic/realestate_logic.dart';
import '../services/business_logic/auto_repair_logic.dart';
import '../services/business_logic/agriculture_logic.dart';
import '../services/business_logic/retail_logic.dart';
import '../services/business_logic/gym_logic.dart';

/// Master provider that integrates all business logic services
class BusinessLogicProvider extends ChangeNotifier {
  final BusinessLogicRegistry _registry;
  // final FirebaseFirestore _firestore;

  String _currentBusinessId = '';
  String _currentIndustryType = '';

  // Cached data for current industry
  dynamic _cachedData;
  bool _isLoading = false;
  String? _error;

  BusinessLogicProvider({
    BusinessLogicRegistry? registry,
    FirebaseFirestore? firestore,
  }) : _registry = registry ?? BusinessLogicRegistry() {
    _registry.initialize();
  }

  // Getters
  String get currentBusinessId => _currentBusinessId;
  String get currentIndustryType => _currentIndustryType;
  bool get isLoading => _isLoading;
  String? get error => _error;
  dynamic get cachedData => _cachedData;

  /// Set current business context
  void setBusinessContext(String businessId, String industryType) {
    _currentBusinessId = businessId;
    _currentIndustryType = industryType;
    _cachedData = null;
    _error = null;
    notifyListeners();
  }

  /// Get appropriate business logic for current industry
  dynamic getBusinessLogic(String? industryType) {
    try {
      final type = industryType ?? _currentIndustryType;
      return _registry.getBusinessLogic(type);
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  // ==================== PHARMACY OPERATIONS ====================

  /// Check drug interactions
  Future<List<DrugInteraction>> checkDrugInteractions(
    List<String> drugNames,
  ) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.pharmacyLogic;
      // Generate drug IDs from names for interaction checking
      final drugIds = List.generate(drugNames.length, (i) => 'drug_$i');
      final result = await logic.checkDrugInteractions(drugIds, drugNames);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get expiring medications
  Future<List<ExpiringMedication>> getExpiringMedications(int daysAhead) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.pharmacyLogic;
      final result =
          await logic.getExpiringMedications(_currentBusinessId, daysAhead);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Generate prescription report
  Future<PrescriptionReport?> generatePrescriptionReport() async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.pharmacyLogic;
      // TODO: Replace 'startDate' and 'endDate' with actual DateTime values as required by your business logic
      final result = await logic.generatePrescriptionReport(
        _currentBusinessId,
        DateTime.now()
            .subtract(const Duration(days: 30)), // Example: 30 days ago
        DateTime.now(), // Example: today
      );
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== RESTAURANT OPERATIONS ====================

  /// Get current statuus
  Future<QueueStatus?> getQueueStatus() async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.restaurantLogic;
      final result = await logic.getCurrentQueueStatus(_currentBusinessId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get menu recommendations
  Future<List<MenuRecommendation>> getMenuRecommendations(
      String customerId) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.restaurantLogic;
      final result =
          await logic.getMenuRecommendations(_currentBusinessId, customerId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Analyze peak hours
  Future<PeakHoursAnalysis?> analyzePeakHours(
      DateTime startDate, DateTime endDate) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.restaurantLogic;
      final result =
          await logic.analyzePeakHours(_currentBusinessId, startDate, endDate);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== SALON OPERATIONS ====================

  /// Get available time slots for a service on a date
  Future<List<TimeSlot>> getAvailableTimeSlots(
      DateTime date, String serviceId) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.salonLogic;
      final result = await logic.getAvailableTimeSlots(
          _currentBusinessId, date, serviceId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get stylist availability for a service on a date
  Future<List<StylistAvailability>> getStylistAvailability(
      String serviceId, DateTime date) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.salonLogic;
      final result = await logic.getStylistAvailability(
          _currentBusinessId, serviceId, date);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ==================== REAL ESTATE OPERATIONS ====================

  /// Get lease status for a specific property
  Future<LeaseStatus?> getLeaseStatus(String propertyId) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.realEstateLogic;
      final result = await logic.getLeaseStatus(_currentBusinessId, propertyId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get maintenance requests
  Future<List<MaintenanceRequest>> getMaintenanceRequests(
      String propertyId) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.realEstateLogic;
      final result =
          await logic.getMaintenanceRequests(_currentBusinessId, propertyId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Create a maintenance request
  Future<MaintenanceRequest?> createMaintenanceRequest(
      String propertyId, String description,
      {String priority = 'medium', String? assignedProviderId, String? assignedProviderName}) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);
    try {
      final logic = _registry.realEstateLogic;
      final result = await logic.createMaintenanceRequest(
          _currentBusinessId, propertyId, description,
          priority: priority, assignedProviderId: assignedProviderId, assignedProviderName: assignedProviderName);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get service providers for current business
  Future<List<ServiceProvider>> getServiceProviders() async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);
    try {
      final logic = _registry.realEstateLogic;
      final result = await logic.getServiceProviders(_currentBusinessId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ==================== AUTO REPAIR OPERATIONS ====================

  /// Get vehicle service history
  Future<List<ServiceRecord>> getVehicleServiceHistory(String vehicleId) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.autoRepairLogic;
      final result =
          await logic.getVehicleServiceHistory(_currentBusinessId, vehicleId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Calculate maintenance schedule
  Future<MaintenanceSchedule?> getMaintenanceSchedule(String vehicleId) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.autoRepairLogic;
      final result = await logic.calculateMaintenanceSchedule(
          _currentBusinessId, vehicleId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get active repair jobs
  Future<List<JobStatus>> getActiveJobs() async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.autoRepairLogic;
      final result = await logic.getActiveJobs(_currentBusinessId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ==================== AGRICULTURE OPERATIONS ====================

  /// Get crop health status for a farm
  Future<List<CropHealth>> getCropHealthStatus(String farmId) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.agricultureLogic;
      final result =
          await logic.getCropHealthStatus(_currentBusinessId, farmId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Predict harvest time
  Future<HarvestPrediction?> predictHarvestTime(String cropId) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.agricultureLogic;
      final result = await logic.predictHarvestTime(_currentBusinessId, cropId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get livestock health records
  Future<List<LivestockRecord>> getLivestockRecords(String animalId) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.agricultureLogic;
      final result =
          await logic.getLivestockHealthRecords(_currentBusinessId, animalId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ==================== RETAIL OPERATIONS ====================

  /// Get wholesale orders
  Future<List<WholesaleOrder>> getWholesaleOrders({String? status}) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.retailLogic;
      final result = await logic.getWholesaleOrders(_currentBusinessId, status);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get supplier performance
  Future<List<SupplierPerformance>> getSupplierPerformance() async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.retailLogic;
      final result = await logic.getSupplierPerformance(_currentBusinessId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Calculate inventory turnover
  Future<InventoryTurnover?> calculateInventoryTurnover(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.retailLogic;
      final result = await logic.calculateInventoryTurnover(
        _currentBusinessId,
        startDate,
        endDate,
      );
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Analyze store traffic
  Future<StoreTrafficAnalysis?> analyzeStoreTraffic(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.retailLogic;
      final result = await logic.analyzeStoreTraffic(
        _currentBusinessId,
        startDate,
        endDate,
      );
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== GYM OPERATIONS ====================

  /// Get member membership details
  Future<MembershipDetails?> getMembershipDetails(String memberId) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.gymLogic;
      final result =
          await logic.getMembershipDetails(_currentBusinessId, memberId);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get class schedule
  Future<List<ClassSchedule>> getClassSchedule(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_currentBusinessId.isEmpty) return [];
    _setLoading(true);

    try {
      final logic = _registry.gymLogic;
      final result =
          await logic.getClassSchedule(_currentBusinessId, startDate, endDate);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Calculate member billing
  Future<BillingCycle?> calculateMemberBilling(
      String memberId, DateTime month) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.gymLogic;
      final result = await logic.calculateMemberBilling(
          _currentBusinessId, memberId, month);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Analyze member engagement
  Future<MemberEngagementAnalysis?> analyzeMemberEngagement(
    String memberId,
    int monthsBack,
  ) async {
    if (_currentBusinessId.isEmpty) return null;
    _setLoading(true);

    try {
      final logic = _registry.gymLogic;
      final result = await logic.analyzeMemberEngagement(
          _currentBusinessId, memberId, monthsBack);
      _cachedData = result;
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Get all available industries
  List<String> getAvailableIndustries() {
    return _registry.getAvailableIndustries();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearCache() {
    _cachedData = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

