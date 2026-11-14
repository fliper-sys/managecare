import 'package:flutter/material.dart';

/// Design tokens for UI v2: the single source of colour, spacing and shape for
/// new code. Screens read these through [AppTokens.of] and never use raw
/// colours (see tool/check_ui_v2_colors.sh).
///
/// This class does not touch the existing AppTheme. It reads the brightness of
/// the current Theme, so it works with the theme the app already provides.
@immutable
class AppTokens {
  const AppTokens._({
    required this.brightness,
    required this.page,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.brand,
    required this.onBrand,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.info,
    required this.infoBg,
  });

  final Brightness brightness;

  // Surfaces
  final Color page;
  final Color surface;
  final Color raised;
  final Color line;

  // Text
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  // Brand
  final Color brand;
  final Color onBrand;

  // Status (each foreground is paired with its own background)
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;
  final Color info;
  final Color infoBg;

  static const AppTokens light = AppTokens._(
    brightness: Brightness.light,
    page: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    line: Color(0xFFE2E8F0),
    ink: Color(0xFF0F172A),
    inkMuted: Color(0xFF475569),
    inkFaint: Color(0xFF64748B),
    brand: Color(0xFF2563EB),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF047857),
    successBg: Color(0xFFECFDF5),
    warning: Color(0xFFB45309),
    warningBg: Color(0xFFFFFBEB),
    danger: Color(0xFFB91C1C),
    dangerBg: Color(0xFFFEF2F2),
    info: Color(0xFF1D4ED8),
    infoBg: Color(0xFFEFF6FF),
  );

  static const AppTokens dark = AppTokens._(
    brightness: Brightness.dark,
    page: Color(0xFF070B14),
    surface: Color(0xFF0F172A),
    raised: Color(0xFF162033),
    line: Color(0xFF1E293B),
    ink: Color(0xFFF1F5F9),
    inkMuted: Color(0xFF94A3B8),
    inkFaint: Color(0xFF8191A8),
    brand: Color(0xFF60A5FA),
    onBrand: Color(0xFF0B1220),
    success: Color(0xFF34D399),
    successBg: Color(0xFF052E26),
    warning: Color(0xFFFBBF24),
    warningBg: Color(0xFF3A2A06),
    danger: Color(0xFFF87171),
    dangerBg: Color(0xFF3B1212),
    info: Color(0xFF93C5FD),
    infoBg: Color(0xFF0F2347),
  );

  /// Tokens for the brightness of the nearest Theme.
  static AppTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // Spacing (4-point base)
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;

  // Radii
  static const double rControl = 12;
  static const double rCard = 16;
  static const double rSheet = 24;
  static const double rHero = 28;

  /// A soft background tint of [color], for chips and icon wells on a business
  /// accent.
  static Color tint(Color color, {double amount = 0.14}) =>
      color.withOpacity(amount);
}
