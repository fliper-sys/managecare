/// Formats a naira amount with thousands separators, for example ₦1,250,000.
String formatNaira(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}₦$out';
}

/// Like [formatNaira] but keeps kobo when the amount has them, for example
/// ₦1,250.50. Whole amounts print without decimals. Use for unit prices,
/// custom prices and anything a cashier can type.
String formatNairaPrecise(num amount) {
  final cents = (amount * 100).round();
  if (cents % 100 == 0) return formatNaira(cents ~/ 100);
  final neg = cents < 0;
  final abs = cents.abs();
  final whole = formatNaira(abs ~/ 100).substring(1); // drop the sign-less ₦
  final kobo = (abs % 100).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}₦$whole.$kobo';
}

/// Parses text typed in a naira field: ignores commas, spaces and the ₦ sign.
/// Returns null when it is not a number.
double? parseNaira(String text) {
  final cleaned = text.replaceAll(RegExp(r'[₦,\s]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
