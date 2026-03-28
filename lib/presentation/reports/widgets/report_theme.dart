import 'package:flutter/material.dart';

extension ReportThemeContext on BuildContext {
  ThemeData get reportTheme => Theme.of(this);

  Color get reportBackground => reportTheme.scaffoldBackgroundColor;

  Color get reportSurface => reportTheme.cardColor;

  Color get reportBorder => reportTheme.dividerColor;

  Color get reportMutedText =>
      reportTheme.textTheme.bodySmall?.color ??
      reportTheme.colorScheme.onSurface.withOpacity(0.7);

  Color get reportChipSurface => reportTheme.brightness == Brightness.dark
      ? reportTheme.colorScheme.surface.withOpacity(0.82)
      : Colors.white;

  List<BoxShadow> get reportCardShadow => reportTheme.brightness == Brightness.dark
      ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
}
