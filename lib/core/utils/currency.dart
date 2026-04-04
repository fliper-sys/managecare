import 'package:intl/intl.dart';

/// Simple currency formatter for NGN displays across the app.
const String kNairaSymbol = '₦';
const String kNairaFallbackSymbol = 'NGN ';

String formatCurrency(
  double amount, {
  String symbol = kNairaSymbol,
  int decimalDigits = 2,
}) {
  try {
    final f = NumberFormat.currency(
      locale: 'en_NG',
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return f.format(amount);
  } catch (_) {
    return '$symbol${amount.toStringAsFixed(decimalDigits)}';
  }
}
