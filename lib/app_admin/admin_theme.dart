import 'package:flutter/material.dart';

extension AdminThemeContext on BuildContext {
  ThemeData get adminTheme => Theme.of(this);
  ColorScheme get adminScheme => adminTheme.colorScheme;
  bool get isAdminDark => adminTheme.brightness == Brightness.dark;

  Color get adminBackground =>
      isAdminDark ? const Color(0xFF08101D) : const Color(0xFFF4F7FB);
  Color get adminSurface =>
      isAdminDark ? const Color(0xFF111827) : Colors.white;
  Color get adminSurfaceAlt =>
      isAdminDark ? const Color(0xFF0F1A2D) : const Color(0xFFF8FAFC);
  Color get adminSurfaceStrong =>
      isAdminDark ? const Color(0xFF152238) : const Color(0xFF0F172A);
  Color get adminBorder =>
      isAdminDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get adminTextPrimary => adminScheme.onSurface;
  Color get adminTextSecondary =>
      adminScheme.onSurface.withOpacity(isAdminDark ? 0.72 : 0.64);
  Color get adminTextTertiary =>
      adminScheme.onSurface.withOpacity(isAdminDark ? 0.52 : 0.5);
  Gradient get adminHeaderGradient => LinearGradient(
        colors: isAdminDark
            ? const [Color(0xFF152238), Color(0xFF0B1322)]
            : const [Color(0xFF1E293B), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  BoxDecoration adminCardDecoration({
    Color? color,
    BorderRadiusGeometry? borderRadius,
  }) {
    return BoxDecoration(
      color: color ?? adminSurface,
      borderRadius:
          borderRadius ?? const BorderRadius.all(Radius.circular(20)),
      border: Border.all(color: adminBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isAdminDark ? 0.24 : 0.05),
          blurRadius: isAdminDark ? 18 : 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
