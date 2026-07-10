import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

String formatAmount(
  dynamic value, {
    int decimalDigits = 2,
    String locale = 'en_US',
  }) {
  if (value == null) {
    return '0';
  }

  if (value is num) {
    final pattern = decimalDigits > 0
        ? '#,##0.${'0' * decimalDigits}'
        : '#,##0';
    return NumberFormat(pattern, locale).format(value);
  }

  final parsed = double.tryParse(value.toString().replaceAll(',', '').trim());
  if (parsed == null) {
    return value.toString();
  }

  final pattern = decimalDigits > 0
      ? '#,##0.${'0' * decimalDigits}'
      : '#,##0';
  return NumberFormat(pattern, locale).format(parsed);
}

String normalizeAmountInput(String value) {
  return value.replaceAll(',', '').trim();
}

double? parseAmountInput(String value) {
  final normalized = normalizeAmountInput(value);
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({this.decimalDigits = 2});

  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final sanitized = newValue.text.replaceAll(',', '');
    if (sanitized == '.') {
      return const TextEditingValue(text: '0.');
    }

    if (!RegExp(r'^\d*(\.\d*)?$').hasMatch(sanitized)) {
      return oldValue;
    }

    final parts = sanitized.split('.');
    final integerPart = parts.first;
    String? fractionPart;

    if (parts.length > 1) {
      fractionPart = parts[1];
      if (decimalDigits <= 0) {
        fractionPart = '';
      } else if (fractionPart.length > decimalDigits) {
        fractionPart = fractionPart.substring(0, decimalDigits);
      }
    }

    final formattedInteger = integerPart.isEmpty
        ? ''
        : integerPart.replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (match) => '${match[1]},',
          );

    var formatted = formattedInteger;
    if (fractionPart != null && fractionPart.isNotEmpty) {
      formatted = '$formatted.$fractionPart';
    } else if (sanitized.contains('.')) {
      formatted = '$formatted.';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
