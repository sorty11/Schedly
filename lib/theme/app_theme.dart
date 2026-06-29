import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  // ─── Text Theme ─────────────────────────────────────────────────────────────
  // Outfit for display/title, Inter for body/labels
  static TextTheme _buildTextTheme(TextTheme base, {required bool isDark}) {
    final textColor = isDark ? AppColors.onSurfaceDark : AppColors.onSurface;
    final mutedColor = isDark ? const Color(0xFF8888A4) : const Color(0xFF6B7280);

    return base.copyWith(
      // Display — Outfit, large hero numbers and names
      displayLarge: GoogleFonts.outfit(
        fontSize: 40, fontWeight: FontWeight.w800,
        letterSpacing: -1.5, color: textColor, height: 1.1,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 32, fontWeight: FontWeight.w700,
        letterSpacing: -1.0, color: textColor, height: 1.15,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 26, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: textColor, height: 1.2,
      ),

      // Headline — Outfit
      headlineLarge: GoogleFonts.outfit(
        fontSize: 22, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: textColor, height: 1.3,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20, fontWeight: FontWeight.w700,
        letterSpacing: -0.25, color: textColor, height: 1.3,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: textColor, height: 1.35,
      ),

      // Title — Outfit
      titleLarge: GoogleFonts.outfit(
        fontSize: 16, fontWeight: FontWeight.w700,
        color: textColor, height: 1.4,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 15, fontWeight: FontWeight.w600,
        color: textColor, height: 1.4,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: textColor, height: 1.4,
      ),

      // Body — Inter
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: textColor, height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: mutedColor, height: 1.4,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: mutedColor, height: 1.4,
      ),

      // Label — Inter (uppercase caps)
      labelLarge: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w700,
        letterSpacing: 0.5, color: textColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w700,
        letterSpacing: 0.8, color: textColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w600,
        letterSpacing: 1.0, color: mutedColor,
      ),
    );
  }

  // ─── Input Decoration Theme ───────────────────────────────────────────────
  static InputDecorationTheme _inputTheme(ColorScheme colors) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: colors.brightness == Brightness.light
              ? const Color(0xFFE8E8F0)
              : const Color(0xFF2A2A38),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: colors.brightness == Brightness.light
              ? const Color(0xFFE8E8F0)
              : const Color(0xFF2A2A38),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.onSurface.withValues(alpha: 0.6),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: colors.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  // ─── Light Theme ─────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,          // Indigo 600
      primaryContainer: Color(0xFFEEF2FF), // Indigo 50
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.secondary,       // Violet 500
      secondaryContainer: Color(0xFFF5F3FF),
      tertiary: AppColors.accent,           // Cyan 500
      surface: AppColors.surface,           // White
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: AppColors.onSurface,       // Near-black
      error: AppColors.red,
      onError: Colors.white,
      outline: Color(0xFFE8E8F0),
      outlineVariant: Color(0xFFF0F0F8),
      surfaceContainerHighest: Color(0xFFF5F5F7),
      scrim: Color(0x40000000),
    );

    final textTheme = _buildTextTheme(ThemeData.light().textTheme, isDark: false);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface, size: 24),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: Color(0xFF6B7280), size: 24);
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF5F5F7),
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        side: BorderSide.none,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E8F0),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: _inputTheme(colorScheme),
      extensions: const [lightSemanticColors],
    );
  }

  // ─── Dark Theme ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primaryDark,        // Indigo 400
      primaryContainer: Color(0xFF1E1B4B),   // Indigo 950
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondaryDark,    // Violet 400
      secondaryContainer: Color(0xFF2E1065),
      tertiary: AppColors.accentDark,        // Cyan 400
      surface: AppColors.surfaceDark,        // #141418
      onPrimary: Color(0xFF0C0C10),
      onSecondary: Color(0xFF0C0C10),
      onTertiary: Color(0xFF0C0C10),
      onSurface: AppColors.onSurfaceDark,    // Near-white
      error: AppColors.redLight,
      onError: Color(0xFF0C0C10),
      outline: Color(0xFF2A2A38),
      outlineVariant: Color(0xFF1E1E2A),
      surfaceContainerHighest: Color(0xFF1C1C22),
      scrim: Color(0x80000000),
    );

    final textTheme = _buildTextTheme(ThemeData.dark().textTheme, isDark: true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.onSurfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceDark,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurfaceDark, size: 24),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Color(0xFF0C0C10),
        elevation: 4,
        shape: CircleBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF242430),
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceDark,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryDark.withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: const Color(0xFF8888A4),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryDark, size: 24);
          }
          return const IconThemeData(color: Color(0xFF8888A4), size: 24);
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1C1C22),
        selectedColor: AppColors.primaryDark.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceDark,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        side: BorderSide.none,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A38),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: _inputTheme(colorScheme),
      extensions: const [darkSemanticColors],
    );
  }
}
