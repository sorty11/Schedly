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

// ─── Curated Lecture Type Colors Extension ────────────────────────────────────
class SchedlyLectureTypeColors
    extends ThemeExtension<SchedlyLectureTypeColors> {
  final Color theory;
  final Color lab;
  final Color tutorial;
  final Color practical;
  final Color project;
  final Color seminar;
  final Color viva;
  final Color event;
  final Color other;
  final Color lunch;

  const SchedlyLectureTypeColors({
    required this.theory,
    required this.lab,
    required this.tutorial,
    required this.practical,
    required this.project,
    required this.seminar,
    required this.viva,
    required this.event,
    required this.other,
    required this.lunch,
  });

  Color resolve({String? component, String? subject}) {
    final s = (subject ?? '').toLowerCase();
    if (s.contains('lunch') || s.contains('break')) {
      return lunch;
    }
    final c = (component ?? '').trim().toLowerCase();
    if (c.contains('theor') || c.contains('lect') || c == 'th') return theory;
    if (c.contains('lab') || c == 'la') return lab;
    if (c.contains('tut') || c == 'tu') return tutorial;
    if (c.contains('prac') || c == 'pr') return practical;
    if (c.contains('proj')) return project;
    if (c.contains('sem')) return seminar;
    if (c.contains('viva')) return viva;
    if (c.contains('event') || c.contains('activ')) return event;

    // Deterministic subject hash fallback within the theme's core harmonious type palette
    final palette = [theory, lab, tutorial, practical, project, seminar];
    final hash = (subject ?? 'schedly').hashCode.abs();
    return palette[hash % palette.length];
  }

  @override
  SchedlyLectureTypeColors copyWith({
    Color? theory,
    Color? lab,
    Color? tutorial,
    Color? practical,
    Color? project,
    Color? seminar,
    Color? viva,
    Color? event,
    Color? other,
    Color? lunch,
  }) {
    return SchedlyLectureTypeColors(
      theory: theory ?? this.theory,
      lab: lab ?? this.lab,
      tutorial: tutorial ?? this.tutorial,
      practical: practical ?? this.practical,
      project: project ?? this.project,
      seminar: seminar ?? this.seminar,
      viva: viva ?? this.viva,
      event: event ?? this.event,
      other: other ?? this.other,
      lunch: lunch ?? this.lunch,
    );
  }

  @override
  SchedlyLectureTypeColors lerp(
    ThemeExtension<SchedlyLectureTypeColors>? other,
    double t,
  ) {
    if (other is! SchedlyLectureTypeColors) return this;
    return SchedlyLectureTypeColors(
      theory: Color.lerp(theory, other.theory, t)!,
      lab: Color.lerp(lab, other.lab, t)!,
      tutorial: Color.lerp(tutorial, other.tutorial, t)!,
      practical: Color.lerp(practical, other.practical, t)!,
      project: Color.lerp(project, other.project, t)!,
      seminar: Color.lerp(seminar, other.seminar, t)!,
      viva: Color.lerp(viva, other.viva, t)!,
      event: Color.lerp(event, other.event, t)!,
      other: Color.lerp(this.other, other.other, t)!,
      lunch: Color.lerp(lunch, other.lunch, t)!,
    );
  }
}

// ─── 1. DEFAULT PALETTES (Classic Schedly - Unchanged Baseline) ───────────────
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

const darkSemanticColors = AppSemanticColors(
  pending: Color(0xFFF5B014),
  conducted: Color(0xFF10B981),
  cancelled: Color(0xFFF87171),
  rescheduled: Color(0xFF818CF8),
  success: Color(0xFF10B981),
  warning: Color(0xFFF5B014),
  error: Color(0xFFF87171),
  accent: Color(0xFF0066FF), // Unchanged Electric Blue
  surfaceElevated: Color(0xFF0A0A0A),
  surfaceElevated2: Color(0xFF111111),
  surfaceTinted: Color(0xFF0D1524),
  borderSubtle: Color(0xFF222222),
  borderFocus: Color(0xFF0066FF),
  onSurfaceMuted: Color(0xFFA1A1A1),
  onSurfaceFaint: Color(0xFF737373),
);

const defaultLightLectureColors = SchedlyLectureTypeColors(
  theory: Color(0xFF0066FF),
  lab: Color(0xFF007A5A),
  tutorial: Color(0xFF5E548E),
  practical: Color(0xFF0284C7),
  project: Color(0xFFE5A000),
  seminar: Color(0xFF8B5CF6),
  viva: Color(0xFFE5484D),
  event: Color(0xFF2563EB),
  other: Color(0xFF666666),
  lunch: Color(0xFFF59E0B),
);

const defaultDarkLectureColors = SchedlyLectureTypeColors(
  theory: Color(0xFF3B82F6),
  lab: Color(0xFF10B981),
  tutorial: Color(0xFF818CF8),
  practical: Color(0xFF38BDF8),
  project: Color(0xFFF5B014),
  seminar: Color(0xFFA78BFA),
  viva: Color(0xFFF87171),
  event: Color(0xFF60A5FA),
  other: Color(0xFFA1A1A1),
  lunch: Color(0xFFFBBF24),
);

