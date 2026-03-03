import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2563EB); // Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1E40AF);

  // Secondary Colors
  static const Color secondary = Color(0xFF10B981); // Green
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF059669);

  // Accent Colors
  static const Color accent = Color(0xFFF59E0B); // Amber
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentDark = Color(0xFFD97706);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Background Colors
  static const Color background = Color(0xFFF9FAFB);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color.fromARGB(255, 168, 172, 180);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);

  // Border & Divider
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color lightGrey = Color(0xFFD1D5DB);
  static const Color darkGrey = Color(0xFF374151);
  static const Color successLight = Color(0xFFDCFCE7);

  // Card & Surface
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF9FAFB);
  static const Color white = Color(0xFFFFFFFF);

  // Industry-Specific Colors
  static const Color pharmacy = Color(0xFF059669); // Green
  static const Color retail = Color(0xFF2563EB); // Blue
  static const Color agri = Color(0xFF84CC16); // Lime
  static const Color auto = Color(0xFF7C3AED); // Purple
  static const Color salon = Color(0xFFEC4899); // Pink
  static const Color hotel = Color(0xFF0891B2); // Cyan
  static const Color drink = Color(0xFFF97316); // Orange
  static const Color restaurant = Color(0xFFDC2626); // Red
  static const Color realEstate = Color(0xFF0369A1); // Sky Blue

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
  ];

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [error, Color(0xFFFCA5A5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Get color by business type
  static Color getBusinessTypeColor(String businessType) {
    switch (businessType.toLowerCase()) {
      case 'pharmacy':
        return pharmacy;
      case 'retail':
        return retail;
      case 'agri':
      case 'agriculture':
        return agri;
      case 'auto':
      case 'automotive':
        return auto;
      case 'salon':
        return salon;
      case 'hotel':
        return hotel;
      case 'drink':
      case 'bar':
        return drink;
      case 'restaurant':
        return restaurant;
      case 'realestate':
      case 'real_estate':
        return realEstate;
      default:
        return primary;
    }
  }

  // Shadow Colors
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}

