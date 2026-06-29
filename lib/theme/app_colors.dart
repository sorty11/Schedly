import 'package:flutter/material.dart';

// ─── Semantic Color Extension ──────────────────────────────────────────────────
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color pending;
  final Color conducted;
  final Color cancelled;
  final Color rescheduled;
  final Color success;
  final Color warning;
  final Color error;
  final Color accent;
  final Color surfaceElevated;
  final Color surfaceElevated2;
  final Color borderSubtle;
  final Color onSurfaceMuted;

  const AppSemanticColors({
    required this.pending,
    required this.conducted,
    required this.cancelled,
    required this.rescheduled,
    required this.success,
    required this.warning,
    required this.error,
    required this.accent,
    required this.surfaceElevated,
    required this.surfaceElevated2,
    required this.borderSubtle,
    required this.onSurfaceMuted,
  });

  @override
  AppSemanticColors copyWith({
    Color? pending,
    Color? conducted,
    Color? cancelled,
    Color? rescheduled,
    Color? success,
    Color? warning,
    Color? error,
    Color? accent,
    Color? surfaceElevated,
    Color? surfaceElevated2,
    Color? borderSubtle,
    Color? onSurfaceMuted,
  }) {
    return AppSemanticColors(
      pending: pending ?? this.pending,
      conducted: conducted ?? this.conducted,
      cancelled: cancelled ?? this.cancelled,
      rescheduled: rescheduled ?? this.rescheduled,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      accent: accent ?? this.accent,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceElevated2: surfaceElevated2 ?? this.surfaceElevated2,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      pending: Color.lerp(pending, other.pending, t)!,
      conducted: Color.lerp(conducted, other.conducted, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
      rescheduled: Color.lerp(rescheduled, other.rescheduled, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceElevated2: Color.lerp(surfaceElevated2, other.surfaceElevated2, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
    );
  }
}

// ─── Light Theme Palette ──────────────────────────────────────────────────────
// Identity: "Indigo Dusk"
const lightSemanticColors = AppSemanticColors(
  pending:        Color(0xFFF59E0B),  // Amber 400
  conducted:      Color(0xFF10B981),  // Emerald 500
  cancelled:      Color(0xFFEF4444),  // Red 500
  rescheduled:    Color(0xFF6366F1),  // Indigo 500
  success:        Color(0xFF22C55E),  // Green 500
  warning:        Color(0xFFF59E0B),  // Amber 400
  error:          Color(0xFFEF4444),  // Red 500
  accent:         Color(0xFF06B6D4),  // Cyan 500
  surfaceElevated:  Color(0xFFFAFAFE),  // Slightly tinted white
  surfaceElevated2: Color(0xFFF0F0FA),  // Dialog/sheet surface
  borderSubtle:   Color(0xFFE8E8F0),
  onSurfaceMuted: Color(0xFF6B7280),  // Gray 500
);

// ─── Dark Theme Palette ───────────────────────────────────────────────────────
const darkSemanticColors = AppSemanticColors(
  pending:        Color(0xFFFBBF24),  // Amber 400
  conducted:      Color(0xFF34D399),  // Emerald 400
  cancelled:      Color(0xFFF87171),  // Red 400
  rescheduled:    Color(0xFF818CF8),  // Indigo 400
  success:        Color(0xFF4ADE80),  // Green 400
  warning:        Color(0xFFFBBF24),  // Amber 400
  error:          Color(0xFFF87171),  // Red 400
  accent:         Color(0xFF22D3EE),  // Cyan 400
  surfaceElevated:  Color(0xFF1C1C22),  // Surface 2
  surfaceElevated2: Color(0xFF242430),  // Surface 3 (dialogs)
  borderSubtle:   Color(0xFF2A2A38),
  onSurfaceMuted: Color(0xFF8888A4),
);

// ─── Named Color Palette (for use in gradients, hardcoded accents) ────────────
class AppColors {
  AppColors._();

  // Primary family — Indigo
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF818CF8);   // dark mode primary

  // Secondary family — Violet
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color secondaryDark = Color(0xFFA78BFA);

  // Accent — Cyan
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentDark = Color(0xFF22D3EE);

  // Status
  static const Color green = Color(0xFF10B981);
  static const Color greenLight = Color(0xFF34D399);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color red = Color(0xFFEF4444);
  static const Color redLight = Color(0xFFF87171);

  // Neutral (light)
  static const Color background = Color(0xFFF5F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF111827);

  // Neutral (dark)
  static const Color backgroundDark = Color(0xFF0C0C10);
  static const Color surfaceDark = Color(0xFF141418);
  static const Color onSurfaceDark = Color(0xFFF1F1F5);
}