// ─── 2. HERITAGE PALETTES (Old School Rust & Academic Editorial) ─────────────
const heritageLightSemanticColors = AppSemanticColors(
  pending: Color(0xFFB87010), // Warm amber brass
  conducted: Color(0xFF406B33), // Olive grove
  cancelled: Color(0xFF8E2C24), // Rich oxblood
  rescheduled: Color(0xFF693D53), // Dusty plum
  success: Color(0xFF406B33),
  warning: Color(0xFFB87010),
  error: Color(0xFF8E2C24),
  accent: Color(0xFFA34820), // Aged rust copper
  surfaceElevated: Color(0xFFFFFFFF),
  surfaceElevated2: Color(0xFFF7F3EB), // Antique parchment card
  surfaceTinted: Color(0xFFFAF5ED),
  borderSubtle: Color(0xFFE5DDD0), // Warm bookbinder rule
  borderFocus: Color(0xFFA34820),
  onSurfaceMuted: Color(0xFF6B6154), // Sepia graphite
  onSurfaceFaint: Color(0xFF9C9182),
);

const heritageDarkSemanticColors = AppSemanticColors(
  pending: Color(0xFFD48827), // Antique brass
  conducted: Color(0xFF5E8B4E), // Deep olive
  cancelled: Color(0xFF9E3B33), // Oxblood
  rescheduled: Color(0xFF7D5265), // Dusty plum
  success: Color(0xFF5E8B4E),
  warning: Color(0xFFD48827),
  error: Color(0xFF9E3B33),
  accent: Color(0xFFC86432), // Rust copper
  surfaceElevated: Color(0xFF1A1715), // Deep warm charcoal slate
  surfaceElevated2: Color(0xFF221F1C), // Slightly raised leather plate
  surfaceTinted: Color(0xFF241D17),
  borderSubtle: Color(0xFF332D27), // Subtle aged brass rule
  borderFocus: Color(0xFFC86432),
  onSurfaceMuted: Color(0xFFA89F91), // Weathered antique ink
  onSurfaceFaint: Color(0xFF786F63),
);

const heritageLightLectureColors = SchedlyLectureTypeColors(
  theory: Color(0xFFA34820), // Rust copper
  lab: Color(0xFF406B33), // Olive
  tutorial: Color(0xFF693D53), // Dusty plum
  practical: Color(0xFF336360), // Verdigris
  project: Color(0xFFB87010), // Antique amber
  seminar: Color(0xFF7A5C3E), // Saddle leather
  viva: Color(0xFF8E2C24), // Oxblood
  event: Color(0xFF8C5329), // Tobacco bronze
  other: Color(0xFF6B6154),
  lunch: Color(0xFFB87010),
);

const heritageDarkLectureColors = SchedlyLectureTypeColors(
  theory: Color(0xFFC86432), // Rust copper
  lab: Color(0xFF5E8B4E), // Aged olive
  tutorial: Color(0xFF7D5265), // Dusty plum
  practical: Color(0xFF467B78), // Oxidized verdigris
  project: Color(0xFFD48827), // Antique brass amber
  seminar: Color(0xFFA37B55), // Tobacco brown
  viva: Color(0xFF9E3B33), // Oxblood
  event: Color(0xFFB37340), // Warm clay
  other: Color(0xFF8C8172),
  lunch: Color(0xFFD48827),
);

// ─── 3. FUTURE PALETTES (Neo Future & Luminous Cybernetic Precision) ─────────
const futureLightSemanticColors = AppSemanticColors(
  pending: Color(0xFFD97706),
  conducted: Color(0xFF059669),
  cancelled: Color(0xFFE11D48),
  rescheduled: Color(0xFF7C3AED),
  success: Color(0xFF059669),
  warning: Color(0xFFD97706),
  error: Color(0xFFE11D48),
  accent: Color(0xFF0284C7), // High-tech azure
  surfaceElevated: Color(0xFFFFFFFF),
  surfaceElevated2: Color(0xFFF0F5FA),
  surfaceTinted: Color(0xFFEAF2FB),
  borderSubtle: Color(0xFFD6E2EE),
  borderFocus: Color(0xFF0284C7),
  onSurfaceMuted: Color(0xFF53647B),
  onSurfaceFaint: Color(0xFF8A9BAE),
);

const futureDarkSemanticColors = AppSemanticColors(
  pending: Color(0xFFFBBF24), // Cyber amber
  conducted: Color(0xFF06D6A0), // Neon emerald
  cancelled: Color(0xFFFF3366), // Laser crimson
  rescheduled: Color(0xFF8B5CF6), // Ultraviolet
  success: Color(0xFF06D6A0),
  warning: Color(0xFFFBBF24),
  error: Color(0xFFFF3366),
  accent: Color(0xFF00D8FF), // Electric cyan
  surfaceElevated: Color(0xFF0B111D), // Abyssal gunmetal
  surfaceElevated2: Color(0xFF121B2C),
  surfaceTinted: Color(0xFF0F1E36),
  borderSubtle: Color(0xFF1E2F48), // Thin luminous gunmetal border
  borderFocus: Color(0xFF00D8FF),
  onSurfaceMuted: Color(0xFF8899B0),
  onSurfaceFaint: Color(0xFF53647B),
);

