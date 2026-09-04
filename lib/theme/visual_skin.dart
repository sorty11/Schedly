import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'visual_theme.dart';

/// The central VisualSkin engine defining how Schedly looks and behaves per theme.
/// Every reusable component asks [VisualSkin.of(context)]: "How should I LOOK?"
abstract class VisualSkin {
  final SchedlyVisualTheme visualTheme;
  final bool isDark;

  const VisualSkin({required this.visualTheme, required this.isDark});

  static VisualSkin of(BuildContext context) {
    final ext = Theme.of(context).extension<SchedlySkinExtension>();
    if (ext != null) return ext.skin;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultSkin(isDark: isDark);
  }

  static VisualSkin fromTheme(
    SchedlyVisualTheme theme, {
    required bool isDark,
  }) {
    switch (theme) {
      case SchedlyVisualTheme.heritage:
        return HeritageSkin(isDark: isDark);
      case SchedlyVisualTheme.future:
        return FutureSkin(isDark: isDark);
      case SchedlyVisualTheme.bloom:
        return BloomSkin(isDark: isDark);
      case SchedlyVisualTheme.defaultTheme:
        return DefaultSkin(isDark: isDark);
    }
  }

  // ─── Visual Recipes ────────────────────────────────────────────────────────
  SkinCardRecipe get cardRecipe;
  SkinBadgeRecipe get badgeRecipe;
  SkinIconContainerRecipe get iconRecipe;
  SkinDaySelectorRecipe get daySelectorRecipe;
  SkinNavigationRecipe get navigationRecipe;
  SkinHeaderRecipe get headerRecipe;

  Color get primaryAccent;
  Color get surfaceBase;
  Color get surfaceElevated;
  Color get textPrimary;
  Color get textMuted;
  Color get borderLine;

  IconData getSubjectIcon(String subject, {String? component});
}

// ─── ThemeExtension for registering into ThemeData ───────────────────────────
class SchedlySkinExtension extends ThemeExtension<SchedlySkinExtension> {
  final VisualSkin skin;

  const SchedlySkinExtension({required this.skin});

  @override
  SchedlySkinExtension copyWith({VisualSkin? skin}) {
    return SchedlySkinExtension(skin: skin ?? this.skin);
  }

