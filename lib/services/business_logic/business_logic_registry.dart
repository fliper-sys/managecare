/// Central registry for all business logic services
/// Provides industry-specific business logic engines
library;

import 'pharmacy_logic.dart';
import 'restaurant_logic.dart';
import 'salon_logic.dart';
import 'realestate_logic.dart';
import 'auto_repair_logic.dart';
import 'agriculture_logic.dart';
import 'retail_logic.dart';
import 'gym_logic.dart';

class BusinessLogicRegistry {
  static final BusinessLogicRegistry _instance =
      BusinessLogicRegistry._internal();

  factory BusinessLogicRegistry() {
    return _instance;
  }

  BusinessLogicRegistry._internal();

  late PharmacyBusinessLogic _pharmacyLogic;
  late RestaurantBusinessLogic _restaurantLogic;
  late SalonBusinessLogic _salonLogic;
  late RealEstateBusinessLogic _realEstateLogic;
  late AutoRepairBusinessLogic _autoRepairLogic;
  late AgricultureBusinessLogic _agricultureLogic;
  late RetailBusinessLogic _retailLogic;
  late GymBusinessLogic _gymLogic;

  void initialize() {
    _pharmacyLogic = PharmacyBusinessLogic();
    _restaurantLogic = RestaurantBusinessLogic();
    _salonLogic = SalonBusinessLogic();
    _realEstateLogic = RealEstateBusinessLogic();
    _autoRepairLogic = AutoRepairBusinessLogic();
    _agricultureLogic = AgricultureBusinessLogic();
    _retailLogic = RetailBusinessLogic();
    _gymLogic = GymBusinessLogic();
  }

  /// Get pharmacy business logic
  PharmacyBusinessLogic get pharmacyLogic => _pharmacyLogic;

  /// Get restaurant business logic
  RestaurantBusinessLogic get restaurantLogic => _restaurantLogic;

  /// Get salon business logic
  SalonBusinessLogic get salonLogic => _salonLogic;

  /// Get real estate business logic
  RealEstateBusinessLogic get realEstateLogic => _realEstateLogic;

  /// Get auto repair business logic
  AutoRepairBusinessLogic get autoRepairLogic => _autoRepairLogic;

  /// Get agriculture business logic
  AgricultureBusinessLogic get agricultureLogic => _agricultureLogic;

  /// Get retail business logic
  RetailBusinessLogic get retailLogic => _retailLogic;

  /// Get gym business logic
  GymBusinessLogic get gymLogic => _gymLogic;

  /// Get business logic for any industry type
  dynamic getBusinessLogic(String industryType) {
    switch (industryType.toLowerCase()) {
      case 'pharmacy':
        return _pharmacyLogic;
      case 'restaurant':
      case 'bar':
      case 'drink':
        return _restaurantLogic;
      case 'salon':
        return _salonLogic;
      case 'realestate':
      case 'real_estate':
      case 'realstate':
        return _realEstateLogic;
      case 'auto':
      case 'autorepair':
      case 'auto_repair':
      case 'car':
      case 'garage':
        return _autoRepairLogic;
      case 'agriculture':
      case 'farm':
      case 'farming':
      case 'crops':
        return _agricultureLogic;
      case 'retail':
      case 'bakery':
      case 'shop':
      case 'store':
        return _retailLogic;
      case 'gym':
      case 'fitness':
      case 'health':
      case 'wellness':
        return _gymLogic;
      default:
        throw UnsupportedError(
            'Business logic not available for $industryType');
    }
  }

  /// Get all available industry types
  List<String> getAvailableIndustries() {
    return [
      'Pharmacy',
      'Restaurant',
      'Bar',
      'Salon',
      'Real Estate',
      'Auto Repair',
      'Agriculture',
      'Retail',
      'Bakery',
      'Gym'
    ];
  }

  /// Get metrics calculator
  BusinessMetricsCalculator getMetricsCalculator() {
    return BusinessMetricsCalculator();
  }
}

/// Business metrics calculator - common across all businesses
class BusinessMetricsCalculator {
  /// Calculate revenue metrics
  static RevenueSummary calculateRevenue(
    List<dynamic> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    double totalRevenue = 0;
    int totalTransactions = 0;
    final categoryRevenue = <String, double>{};

    for (var transaction in transactions) {
      totalRevenue += transaction.amount ?? 0;
      totalTransactions++;

      final category = transaction.category ?? 'Other';
      categoryRevenue[category] =
          (categoryRevenue[category] ?? 0) + (transaction.amount ?? 0);
    }

    final avgTransactionValue =
        totalTransactions > 0 ? totalRevenue / totalTransactions : 0;

    return RevenueSummary(
      totalRevenue: totalRevenue,
      totalTransactions: totalTransactions,
      averageTransactionValue: avgTransactionValue as double,
      categoryBreakdown: categoryRevenue,
      period: '${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
    );
  }

  /// Calculate growth rate
  static double calculateGrowthRate(
    double currentValue,
    double previousValue,
  ) {
    if (previousValue == 0) return currentValue == 0 ? 0 : 100;
    return ((currentValue - previousValue) / previousValue) * 100;
  }

  /// Calculate trend
  static String calculateTrend(double growthRate) {
    if (growthRate > 10) return 'Strongly Positive';
    if (growthRate > 0) return 'Positive';
    if (growthRate > -10) return 'Slightly Negative';
    return 'Strongly Negative';
  }
}

class RevenueSummary {
  final double totalRevenue;
  final int totalTransactions;
  final double averageTransactionValue;
  final Map<String, double> categoryBreakdown;
  final String period;

  RevenueSummary({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.averageTransactionValue,
    required this.categoryBreakdown,
    required this.period,
  });

  double get percentageChangeNeeded {
    // Calculate what percentage increase is needed to meet a growth target
    const double targetGrowthPercentage = 20;
    return (totalRevenue * (targetGrowthPercentage / 100));
  }
}

/// Common business KPIs
class BusinessKPIs {
  final double dailyRevenue;
  final double weeklyRevenue;
  final double monthlyRevenue;
  final int activeCustomers;
  final int newCustomers;
  final double averageCustomerLifetimeValue;
  final double conversionRate;
  final double repeatCustomerRate;
  final int totalOrders;
  final double avgOrderValue;

  BusinessKPIs({
    required this.dailyRevenue,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.activeCustomers,
    required this.newCustomers,
    required this.averageCustomerLifetimeValue,
    required this.conversionRate,
    required this.repeatCustomerRate,
    required this.totalOrders,
    required this.avgOrderValue,
  });

  /// Get business health status
  String getHealthStatus() {
    final revenueGrowth = (monthlyRevenue / weeklyRevenue) / 4;
    if (revenueGrowth > 1.1) return 'Excellent';
    if (revenueGrowth > 1.0) return 'Good';
    if (revenueGrowth > 0.8) return 'Fair';
    return 'Needs Attention';
  }

  /// Get actionable insights
  List<String> getInsights() {
    final insights = <String>[];

    if (conversionRate < 5) {
      insights.add(
          'Consider improving your conversion rate (currently ${conversionRate.toStringAsFixed(1)}%)');
    }

    if (repeatCustomerRate < 30) {
      insights.add(
          'Focus on customer retention - repeat customer rate is only ${repeatCustomerRate.toStringAsFixed(1)}%');
    }

    if (avgOrderValue < 50) {
      insights.add(
          'Implement upselling strategies to increase average order value');
    }

    if (newCustomers < (activeCustomers * 0.1)) {
      insights.add(
          'Launch customer acquisition campaigns - new customer acquisition is low');
    }

    return insights;
  }
}

