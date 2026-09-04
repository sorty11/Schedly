import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart' show themeController;
import 'design_tokens.dart';
import 'app_colors.dart';
import 'visual_theme.dart';
import 'animated_theme_background.dart';
import '../widgets/animations/animated_card.dart';

class ThemesPage extends StatelessWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Themes',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: themeController,
          builder: (context, _) {
            final activeTheme = themeController.visualTheme;

            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2l,
                vertical: AppSpacing.lg,
              ),
              children: [
                Text(
                  'VISUAL PERSONALIZATION',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.9,
                    color: sem.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose your preferred visual aesthetic. All timetable information, attendance calculations, and permissions remain completely identical.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: sem.onSurfaceMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Theme Cards
                for (final theme in SchedlyVisualTheme.values) ...[
                  _ThemeCard(
                    theme: theme,
                    isSelected: activeTheme == theme,
                    isDark: isDark,
                    colorScheme: colorScheme,
                    sem: sem,
                    onTap: () => themeController.setVisualTheme(theme),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final SchedlyVisualTheme theme;
  final bool isSelected;
  final bool isDark;
  final ColorScheme colorScheme;
  final AppSemanticColors sem;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.isDark,
    required this.colorScheme,
    required this.sem,
    required this.onTap,
  });

  List<Color> _swatches(SchedlyVisualTheme theme) {
    switch (theme) {
      case SchedlyVisualTheme.defaultTheme:
        return const [
          Color(0xFF0066FF),
          Color(0xFF007A5A),
          Color(0xFF5E548E),
          Color(0xFFE5A000),
        ];
      case SchedlyVisualTheme.heritage:
        return const [
          Color(0xFFC86432),
          Color(0xFF5E8B4E),
          Color(0xFFD48827),
          Color(0xFF9E3B33),
        ];
      case SchedlyVisualTheme.future:
        return const [
          Color(0xFF00D8FF),
          Color(0xFF8B5CF6),
          Color(0xFF06D6A0),
          Color(0xFFFF3366),
        ];
      case SchedlyVisualTheme.bloom:
        return const [
          Color(0xFFE11D74),
          Color(0xFFC084FC),
          Color(0xFF34D399),
          Color(0xFFFB923C),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? colorScheme.primary
        : (isDark ? sem.borderSubtle : const Color(0xFFE8E8F0));

    return AnimatedCard(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      child: Container(
        decoration: BoxDecoration(
          color: sem.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Miniature Animated Preview
            SizedBox(
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedThemeCanvas(
                    theme: theme,
                    isDark: isDark,
                    isPreview: true,
                  ),
                  // Subtle inner vignette over preview
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (isDark
                              ? const Color(0xAA0A0A0A)
                              : const Color(0x55000000)),
                        ],
                      ),
                    ),
                  ),
                  // Active Badge on preview if selected
                  if (isSelected)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ACTIVE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Theme Info
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:
                          (isSelected
                                  ? colorScheme.primary
                                  : sem.onSurfaceMuted)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      theme.icon,
                      size: 20,
                      color: isSelected
                          ? colorScheme.primary
                          : sem.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.onSurfaceDark
                                : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          theme.description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: sem.onSurfaceMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Signature Palette Swatches
                        Row(
                          children: [
                            for (final color in _swatches(theme))
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected
                        ? colorScheme.primary
                        : sem.onSurfaceFaint,
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