  @override
  SchedlySkinExtension lerp(
    ThemeExtension<SchedlySkinExtension>? other,
    double t,
  ) {
    if (other is! SchedlySkinExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension BuildContextSkin on BuildContext {
  VisualSkin get skin => VisualSkin.of(this);
}

// ═════════════════════════════════════════════════════════════════════════════
// RECIPE CONTRACTS
// ═════════════════════════════════════════════════════════════════════════════

abstract class SkinCardRecipe {
  BorderRadius get borderRadius;
  BoxDecoration decoration({
    required BuildContext context,
    required Color leftRailColor,
    bool isCancelled = false,
    bool isHighlighted = false,
  });
  EdgeInsets get padding;
  double get leftRailWidth;
}

abstract class SkinBadgeRecipe {
  Widget buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    bool isCancelled = false,
  });
}

abstract class SkinIconContainerRecipe {
  Widget buildContainer(
    BuildContext context, {
    required IconData icon,
    required Color color,
    bool isCancelled = false,
    double size = 50,
  });
}

abstract class SkinDaySelectorRecipe {
  Widget buildDayPill(
    BuildContext context, {
    required String dayName,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  });
}

abstract class SkinNavigationRecipe {
  BoxDecoration decoration(BuildContext context);
  Color get activeItemColor;
  Color get inactiveItemColor;
  Widget buildNavIndicator({required bool isSelected, required Widget child});
}

abstract class SkinHeaderRecipe {
  TextStyle get titleStyle;
  TextStyle get subtitleStyle;
  Widget buildActionPill(
    BuildContext context, {
    required String label,
    IconData? icon,
    required VoidCallback? onTap,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. DEFAULT SKIN — CLASSIC SCHEDLY (100% UNTOUCHED BASELINE)
// ═════════════════════════════════════════════════════════════════════════════

class DefaultSkin extends VisualSkin {
  const DefaultSkin({required super.isDark})
    : super(visualTheme: SchedlyVisualTheme.defaultTheme);

  @override
  Color get primaryAccent =>
      isDark ? AppColors.primaryLight : AppColors.primary;
  @override
  Color get surfaceBase =>
      isDark ? AppColors.backgroundDark : AppColors.background;
  @override
  Color get surfaceElevated =>
      isDark ? AppColors.surfaceDark : AppColors.surface;
  @override
  Color get textPrimary =>
      isDark ? AppColors.onSurfaceDark : AppColors.onSurface;
  @override
  Color get textMuted =>
      isDark ? const Color(0xFFA1A1A1) : const Color(0xFF666666);
  @override
  Color get borderLine =>
      isDark ? const Color(0xFF222222) : const Color(0xFFEBEBEB);

  @override
  SkinCardRecipe get cardRecipe => _DefaultCardRecipe(isDark: isDark);
  @override
  SkinBadgeRecipe get badgeRecipe => _DefaultBadgeRecipe(isDark: isDark);
  @override
  SkinIconContainerRecipe get iconRecipe => _DefaultIconRecipe(isDark: isDark);
  @override
  SkinDaySelectorRecipe get daySelectorRecipe =>
      _DefaultDaySelectorRecipe(isDark: isDark);
  @override
  SkinNavigationRecipe get navigationRecipe =>
      _DefaultNavigationRecipe(isDark: isDark);
  @override
  SkinHeaderRecipe get headerRecipe => _DefaultHeaderRecipe(isDark: isDark);

  @override
  IconData getSubjectIcon(String subject, {String? component}) {
    final s = subject.toLowerCase();
    if (s.contains('math') || s.contains('calculus') || s.contains('algebra')) {
      return Icons.calculate_rounded;
    }
    if (s.contains('code') ||
        s.contains('program') ||
        s.contains('oop') ||
        s.contains('java') ||
        s.contains('python') ||
        s.contains('se') ||
        s.contains('dsa')) {
      return Icons.computer_rounded;
    }
    if (s.contains('beee') || s.contains('electric') || s.contains('circuit')) {
      return Icons.electrical_services_rounded;
    }
    if (s.contains('physics')) return Icons.science_rounded;
    if (s.contains('chemistry') || s.contains('biotech')) {
      return Icons.biotech_rounded;
    }
    if (s.contains('dbms') || s.contains('data') || s.contains('sql')) {
      return Icons.storage_rounded;
    }
    if (s.contains('lade') || s.contains('book')) {
      return Icons.menu_book_rounded;
    }
    if (s.contains('ctps') || s.contains('ai') || s.contains('think')) {
      return Icons.lightbulb_rounded;
    }
    if (s.contains('lunch') || s.contains('break')) {
      return Icons.restaurant_rounded;
    }
    if (s.contains('lab') ||
        (component != null && component.toLowerCase().contains('lab'))) {
      return Icons.science_rounded;
    }
    return Icons.school_rounded;
  }
}

class _DefaultCardRecipe extends SkinCardRecipe {
  final bool isDark;
  _DefaultCardRecipe({required this.isDark});

  @override
  BorderRadius get borderRadius => BorderRadius.circular(16.0);

  @override
  double get leftRailWidth => 4.0;

  @override
  EdgeInsets get padding => const EdgeInsets.all(16.0);

  @override
  BoxDecoration decoration({
    required BuildContext context,
    required Color leftRailColor,
    bool isCancelled = false,
    bool isHighlighted = false,
  }) {
    final sem = Theme.of(context).extension<AppSemanticColors>();
    final cancelledColor = sem?.cancelled ?? const Color(0xFFEF4444);
    final borderColor =
        sem?.borderSubtle ??
        (isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5));
    final bgColor = isCancelled
        ? cancelledColor.withOpacity(0.04)
        : (isDark ? const Color(0xFF1F1F1F) : Colors.white);

    return BoxDecoration(
      color: bgColor,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class _DefaultBadgeRecipe extends SkinBadgeRecipe {
  final bool isDark;
  _DefaultBadgeRecipe({required this.isDark});

  @override
  Widget buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    bool isCancelled = false,
  }) {
    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'CANCELLED',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _DefaultIconRecipe extends SkinIconContainerRecipe {
  final bool isDark;
  _DefaultIconRecipe({required this.isDark});

  @override
  Widget buildContainer(
    BuildContext context, {
    required IconData icon,
    required Color color,
    bool isCancelled = false,
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _DefaultDaySelectorRecipe extends SkinDaySelectorRecipe {
  final bool isDark;
  _DefaultDaySelectorRecipe({required this.isDark});

  @override
  Widget buildDayPill(
    BuildContext context, {
    required String dayName,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primary
              : isToday
              ? primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: isToday && !isSelected
              ? Border.all(color: primary.withOpacity(0.3), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dayName,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? primary
                    : isDark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
            if (isToday && !isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DefaultNavigationRecipe extends SkinNavigationRecipe {
  final bool isDark;
  _DefaultNavigationRecipe({required this.isDark});

  @override
  BoxDecoration decoration(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>();
    final border =
        sem?.borderSubtle ??
        (isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5));
    return BoxDecoration(
      color: isDark
          ? AppColors.surfaceDark.withOpacity(0.90)
          : Colors.white.withOpacity(0.90),
      border: Border(top: BorderSide(color: border, width: 0.8)),
    );
  }

  @override
  Color get activeItemColor =>
      isDark ? AppColors.primaryLight : AppColors.primary;
  @override
  Color get inactiveItemColor =>
      isDark ? const Color(0xFFA1A1A1) : const Color(0xFF666666);

  @override
  Widget buildNavIndicator({required bool isSelected, required Widget child}) {
    return child;
  }
}

class _DefaultHeaderRecipe extends SkinHeaderRecipe {
  final bool isDark;
  _DefaultHeaderRecipe({required this.isDark});

  @override
  TextStyle get titleStyle => TextStyle(
    fontFamily: 'Outfit',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurface,
  );

  @override
  TextStyle get subtitleStyle => TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: isDark ? const Color(0xFFA1A1A1) : const Color(0xFF666666),
  );

  @override
  Widget buildActionPill(
    BuildContext context, {
    required String label,
    IconData? icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. HERITAGE SKIN — OLD SCHOOL RUST (ACADEMIC ARCHIVE, ENGRAVED TACTILE)
// ═════════════════════════════════════════════════════════════════════════════

class HeritageSkin extends VisualSkin {
  const HeritageSkin({required super.isDark})
    : super(visualTheme: SchedlyVisualTheme.heritage);

  @override
  Color get primaryAccent => const Color(0xFFC86432); // Aged rust
  @override
  Color get surfaceBase =>
      isDark ? const Color(0xFF131211) : const Color(0xFFF7F4EF);
  @override
  Color get surfaceElevated =>
      isDark ? const Color(0xFF1E1B18) : const Color(0xFFEFE9E0);
  @override
  Color get textPrimary =>
      isDark ? const Color(0xFFEDE5DA) : const Color(0xFF2B231D);
  @override
  Color get textMuted =>
      isDark ? const Color(0xFF9E9284) : const Color(0xFF7A6E60);
  @override
  Color get borderLine =>
      isDark ? const Color(0xFF38312A) : const Color(0xFFDDD3C4);

  @override
  SkinCardRecipe get cardRecipe => _HeritageCardRecipe(isDark: isDark);
  @override
  SkinBadgeRecipe get badgeRecipe => _HeritageBadgeRecipe(isDark: isDark);
  @override
  SkinIconContainerRecipe get iconRecipe => _HeritageIconRecipe(isDark: isDark);
  @override
  SkinDaySelectorRecipe get daySelectorRecipe =>
      _HeritageDaySelectorRecipe(isDark: isDark);
  @override
  SkinNavigationRecipe get navigationRecipe =>
      _HeritageNavigationRecipe(isDark: isDark);
  @override
  SkinHeaderRecipe get headerRecipe => _HeritageHeaderRecipe(isDark: isDark);

  @override
  IconData getSubjectIcon(String subject, {String? component}) {
    final s = subject.toLowerCase();
    if (s.contains('dsa') ||
        s.contains('algorithm') ||
        s.contains('data struct')) {
      return Icons.auto_stories_rounded; // Antique illuminated book
    }
    if (s.contains('se') ||
        s.contains('code') ||
        s.contains('program') ||
        s.contains('oop')) {
      return Icons.code_rounded; // Parchment code brackets
    }
    if (s.contains('dcca') ||
        s.contains('arch') ||
        s.contains('hardware') ||
        s.contains('circuit')) {
      return Icons.memory_rounded; // Engraved micro-module
    }
    if (s.contains('wdd') || s.contains('web') || s.contains('design')) {
      return Icons.science_rounded; // Alchemist flask
    }
    if (s.contains('pns') ||
        s.contains('prob') ||
        s.contains('stat') ||
        s.contains('math')) {
      return Icons.science_outlined; // Measuring vessel
    }
    if (s.contains('physics') || s.contains('lab')) {
      return Icons.biotech_rounded;
    }
    if (s.contains('lunch')) return Icons.local_cafe_rounded;
    return Icons.menu_book_rounded;
  }
}

class _HeritageCardRecipe extends SkinCardRecipe {
  final bool isDark;
  _HeritageCardRecipe({required this.isDark});

  @override
  BorderRadius get borderRadius => BorderRadius.circular(14.0);

  @override
  double get leftRailWidth => 4.0;

  @override
  EdgeInsets get padding => const EdgeInsets.fromLTRB(14, 14, 14, 14);

  @override
  BoxDecoration decoration({
    required BuildContext context,
    required Color leftRailColor,
    bool isCancelled = false,
    bool isHighlighted = false,
  }) {
    final surfaceColor = isDark
        ? const Color(0xFF1A1715)
        : const Color(0xFFFAF7F2);
    final borderOuter = isDark
        ? const Color(0xFF38312A)
        : const Color(0xFFD8CEBF);

    return BoxDecoration(
      color: surfaceColor,
      borderRadius: borderRadius,
      border: Border.all(color: borderOuter, width: 1.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        // Subtle inner warm glow
        BoxShadow(
          color: (isDark ? const Color(0xFFC86432) : const Color(0xFFE8C8A0))
              .withOpacity(0.03),
          blurRadius: 1,
        ),
      ],
    );
  }
}

class _HeritageBadgeRecipe extends SkinBadgeRecipe {
  final bool isDark;
  _HeritageBadgeRecipe({required this.isDark});

  @override
  Widget buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    bool isCancelled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withOpacity(0.45), width: 1.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Newsreader',
          fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}

class _HeritageIconRecipe extends SkinIconContainerRecipe {
  final bool isDark;
  _HeritageIconRecipe({required this.isDark});

  @override
  Widget buildContainer(
    BuildContext context, {
    required IconData icon,
    required Color color,
    bool isCancelled = false,
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF221E1A) : const Color(0xFFF0EAE1),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: color.withOpacity(0.40), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.40 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7.0),
          border: Border.all(color: color.withOpacity(0.20), width: 0.8),
        ),
        child: Center(
          child: Icon(icon, color: color, size: size * 0.46),
        ),
      ),
    );
  }
}

class _HeritageDaySelectorRecipe extends SkinDaySelectorRecipe {
  final bool isDark;
  _HeritageDaySelectorRecipe({required this.isDark});

  @override
  Widget buildDayPill(
    BuildContext context, {
    required String dayName,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark ? const Color(0xFF6B4226) : const Color(0xFFB86B3E);
    final activeText = const Color(0xFFF7EFE6);
    final unselectedText = isDark
        ? const Color(0xFF8A7D6E)
        : const Color(0xFF7A6B5C);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10.0),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFFD49B5A).withOpacity(0.5),
                  width: 1.0,
                )
              : isToday
              ? Border.all(
                  color: const Color(0xFF8A7D6E).withOpacity(0.4),
                  width: 1.0,
                )
              : Border.all(color: Colors.transparent, width: 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          dayName,
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? activeText : unselectedText,
          ),
        ),
      ),
    );
  }
}

class _HeritageNavigationRecipe extends SkinNavigationRecipe {
  final bool isDark;
  _HeritageNavigationRecipe({required this.isDark});

  @override
  BoxDecoration decoration(BuildContext context) {
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF131211).withOpacity(0.96)
          : const Color(0xFFF7F4EF).withOpacity(0.96),
      border: Border(
        top: BorderSide(
          color: isDark ? const Color(0xFF38312A) : const Color(0xFFD8CEBF),
          width: 1.0,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  @override
  Color get activeItemColor => const Color(0xFFD49B5A); // Warm antique amber
  @override
  Color get inactiveItemColor =>
      isDark ? const Color(0xFF8A7D6E) : const Color(0xFF7A6B5C);

  @override
  Widget buildNavIndicator({required bool isSelected, required Widget child}) {
    return child;
  }
}

class _HeritageHeaderRecipe extends SkinHeaderRecipe {
  final bool isDark;
  _HeritageHeaderRecipe({required this.isDark});

  @override
  TextStyle get titleStyle => TextStyle(
    fontFamily: 'Newsreader',
    fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: isDark ? const Color(0xFFEDE5DA) : const Color(0xFF2B231D),
  );

  @override
  TextStyle get subtitleStyle => TextStyle(
    fontFamily: 'Newsreader',
    fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
    fontSize: 13,
    fontStyle: FontStyle.italic,
    color: isDark ? const Color(0xFF9E9284) : const Color(0xFF7A6E60),
  );

  @override
  Widget buildActionPill(
    BuildContext context, {
    required String label,
    IconData? icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF221E1A) : const Color(0xFFEDE5DA),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isDark ? const Color(0xFF4A4035) : const Color(0xFFC8BEAE),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isDark
                    ? const Color(0xFFD49B5A)
                    : const Color(0xFF8A5A2B),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontFamilyFallback: const [
                  'Playfair Display',
                  'Georgia',
                  'serif',
                ],
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFEDE5DA)
                    : const Color(0xFF2B231D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. FUTURE SKIN — NEO FUTURE (HIGH-TECH PRECISION, LUMINOUS CYBER OS)
// ═════════════════════════════════════════════════════════════════════════════

class FutureSkin extends VisualSkin {
  const FutureSkin({required super.isDark})
    : super(visualTheme: SchedlyVisualTheme.future);

  @override
  Color get primaryAccent => const Color(0xFF00E5FF); // Electric cyan
  @override
  Color get surfaceBase =>
      isDark ? const Color(0xFF070A0F) : const Color(0xFFEDF3F9);
  @override
  Color get surfaceElevated =>
      isDark ? const Color(0xFF0F1522) : const Color(0xFFE2EAF2);
  @override
  Color get textPrimary =>
      isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0B1623);
  @override
  Color get textMuted =>
      isDark ? const Color(0xFF6E849E) : const Color(0xFF5A728A);
  @override
  Color get borderLine =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFCDD9E5);

  @override
  SkinCardRecipe get cardRecipe => _FutureCardRecipe(isDark: isDark);
  @override
  SkinBadgeRecipe get badgeRecipe => _FutureBadgeRecipe(isDark: isDark);
  @override
  SkinIconContainerRecipe get iconRecipe => _FutureIconRecipe(isDark: isDark);
  @override
  SkinDaySelectorRecipe get daySelectorRecipe =>
      _FutureDaySelectorRecipe(isDark: isDark);
  @override
  SkinNavigationRecipe get navigationRecipe =>
      _FutureNavigationRecipe(isDark: isDark);
  @override
  SkinHeaderRecipe get headerRecipe => _FutureHeaderRecipe(isDark: isDark);

  @override
  IconData getSubjectIcon(String subject, {String? component}) {
    final s = subject.toLowerCase();
    if (s.contains('dsa') || s.contains('algorithm') || s.contains('ai')) {
      return Icons.psychology_rounded; // Cyber neural net
    }
    if (s.contains('se') ||
        s.contains('code') ||
        s.contains('program') ||
        s.contains('oop')) {
      return Icons.terminal_rounded; // Matrix terminal
    }
    if (s.contains('dcca') ||
        s.contains('hardware') ||
        s.contains('arch') ||
        s.contains('circuit')) {
      return Icons.developer_board_rounded; // Micro-processor chip
    }
    if (s.contains('wdd') || s.contains('web')) {
      return Icons.science_rounded; // High-tech vial
    }
    if (s.contains('pns') || s.contains('prob') || s.contains('math')) {
      return Icons.hub_rounded; // Network nodes
    }
    if (s.contains('physics') || s.contains('lab')) {
      return Icons.blur_on_rounded;
    }
    if (s.contains('lunch')) return Icons.battery_charging_full_rounded;
    return Icons.schema_rounded;
  }
}

class _FutureCardRecipe extends SkinCardRecipe {
  final bool isDark;
  _FutureCardRecipe({required this.isDark});

  @override
  BorderRadius get borderRadius => BorderRadius.circular(10.0);

  @override
  double get leftRailWidth => 3.5;

  @override
  EdgeInsets get padding => const EdgeInsets.fromLTRB(14, 14, 14, 14);

  @override
  BoxDecoration decoration({
    required BuildContext context,
    required Color leftRailColor,
    bool isCancelled = false,
    bool isHighlighted = false,
  }) {
    final surfaceColor = isDark
        ? const Color(0xFF0B1019)
        : const Color(0xFFF4F8FC);
    final borderColor = isCancelled
        ? const Color(0xFFFF3366)
        : const Color(0xFF00E5FF).withOpacity(isDark ? 0.25 : 0.35);

    return BoxDecoration(
      color: surfaceColor,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: [
        BoxShadow(
          color: leftRailColor.withOpacity(isDark ? 0.12 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class _FutureBadgeRecipe extends SkinBadgeRecipe {
  final bool isDark;
  _FutureBadgeRecipe({required this.isDark});

  @override
  Widget buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    bool isCancelled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withOpacity(0.80), width: 1.0),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 5)],
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

class _FutureIconRecipe extends SkinIconContainerRecipe {
  final bool isDark;
  _FutureIconRecipe({required this.isDark});

  @override
  Widget buildContainer(
    BuildContext context, {
    required IconData icon,
    required Color color,
    bool isCancelled = false,
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1522) : const Color(0xFFE5EFF9),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withOpacity(0.85), width: 1.2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.40), blurRadius: 8)],
      ),
      child: Center(
        child: Icon(icon, color: color, size: size * 0.48),
      ),
    );
  }
}

class _FutureDaySelectorRecipe extends SkinDaySelectorRecipe {
  final bool isDark;
  _FutureDaySelectorRecipe({required this.isDark});

  @override
  Widget buildDayPill(
    BuildContext context, {
    required String dayName,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    final cyanGlow = const Color(0xFF00E5FF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? cyanGlow
              : isToday
              ? cyanGlow.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          border: isSelected
              ? Border.all(color: Colors.white, width: 1.0)
              : Border.all(
                  color: isToday
                      ? cyanGlow.withOpacity(0.4)
                      : Colors.transparent,
                  width: 1.0,
                ),
          boxShadow: isSelected
              ? [BoxShadow(color: cyanGlow.withOpacity(0.60), blurRadius: 10)]
              : null,
        ),
        child: Text(
          dayName,
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.black
                : isDark
                ? const Color(0xFF7E97B5)
                : const Color(0xFF4A6482),
          ),
        ),
      ),
    );
  }
}

class _FutureNavigationRecipe extends SkinNavigationRecipe {
  final bool isDark;
  _FutureNavigationRecipe({required this.isDark});

  @override
  BoxDecoration decoration(BuildContext context) {
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF070A0F).withOpacity(0.96)
          : const Color(0xFFEDF3F9).withOpacity(0.96),
      border: Border(
        top: BorderSide(
          color: const Color(0xFF00E5FF).withOpacity(0.35),
          width: 1.2,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00E5FF).withOpacity(0.12),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  @override
  Color get activeItemColor => const Color(0xFF00E5FF); // Electric cyan
  @override
  Color get inactiveItemColor =>
      isDark ? const Color(0xFF55687D) : const Color(0xFF6F8297);

  @override
  Widget buildNavIndicator({required bool isSelected, required Widget child}) {
    return child;
  }
}

class _FutureHeaderRecipe extends SkinHeaderRecipe {
  final bool isDark;
  _FutureHeaderRecipe({required this.isDark});

  @override
  TextStyle get titleStyle => TextStyle(
    fontFamily: 'Space Grotesk',
    fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0B1623),
  );

  @override
  TextStyle get subtitleStyle => TextStyle(
    fontFamily: 'Space Grotesk',
    fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
    fontSize: 13,
    color: isDark ? const Color(0xFF6E849E) : const Color(0xFF5A728A),
  );

  @override
  Widget buildActionPill(
    BuildContext context, {
    required String label,
    IconData? icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1726) : const Color(0xFFDDE8F4),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.50),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.20),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: const Color(0xFF00E5FF)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. BLOOM SKIN — VIBRANT (LIFESTYLE BOUTIQUE, SOFT PASTEL SQUIRCLE)
// ═════════════════════════════════════════════════════════════════════════════

class BloomSkin extends VisualSkin {
  const BloomSkin({required super.isDark})
    : super(visualTheme: SchedlyVisualTheme.bloom);

  @override
  Color get primaryAccent => const Color(0xFFFF5376); // Vibrant rose
  @override
  Color get surfaceBase =>
      isDark ? const Color(0xFF1B121C) : const Color(0xFFFFF6F8);
  @override
  Color get surfaceElevated =>
      isDark ? const Color(0xFF271A29) : const Color(0xFFFFFFFF);
  @override
  Color get textPrimary =>
      isDark ? const Color(0xFFFDF2F7) : const Color(0xFF2A1221);
  @override
  Color get textMuted =>
      isDark ? const Color(0xFFBAA3B5) : const Color(0xFF826278);
  @override
  Color get borderLine =>
      isDark ? const Color(0xFF452B41) : const Color(0xFFF5DDE7);

  @override
  SkinCardRecipe get cardRecipe => _BloomCardRecipe(isDark: isDark);
  @override
  SkinBadgeRecipe get badgeRecipe => _BloomBadgeRecipe(isDark: isDark);
  @override
  SkinIconContainerRecipe get iconRecipe => _BloomIconRecipe(isDark: isDark);
  @override
  SkinDaySelectorRecipe get daySelectorRecipe =>
      _BloomDaySelectorRecipe(isDark: isDark);
  @override
  SkinNavigationRecipe get navigationRecipe =>
      _BloomNavigationRecipe(isDark: isDark);
  @override
  SkinHeaderRecipe get headerRecipe => _BloomHeaderRecipe(isDark: isDark);

  @override
  IconData getSubjectIcon(String subject, {String? component}) {
    final s = subject.toLowerCase();
    if (s.contains('dsa') || s.contains('book') || s.contains('learning')) {
      return Icons.menu_book_rounded;
    }
    if (s.contains('se') ||
        s.contains('code') ||
        s.contains('program') ||
        s.contains('oop')) {
      return Icons.code_rounded;
    }
    if (s.contains('dcca') || s.contains('hardware') || s.contains('circuit')) {
      return Icons.widgets_rounded; // Soft modular blocks
    }
    if (s.contains('wdd') || s.contains('web') || s.contains('lab')) {
      return Icons.science_rounded; // Cute flask
    }
    if (s.contains('pns') || s.contains('prob') || s.contains('stat')) {
      return Icons.bubble_chart_rounded;
    }
    if (s.contains('lunch')) return Icons.restaurant_rounded;
    return Icons.auto_stories_rounded;
  }
}

class _BloomCardRecipe extends SkinCardRecipe {
  final bool isDark;
  _BloomCardRecipe({required this.isDark});

  @override
  BorderRadius get borderRadius => BorderRadius.circular(22.0);

  @override
  double get leftRailWidth => 4.5;

  @override
  EdgeInsets get padding => const EdgeInsets.fromLTRB(16, 16, 16, 16);

  @override
  BoxDecoration decoration({
    required BuildContext context,
    required Color leftRailColor,
    bool isCancelled = false,
    bool isHighlighted = false,
  }) {
    final surfaceColor = isDark ? const Color(0xFF261928) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF452B41)
        : const Color(0xFFF9E4EC);

    return BoxDecoration(
      color: surfaceColor,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: [
        BoxShadow(
          color: (isDark ? Colors.black : const Color(0xFFFF699A)).withOpacity(
            isDark ? 0.35 : 0.08,
          ),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _BloomBadgeRecipe extends SkinBadgeRecipe {
  final bool isDark;
  _BloomBadgeRecipe({required this.isDark});

  @override
  Widget buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    bool isCancelled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.22 : 0.16),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _BloomIconRecipe extends SkinIconContainerRecipe {
  final bool isDark;
  _BloomIconRecipe({required this.isDark});

  @override
  Widget buildContainer(
    BuildContext context, {
    required IconData icon,
    required Color color,
    bool isCancelled = false,
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.22 : 0.16),
        borderRadius: BorderRadius.circular(18.0),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.20 : 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: color, size: size * 0.48),
      ),
    );
  }
}

class _BloomDaySelectorRecipe extends SkinDaySelectorRecipe {
  final bool isDark;
  _BloomDaySelectorRecipe({required this.isDark});

  @override
  Widget buildDayPill(
    BuildContext context, {
    required String dayName,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    final activeColor = const Color(0xFFFF5376); // Berry rose

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : isToday
              ? activeColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20.0),
          border: isToday && !isSelected
              ? Border.all(color: activeColor.withOpacity(0.35), width: 1.0)
              : Border.all(color: Colors.transparent, width: 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.40),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          dayName,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : isDark
                ? const Color(0xFFBAA3B5)
                : const Color(0xFF826278),
          ),
        ),
      ),
    );
  }
}

class _BloomNavigationRecipe extends SkinNavigationRecipe {
  final bool isDark;
  _BloomNavigationRecipe({required this.isDark});

