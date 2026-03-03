import 'package:intl/intl.dart';

/// Simple currency formatter. Default to Naira symbol ₦ (en_NG). Use where you
/// want consistent display for money in the restaurant screens.
String formatCurrency(double amount, {String symbol = '₦'}) {
  try {
    final f = NumberFormat.currency(locale: 'en_NG', symbol: symbol, decimalDigits: 2);
    return f.format(amount);
  } catch (_) {
    // fallback
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}