const futureLightLectureColors = SchedlyLectureTypeColors(
  theory: Color(0xFF0284C7), // High-tech Azure
  lab: Color(0xFF059669), // Emerald
  tutorial: Color(0xFF7C3AED), // Violet
  practical: Color(0xFF0EA5E9), // Cyan
  project: Color(0xFFD97706), // Amber
  seminar: Color(0xFFC026D3), // Magenta
  viva: Color(0xFFE11D48), // Laser red
  event: Color(0xFF4F46E5), // Indigo
  other: Color(0xFF53647B),
  lunch: Color(0xFFD97706),
);

const futureDarkLectureColors = SchedlyLectureTypeColors(
  theory: Color(0xFF00D8FF), // Electric Cyan
  lab: Color(0xFF06D6A0), // Neon Emerald
  tutorial: Color(0xFF8B5CF6), // Ultraviolet
  practical: Color(0xFF38BDF8), // Azure
  project: Color(0xFFFBBF24), // Cyber Amber
  seminar: Color(0xFFE879F9), // Neon Magenta
  viva: Color(0xFFFF3366), // Laser Crimson
  event: Color(0xFF6366F1), // Electric Indigo
  other: Color(0xFF64748B),
  lunch: Color(0xFFFBBF24),
);

// ─── 4. BLOOM PALETTES (Chic Feminine Boutique & Soft Pastel Sophistication) ──
const bloomLightSemanticColors = AppSemanticColors(
  pending: Color(0xFFD97736), // Warm peach amber
  conducted: Color(0xFF16A390), // Soft mint seafoam
  cancelled: Color(0xFFD9465B), // Dusty raspberry
  rescheduled: Color(0xFF9855D4), // Soft wisteria lavender
  success: Color(0xFF16A390), // Soft mint
  warning: Color(0xFFD97736), // Peach warning
  error: Color(0xFFD9465B), // Dusty raspberry
  accent: Color(0xFFDE527B), // French blush / dusty rose
  surfaceElevated: Color(0xFFFFFFFF),
  surfaceElevated2: Color(0xFFFAF2F5), // Delicate blush card
  surfaceTinted: Color(0xFFFBF4F7), // Porcelain blush
  borderSubtle: Color(0xFFF1DEE6), // Delicate pastel rose border
  borderFocus: Color(0xFFDE527B),
  onSurfaceMuted: Color(0xFF7E6678), // Mauve charcoal
  onSurfaceFaint: Color(0xFFAA95A6),
);

const bloomDarkSemanticColors = AppSemanticColors(
  pending: Color(0xFFF59E0B), // Honey amber
  conducted: Color(0xFF2DD4BF), // Soft mint
  cancelled: Color(0xFFE8607A), // Muted berry rose
  rescheduled: Color(0xFFC084FC), // Soft lavender
  success: Color(0xFF2DD4BF),
  warning: Color(0xFFF59E0B),
  error: Color(0xFFE8607A),
  accent: Color(0xFFEC729C), // Glowing blush rose
  surfaceElevated: Color(0xFF19111C), // Velvet mulberry night
  surfaceElevated2: Color(0xFF231728), // Raised plum surface
  surfaceTinted: Color(0xFF291A2E),
  borderSubtle: Color(0xFF3E2844), // Subtle wine plum rule
  borderFocus: Color(0xFFEC729C),
  onSurfaceMuted: Color(0xFFBAA3BC), // Dusty mauve
  onSurfaceFaint: Color(0xFF8B738D),
);

const bloomLightLectureColors = SchedlyLectureTypeColors(
  theory: Color(0xFFD94877), // Dusty rose
  lab: Color(0xFF16A390), // Soft mint
  tutorial: Color(0xFF8B5CF6), // Soft lavender
  practical: Color(0xFF3B82F6), // Soft periwinkle
  project: Color(0xFFE86C45), // Peach coral
  seminar: Color(0xFFC04B8C), // Mauve plum
  viva: Color(0xFFB52E52), // Rosewood
  event: Color(0xFF7C3AED), // Violet
  other: Color(0xFF7E6678),
  lunch: Color(0xFFF59E0B),
);

const bloomDarkLectureColors = SchedlyLectureTypeColors(
  theory: Color(0xFFEC729C), // Blush rose
  lab: Color(0xFF2DD4BF), // Soft mint
  tutorial: Color(0xFFC084FC), // Lavender
  practical: Color(0xFF38BDF8), // Sky
  project: Color(0xFFFB923C), // Peach
  seminar: Color(0xFFF43F5E), // Coral
  viva: Color(0xFFFB7185), // Rose
  event: Color(0xFFA78BFA), // Periwinkle
  other: Color(0xFFBAA3BC),
  lunch: Color(0xFFF59E0B),
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
