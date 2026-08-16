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
  final Color surfaceTinted;
  final Color borderSubtle;
  final Color borderFocus;
  final Color onSurfaceMuted;
  final Color onSurfaceFaint;

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
    required this.surfaceTinted,
    required this.borderSubtle,
    required this.borderFocus,
    required this.onSurfaceMuted,
    required this.onSurfaceFaint,
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
    Color? surfaceTinted,
    Color? borderSubtle,
    Color? borderFocus,
    Color? onSurfaceMuted,
    Color? onSurfaceFaint,
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
      surfaceTinted: surfaceTinted ?? this.surfaceTinted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderFocus: borderFocus ?? this.borderFocus,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      onSurfaceFaint: onSurfaceFaint ?? this.onSurfaceFaint,
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
      surfaceElevated2: Color.lerp(
        surfaceElevated2,
        other.surfaceElevated2,
        t,
      )!,
      surfaceTinted: Color.lerp(surfaceTinted, other.surfaceTinted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      onSurfaceFaint: Color.lerp(onSurfaceFaint, other.onSurfaceFaint, t)!,
    );
  }
}

// ─── Light Theme Palette (Project Phoenix) ───────────────────────────────────
// Inspired by Vercel/Linear: Pure whites, very subtle grays, vibrant electric blue.
const lightSemanticColors = AppSemanticColors(
  pending: Color(0xFFE5A000), // Crisp Amber
  conducted: Color(0xFF007A5A), // Deep crisp green
  cancelled: Color(0xFFE5484D), // Sharp red
  rescheduled: Color(0xFF5E548E), // Muted purple
  success: Color(0xFF007A5A),
  warning: Color(0xFFE5A000),
  error: Color(0xFFE5484D),
  accent: Color(0xFF0066FF), // Electric Blue
  surfaceElevated: Color(0xFFFFFFFF), // Pure White
  surfaceElevated2: Color(0xFFFAFAFA), // Off-white
  surfaceTinted: Color(0xFFF3F8FF), // Barely tinted blue
  borderSubtle: Color(0xFFEBEBEB), // Very faint border
  borderFocus: Color(0xFF0066FF),
  onSurfaceMuted: Color(0xFF666666), // True mid-gray
  onSurfaceFaint: Color(0xFF999999), // Light text
);

// ─── Dark Theme Palette (Project Phoenix) ────────────────────────────────────
// Pure blacks, sharp borders, highly legible typography.
const darkSemanticColors = AppSemanticColors(
  pending: Color(0xFFF5B014),
  conducted: Color(0xFF10B981),
  cancelled: Color(0xFFF87171),
  rescheduled: Color(0xFF818CF8),
  success: Color(0xFF10B981),
  warning: Color(0xFFF5B014),
  error: Color(0xFFF87171),
  accent: Color(0xFF0066FF), // Unchanged Electric Blue, pops on black
  surfaceElevated: Color(
    0xFF0A0A0A,
  ), // True dark, but not OLED black to allow borders
  surfaceElevated2: Color(0xFF111111), // Slightly raised
  surfaceTinted: Color(0xFF0D1524), // Extremely faint blue tint
  borderSubtle: Color(0xFF222222), // Sharp hairline border
  borderFocus: Color(0xFF0066FF),
  onSurfaceMuted: Color(0xFFA1A1A1),
  onSurfaceFaint: Color(0xFF737373),
);

// ─── Named Color Palette ──────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0066FF);
  static const Color primaryLight = Color(0xFF3385FF);
  static const Color primaryDark = Color(0xFF005CE6);

  static const Color secondary = Color(0xFF666666);
  static const Color secondaryDark = Color(0xFFA1A1A1);

  static const Color accent = Color(0xFF0066FF);
  static const Color accentDark = Color(0xFF0066FF);

  static const Color green = Color(0xFF007A5A);
  static const Color greenLight = Color(0xFF10B981);
  static const Color amber = Color(0xFFE5A000);
  static const Color amberLight = Color(0xFFF5B014);
  static const Color red = Color(0xFFE5484D);
  static const Color redLight = Color(0xFFF87171);

  // Backgrounds are solid and neutral
  static const Color background = Color(0xFFF9F9F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF111111);

  static const Color backgroundDark = Color(
    0xFF000000,
  ); // OLED black background
  static const Color surfaceDark = Color(0xFF0A0A0A);
  static const Color onSurfaceDark = Color(0xFFEDEDED);

  // Deprecated. Kept to not break existing references during transition.
  static const Color neumorphSurface = Color(0xFFF9F9F9);
  static const Color neumorphSurfaceDark = Color(0xFF000000);
}
