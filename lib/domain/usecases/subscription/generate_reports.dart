import '../usecase.dart';

/// Generate comprehensive business reports
class GenerateReportUseCase
    extends UseCase<BusinessReport, GenerateReportParams> {
  @override
  Future<BusinessReport> call(GenerateReportParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class GenerateReportParams {
  final String businessId;
  final String reportType; // sales, inventory, financial, customer, performance
  final DateTime startDate;
  final DateTime endDate;
  final String? groupBy; // daily, weekly, monthly, category

  GenerateReportParams({
    required this.businessId,
    required this.reportType,
    required this.startDate,
    required this.endDate,
    this.groupBy,
  });
}

class BusinessReport {
  final String reportType;
  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, dynamic> metrics;
  final List<ChartData> chartData;
  final List<String> insights;

  BusinessReport({
    required this.reportType,
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.metrics,
    required this.chartData,
    required this.insights,
  });
}

class ChartData {
  final String label;
  final double value;
  final String? category;

  ChartData({required this.label, required this.value, this.category});
}

/// Calculate financial metrics
class CalculateFinancialMetricsUseCase
    extends UseCase<FinancialMetrics, String> {
  @override
  Future<FinancialMetrics> call(String businessId) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class FinancialMetrics {
  final double totalRevenue;
  final double totalExpenses;
  final double grossProfit;
  final double profitMargin;
  final double roi;
  final double avgOrderValue;
  final double avgTransactionValue;
  final DateTime calculatedAt;

  FinancialMetrics({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.grossProfit,
    required this.profitMargin,
    required this.roi,
    required this.avgOrderValue,
    required this.avgTransactionValue,
    required this.calculatedAt,
  });
}

/// Get KPI dashboard
class GetKPIDashboardUseCase extends UseCase<KPIDashboard, String> {
  @override
  Future<KPIDashboard> call(String businessId) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class KPIDashboard {
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final int todayTransactions;
  final int activeCustomers;
  final double conversionRate;
  final double customerRetentionRate;
  final int growthPercentage;
  final Map<String, dynamic> topPerformers;

  KPIDashboard({
    required this.todayRevenue,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.todayTransactions,
    required this.activeCustomers,
    required this.conversionRate,
    required this.customerRetentionRate,
    required this.growthPercentage,
    required this.topPerformers,
  });
}

/// Export data for external analysis
class ExportDataUseCase extends UseCase<String, ExportDataParams> {
  @override
  Future<String> call(ExportDataParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class ExportDataParams {
  final String businessId;
  final String format; // csv, json, pdf
  final String dataType; // sales, customers, inventory, transactions
  final DateTime startDate;
  final DateTime endDate;

  ExportDataParams({
    required this.businessId,
    required this.format,
    required this.dataType,
    required this.startDate,
    required this.endDate,
  });
}

