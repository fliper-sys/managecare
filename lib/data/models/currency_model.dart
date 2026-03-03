import 'package:cloud_firestore/cloud_firestore.dart';

class Currency {
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalPlaces,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      decimalPlaces: json['decimalPlaces'] as int? ?? 2,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'symbol': symbol,
      'decimalPlaces': decimalPlaces,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(decimalPlaces);
    return '$symbol$formatted';
  }

  Currency copyWith({
    String? code,
    String? name,
    String? symbol,
    int? decimalPlaces,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Currency(
      code: code ?? this.code,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CurrencyRate {
  final String id;
  final String baseCurrency;
  final String targetCurrency;
  final double rate;
  final DateTime effectiveDate;
  final DateTime expiryDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CurrencyRate({
    required this.id,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.effectiveDate,
    required this.expiryDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CurrencyRate.fromJson(Map<String, dynamic> json) {
    return CurrencyRate(
      id: json['id'] as String? ?? '',
      baseCurrency: json['baseCurrency'] as String? ?? '',
      targetCurrency: json['targetCurrency'] as String? ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
      effectiveDate: json['effectiveDate'] is Timestamp
          ? (json['effectiveDate'] as Timestamp).toDate()
          : DateTime.now(),
      expiryDate: json['expiryDate'] is Timestamp
          ? (json['expiryDate'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 365)),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baseCurrency': baseCurrency,
      'targetCurrency': targetCurrency,
      'rate': rate,
      'effectiveDate': Timestamp.fromDate(effectiveDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  double convertAmount(double amount) {
    return amount * rate;
  }

  CurrencyRate copyWith({
    String? id,
    String? baseCurrency,
    String? targetCurrency,
    double? rate,
    DateTime? effectiveDate,
    DateTime? expiryDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CurrencyRate(
      id: id ?? this.id,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      targetCurrency: targetCurrency ?? this.targetCurrency,
      rate: rate ?? this.rate,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

