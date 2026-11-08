class PaymentBreakdown {
  final double cash;
  final double card;
  final double transfer;

  const PaymentBreakdown({
    this.cash = 0,
    this.card = 0,
    this.transfer = 0,
  });

  double get total => cash + card + transfer;
  bool get isValid =>
      cash.isFinite &&
      card.isFinite &&
      transfer.isFinite &&
      cash >= 0 &&
      card >= 0 &&
      transfer >= 0;

  String get method {
    final methods = <String>[
      if (cash > 0) 'cash',
      if (card > 0) 'card',
      if (transfer > 0) 'transfer',
    ];
    if (methods.isEmpty) return 'unpaid';
    return methods.length == 1 ? methods.single : 'mixed';
  }

  Map<String, double> toJson() => {
        'cash': cash,
        'card': card,
        'transfer': transfer,
      };

  factory PaymentBreakdown.fromJson(dynamic value) {
    if (value is! Map) return const PaymentBreakdown();
    double read(String key) {
      final amount = value[key];
      if (amount is num) return amount.toDouble();
      if (amount is String) return double.tryParse(amount) ?? 0;
      return 0;
    }

    return PaymentBreakdown(
      cash: read('cash'),
      card: read('card'),
      transfer: read('transfer'),
    );
  }
}
