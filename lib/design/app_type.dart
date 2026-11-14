import 'dart:ui' show FontFeature;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography for UI v2, matching the flagship demo: Plus Jakarta Sans for
/// text and JetBrains Mono for figures, with tabular digits.
///
/// TODO(phase 2): bundle both families under assets/fonts and register them in
/// pubspec.yaml so the POS works offline. Until then google_fonts fetches them
/// at runtime and falls back to the platform font.
class AppType {
  const AppType._();

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Plus Jakarta Sans.
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
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
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        fontFeatures: tabular,
      );

  /// The demo's micro label: 10 px, heavy, slightly tracked.
  static TextStyle micro({Color? color}) =>
      sans(size: 10, weight: FontWeight.w800, color: color, letterSpacing: 0.4);
}
