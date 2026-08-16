import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

class CommandPaletteOverlay extends StatelessWidget {
  const CommandPaletteOverlay({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      barrierDismissible: true,
      barrierLabel: 'Dismiss Command Palette',
      transitionDuration: AppDuration.standard,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: AppCurves.spring),
            ),
            child: const CommandPaletteOverlay(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: 600,
              height: 400,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161616).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: sem.borderSubtle, width: 1),
                boxShadow: AppShadow.level4(sem.accent, isDark: isDark),
              ),
              child: Column(
                children: [
                  // Search Input Shell
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: sem.onSurfaceMuted,
                          size: AppIconSize.lg,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Search or jump to...',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              color: sem.onSurfaceMuted,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF222222)
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'ESC',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sem.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: sem.borderSubtle),

                  // Content Shell
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: sem.onSurfaceMuted.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Command Palette coming soon',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: sem.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
