import 'package:cloud_firestore/cloud_firestore.dart';

/// Analytics data model for business metrics
class AnalyticsModel {
  final String period; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime endDate;

  // Revenue metrics
  final double totalRevenue;
  final double averageOrderValue;
  final double revenueGrowth; // percentage

  // Transaction metrics
  final int totalTransactions;
  final int transactionGrowth; // count change

  // Customer metrics
  final int newCustomers;
  final int returningCustomers;
  final double customerRetentionRate;

  // Product metrics
  final String topProductId;
  final String topProductName;
  final int topProductSales;

  // Financial metrics
  final double totalCogs; // cost of goods sold for the period
  final double grossProfit; // totalRevenue - totalCogs

  // Worker metrics
  final String topWorkerId;
  final String topWorkerName;
  final double topWorkerSales;

  // Time metrics
  final DateTime createdAt;
  final DateTime updatedAt;

  AnalyticsModel({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.revenueGrowth,
    required this.totalTransactions,
    required this.transactionGrowth,
    required this.newCustomers,
    required this.returningCustomers,
    required this.customerRetentionRate,
    required this.topProductId,
    required this.topProductName,
    required this.topProductSales,
    required this.totalCogs,
    required this.grossProfit,
    required this.topWorkerId,
    required this.topWorkerName,
    required this.topWorkerSales,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsModel(
      period: json['period'] ?? 'daily',
      startDate: json['startDate'] is Timestamp
          ? (json['startDate'] as Timestamp).toDate()
          : json['startDate'] is DateTime
              ? json['startDate']
              : DateTime.now(),
      endDate: json['endDate'] is Timestamp
          ? (json['endDate'] as Timestamp).toDate()
          : json['endDate'] is DateTime
              ? json['endDate']
              : DateTime.now(),
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0.0,
      revenueGrowth: (json['revenueGrowth'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: json['totalTransactions'] ?? 0,
      transactionGrowth: json['transactionGrowth'] ?? 0,
      newCustomers: json['newCustomers'] ?? 0,
      returningCustomers: json['returningCustomers'] ?? 0,
      customerRetentionRate:
          (json['customerRetentionRate'] as num?)?.toDouble() ?? 0.0,
      topProductId: json['topProductId'] ?? '',
      topProductName: json['topProductName'] ?? 'N/A',
      topProductSales: json['topProductSales'] ?? 0,
      topWorkerId: json['topWorkerId'] ?? '',
      topWorkerName: json['topWorkerName'] ?? 'N/A',
      topWorkerSales: (json['topWorkerSales'] as num?)?.toDouble() ?? 0.0,
      totalCogs: (json['totalCogs'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (json['grossProfit'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is DateTime
              ? json['createdAt']
              : DateTime.now(),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : json['updatedAt'] is DateTime
              ? json['updatedAt']
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'startDate': startDate,
      'endDate': endDate,
      'totalRevenue': totalRevenue,
      'averageOrderValue': averageOrderValue,
      'revenueGrowth': revenueGrowth,
      'totalTransactions': totalTransactions,
      'transactionGrowth': transactionGrowth,
      'newCustomers': newCustomers,
      'returningCustomers': returningCustomers,
      'customerRetentionRate': customerRetentionRate,
      'topProductId': topProductId,
      'topProductName': topProductName,
      'topProductSales': topProductSales,
      'totalCogs': totalCogs,
      'grossProfit': grossProfit,
      'topWorkerId': topWorkerId,
      'topWorkerName': topWorkerName,
      'topWorkerSales': topWorkerSales,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

