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
