import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A focused visual system for the administrative-services workspace.
///
/// Applying this theme above the workspace also lets Flutter capture it when
/// the workspace pushes client, invoice, calendar, and task routes.
ThemeData administrativeBusinessTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  const jade = Color(0xFF087E70);
  const jadeBright = Color(0xFF12A48F);
  const ink = Color(0xFF142A34);
  final scheme = base.colorScheme.copyWith(
    primary: dark ? const Color(0xFF56D6BD) : jade,
    onPrimary: dark ? const Color(0xFF06241F) : Colors.white,
    secondary: dark ? const Color(0xFF8DD8C9) : jadeBright,
    tertiary: dark ? const Color(0xFFE9BC72) : const Color(0xFFB7752C),
    surface: dark ? const Color(0xFF142229) : const Color(0xFFFFFFFF),
    onSurface: dark ? const Color(0xFFE7F0EE) : ink,
    surfaceContainerHighest:
        dark ? const Color(0xFF202F35) : const Color(0xFFEEF4F2),
    outline: dark ? const Color(0xFF35484C) : const Color(0xFFD8E4E0),
    error: dark ? const Color(0xFFFF8B83) : const Color(0xFFB84238),
  );
  final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
    headlineLarge: GoogleFonts.manrope(
      textStyle: base.textTheme.headlineLarge,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
    ),
    headlineMedium: GoogleFonts.manrope(
      textStyle: base.textTheme.headlineMedium,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.7,
    ),
    titleLarge: GoogleFonts.manrope(
      textStyle: base.textTheme.titleLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
    ),
    titleMedium: GoogleFonts.dmSans(
      textStyle: base.textTheme.titleMedium,
      fontWeight: FontWeight.w700,
    ),
    labelLarge: GoogleFonts.dmSans(
      textStyle: base.textTheme.labelLarge,
      fontWeight: FontWeight.w700,
    ),
  );
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: scheme.outline),
  );
  final focused = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: scheme.primary, width: 1.7),
  );

  return base.copyWith(
    colorScheme: scheme,
    primaryColor: scheme.primary,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0E191E) : const Color(0xFFF3F7F5),
    canvasColor: dark ? const Color(0xFF0E191E) : const Color(0xFFF3F7F5),
    cardColor: scheme.surface,
    dividerColor: dark ? const Color(0xFF26373C) : const Color(0xFFE4ECE9),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0E191E) : const Color(0xFFF3F7F5),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 19),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline.withOpacity(.68)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.primary,
      textColor: scheme.onSurface,
      tileColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF17262C) : const Color(0xFFFAFCFB),
      border: outline,
      enabledBorder: outline,
      focusedBorder: focused,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: scheme.error, width: 1.7),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface.withOpacity(.48),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface.withOpacity(.74),
      ),
      prefixIconColor: scheme.onSurface.withOpacity(.55),
      suffixIconColor: scheme.onSurface.withOpacity(.55),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 42),
        foregroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: dark ? const Color(0xFF142229) : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withOpacity(dark ? .2 : .12),
      labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? scheme.primary
                    : scheme.onSurface.withOpacity(.63),
              )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurface.withOpacity(.63),
          )),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface.withOpacity(.8),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.primary.withOpacity(.09),
      side: BorderSide(color: scheme.primary.withOpacity(.15)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      labelStyle: textTheme.labelMedium?.copyWith(color: scheme.primary),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withOpacity(.12),
      circularTrackColor: scheme.primary.withOpacity(.12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: dark ? const Color(0xFF26383D) : ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF31434A) : ink,
        borderRadius: BorderRadius.circular(9),
      ),
      textStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
    ),
  );
}
