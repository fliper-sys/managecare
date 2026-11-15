import 'package:flutter/services.dart';

/// Groups thousands as the cashier types: 1250000 shows as 1,250,000, and a
/// decimal part of up to two digits is kept. Only digits and one dot are
/// accepted. The cursor stays at the end of what was typed.
class NairaInputFormatter extends TextInputFormatter {
  const NairaInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    var raw = next.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final dot = raw.indexOf('.');
    String whole = dot < 0 ? raw : raw.substring(0, dot);
    String frac = dot < 0 ? '' : raw.substring(dot + 1).replaceAll('.', '');
    if (frac.length > 2) frac = frac.substring(0, 2);
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final out = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
      out.write(whole[i]);
    }
    final text = dot < 0 ? out.toString() : '${out.isEmpty ? '0' : out}.$frac';
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
