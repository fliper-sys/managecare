import 'package:flutter/services.dart';

/// Restricts a text field to a plain decimal number (digits, at most one
/// decimal point) while typing.
///
/// Deliberately not implemented as `FilteringTextInputFormatter.allow` with
/// an anchored regex - Flutter applies that kind of formatter to the
/// substrings before/after the current selection separately, not the whole
/// resulting string at once, so a `^`-anchored pattern only matches
/// correctly when the cursor sits at the very end. That produced a real bug
/// (price/discount/tax fields that only accepted edits once the cursor was
/// moved past the decimal point). Overriding [formatEditUpdate] directly
/// validates the complete [newValue.text] as one string, so cursor position
/// never affects whether an edit is accepted.
class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Allow a fully-typed number as-is, plus in-progress states like "150."
    // or ".5" that aren't valid numbers yet but are valid keystrokes on the
    // way to one.
    if (double.tryParse(text) != null || RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return newValue;
    }
    return oldValue;
  }
}
