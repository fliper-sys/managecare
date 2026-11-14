import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/painting.dart';

/// Typography for UI v2, matching the flagship demo: Plus Jakarta Sans for
/// text and JetBrains Mono for figures, with tabular digits. Both are bundled
/// variable fonts (SIL OFL, see assets/fonts), so they work offline.
class AppType {
  const AppType._();

  static const String sansFamily = 'PlusJakartaSans';
  static const String monoFamily = 'JetBrainsMono';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static List<FontVariation> _wght(FontWeight w) =>
      [FontVariation('wght', w.value.toDouble())];

  /// Plus Jakarta Sans.
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontSize: size,
        fontWeight: weight,
        fontVariations: _wght(weight),
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// JetBrains Mono with tabular figures, for amounts and codes.
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: size,
        fontWeight: weight,
        fontVariations: _wght(weight),
        fontFeatures: tabular,
        color: color,
        height: height,
      );

  /// The demo's micro label: 10 px, heavy, slightly tracked.
  static TextStyle micro({Color? color}) =>
      sans(size: 10, weight: FontWeight.w800, color: color, letterSpacing: 0.4);
}
