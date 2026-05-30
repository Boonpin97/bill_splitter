import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material You seed — calm teal-green. Generates the rest of the M3 palette.
const _seed = Color(0xFF1F8F7A);

class AppFonts {
  /// Roboto Serif — large numerals and headlines (Material You expressive).
  static TextStyle serif({
    double size = 32,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.1,
    double letterSpacing = -0.2,
    FontStyle? style,
  }) =>
      GoogleFonts.robotoSerif(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: style,
      );

  /// Roboto Flex — body and UI text.
  static TextStyle flex({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
    double letterSpacing = 0.1,
  }) =>
      GoogleFonts.robotoFlex(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Roboto Mono — currency values.
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.robotoMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle label({Color? color}) => flex(
        size: 11,
        weight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
        height: 1.2,
      );
}

ThemeData buildAppTheme() {
  final colors =
      ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);

  // Build the M3 text theme on top of the seeded colors.
  TextTheme textTheme(ColorScheme c) {
    final onSurface = c.onSurface;
    final onSurfaceVar = c.onSurfaceVariant;
    return TextTheme(
      displayLarge: AppFonts.serif(
          size: 52, weight: FontWeight.w400, color: onSurface, height: 1.05),
      displayMedium: AppFonts.serif(
          size: 42, weight: FontWeight.w400, color: onSurface, height: 1.05),
      displaySmall: AppFonts.serif(
          size: 32, weight: FontWeight.w400, color: onSurface),
      headlineLarge:
          AppFonts.serif(size: 28, weight: FontWeight.w500, color: onSurface),
      headlineMedium:
          AppFonts.serif(size: 22, weight: FontWeight.w500, color: onSurface),
      headlineSmall:
          AppFonts.serif(size: 19, weight: FontWeight.w500, color: onSurface),
      titleLarge:
          AppFonts.flex(size: 18, weight: FontWeight.w600, color: onSurface),
      titleMedium:
          AppFonts.flex(size: 15, weight: FontWeight.w600, color: onSurface),
      titleSmall:
          AppFonts.flex(size: 13, weight: FontWeight.w600, color: onSurface),
      bodyLarge:
          AppFonts.flex(size: 15, color: onSurface, letterSpacing: 0.15),
      bodyMedium:
          AppFonts.flex(size: 14, color: onSurface, letterSpacing: 0.2),
      bodySmall:
          AppFonts.flex(size: 12, color: onSurfaceVar, letterSpacing: 0.3),
      labelLarge:
          AppFonts.flex(size: 14, weight: FontWeight.w600, color: onSurface),
      labelMedium: AppFonts.flex(
          size: 12, weight: FontWeight.w600, color: onSurfaceVar),
      labelSmall: AppFonts.flex(
          size: 11,
          weight: FontWeight.w600,
          color: onSurfaceVar,
          letterSpacing: 0.5),
    );
  }

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    textTheme: textTheme(colors),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surfaceTint,
      foregroundColor: colors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 3,
      centerTitle: false,
      titleTextStyle: AppFonts.flex(
          size: 16, weight: FontWeight.w600, color: colors.onSurface),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLow,
      surfaceTintColor: colors.surfaceTint,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 22),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        textStyle: AppFonts.flex(
            size: 14, weight: FontWeight.w600, letterSpacing: 0.1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle:
            AppFonts.flex(size: 14, weight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.onSurface,
        side: BorderSide(color: colors.outlineVariant, width: 1),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle:
            AppFonts.flex(size: 14, weight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        shape: const StadiumBorder(),
        textStyle: AppFonts.flex(size: 14, weight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      elevation: 1,
      focusElevation: 1,
      highlightElevation: 2,
      hoverElevation: 2,
      extendedTextStyle:
          AppFonts.flex(size: 14, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceContainerHighest,
      selectedColor: colors.secondaryContainer,
      labelStyle:
          AppFonts.flex(size: 13, weight: FontWeight.w500, color: colors.onSurface),
      secondaryLabelStyle: AppFonts.flex(
          size: 13,
          weight: FontWeight.w500,
          color: colors.onSecondaryContainer),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.secondaryContainer
                : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant),
        side: WidgetStateProperty.all(BorderSide(color: colors.outlineVariant)),
        textStyle: WidgetStateProperty.all(
            AppFonts.flex(size: 13, weight: FontWeight.w600)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppFonts.flex(color: colors.onSurfaceVariant),
      labelStyle: AppFonts.flex(color: colors.onSurfaceVariant, size: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: colors.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle:
          AppFonts.serif(size: 22, color: colors.onSurface),
      contentTextStyle:
          AppFonts.flex(size: 14, color: colors.onSurfaceVariant),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLow,
      surfaceTintColor: colors.surfaceTint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.inverseSurface,
      contentTextStyle:
          AppFonts.flex(color: colors.onInverseSurface, size: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: colors.outlineVariant,
    splashFactory: InkSparkle.splashFactory,
  );
}

const double kMaxContentWidth = 640;