  @override
  BoxDecoration decoration(BuildContext context) {
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF1B121C).withOpacity(0.96)
          : const Color(0xFFFFF8FA).withOpacity(0.96),
      border: Border(
        top: BorderSide(
          color: isDark ? const Color(0xFF452B41) : const Color(0xFFF5DDE7),
          width: 1.0,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF5376).withOpacity(isDark ? 0.15 : 0.06),
          blurRadius: 14,
          offset: const Offset(0, -3),
        ),
      ],
    );
  }

  @override
  Color get activeItemColor => const Color(0xFFFF5376); // Berry rose
  @override
  Color get inactiveItemColor =>
      isDark ? const Color(0xFFBAA3B5) : const Color(0xFF9E8496);

  @override
  Widget buildNavIndicator({required bool isSelected, required Widget child}) {
    return child;
  }
}

class _BloomHeaderRecipe extends SkinHeaderRecipe {
  final bool isDark;
  _BloomHeaderRecipe({required this.isDark});

  @override
  TextStyle get titleStyle => TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: isDark ? const Color(0xFFFDF2F7) : const Color(0xFF2A1221),
  );

  @override
  TextStyle get subtitleStyle => TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
    fontSize: 13,
    color: isDark ? const Color(0xFFBAA3B5) : const Color(0xFF826278),
  );

  @override
  Widget buildActionPill(
    BuildContext context, {
    required String label,
    IconData? icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E1C2E) : const Color(0xFFFFEDF3),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: const Color(0xFFFF5376).withOpacity(0.35),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: const Color(0xFFFF5376)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFFDF2F7)
                    : const Color(0xFF2A1221),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
