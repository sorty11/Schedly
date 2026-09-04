import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_settings.dart';
import '../../theme/theme.dart';
import '../../user_roles.dart';
import '../../widgets/animations/animated_card.dart';
import '../../widgets/animations/staggered_list_item.dart';
import '../../widgets/app_dialogs.dart';
import '../models/tutorial_tour.dart';
import '../services/onboarding_service.dart';
import '../services/tutorial_registry.dart';
import '../services/tutorial_storage_service.dart';
import '../services/whats_new_service.dart';
import '../widgets/cc_character.dart';

class TutorialsHelpPage extends StatefulWidget {
  const TutorialsHelpPage({super.key});

  @override
  State<TutorialsHelpPage> createState() => _TutorialsHelpPageState();
}

class _TutorialsHelpPageState extends State<TutorialsHelpPage> {
  UserRole get currentRole => AppSettings.currentRole;

  Widget _sectionHeader(String label) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
        top: AppSpacing.xl,
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: semanticColors.onSurfaceMuted,
        ),
      ),
    );
  }

  Widget _buildTourTile({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return StaggeredListItem(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AnimatedCard(
          borderRadius: AppRadius.xl,
          backgroundColor: semanticColors.surfaceElevated,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: semanticColors.borderSubtle, width: 1),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: iconColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: semanticColors.onSurfaceMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: iconColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _replayMainTour() {
    Navigator.of(context).pop();
    OnboardingService.instance.startRoleTour(context, currentRole);
  }

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final skin = VisualSkin.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tutorials & Help',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero Banner ──────────────────────────────────────────────
            StaggeredListItem(
              index: 0,
              child: AnimatedCard(
                borderRadius: AppRadius.xl,
                backgroundColor: skin.primaryAccent.withValues(alpha: 0.08),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: skin.primaryAccent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const CCCharacter(size: 64, expression: CCExpression.happy),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Campus Companion Guide',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Replay interactive spotlights or discover newly added Schedly V11 features anytime.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: semanticColors.onSurfaceMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── What's New Section ────────────────────────────────────────
            _sectionHeader("What's New in V11"),
            _buildTourTile(
              index: 1,
              title: "What's New in Schedly V11",
              subtitle: '4 Visual Skins, attendance skip math, and refined timetables',
              icon: Icons.auto_awesome_rounded,
              iconColor: skin.primaryAccent,
              badgeText: 'V11',
              onTap: () {
                WhatsNewService.showWhatsNew(context, currentRole);
              },
            ),

            // ── Role Getting Started Tour ─────────────────────────────────
            _sectionHeader('Getting Started Tours'),
            _buildTourTile(
              index: 2,
              title: currentRole == UserRole.faculty
                  ? 'Faculty Portal Tour'
                  : (currentRole == UserRole.cr
                      ? 'CR Control Panel Tour'
                      : (currentRole == UserRole.sr
                          ? 'SR Subject Guide Tour'
                          : 'Student Getting Started Tour')),
              subtitle: 'Step-by-step interactive walkthrough of all main navigation tabs',
              icon: Icons.route_rounded,
              iconColor: semanticColors.accent,
              onTap: _replayMainTour,
            ),

            // ── Feature Guides ───────────────────────────────────────────
            _sectionHeader('Feature Guides'),
            _buildTourTile(
              index: 3,
              title: 'Themes & Visual Skins',
              subtitle: 'Preview Classic Schedly, Heritage, Neo Future, and Bloom',
              icon: Icons.palette_outlined,
              iconColor: Colors.purple,
              onTap: () async {
                Navigator.of(context).pop();
                await TutorialStorageService.resetTour('themes_discovery');
              },
            ),
            _buildTourTile(
              index: 4,
              title: 'Attendance & Safe Skip Limits',
              subtitle: 'Understand minimum attendance targets and absence limits',
              icon: Icons.calculate_outlined,
              iconColor: semanticColors.conducted,
              onTap: () async {
                Navigator.of(context).pop();
                await TutorialStorageService.resetTour('attendance_discovery');
              },
            ),
            _buildTourTile(
              index: 5,
              title: 'Monthly Calendar & Date Overrides',
              subtitle: 'Learn how Schedly resolves one-time changes vs weekly recurrence',
              icon: Icons.calendar_month_outlined,
              iconColor: Colors.blue,
              onTap: () async {
                Navigator.of(context).pop();
                await TutorialStorageService.resetTour('monthly_timetable_discovery');
              },
            ),

            // ── Reset Section ─────────────────────────────────────────────
            _sectionHeader('Reset All Hints'),
            StaggeredListItem(
              index: 6,
              child: AnimatedCard(
                borderRadius: AppRadius.xl,
                backgroundColor: semanticColors.surfaceElevated,
                onTap: () async {
                  final confirmed = await AppDialogs.showConfirm(
                    context: context,
                    title: 'Reset All Tutorial Hints?',
                    message:
                        'This will allow all onboarding guides, contextual tips, and What’s New modals to appear again naturally.',
                    confirmText: 'Reset Hints',
                    isDestructive: true,
                  );
                  if (confirmed) {
                    await TutorialStorageService.resetAll();
                    if (!context.mounted) return;
                    AppDialogs.showSnackBar(
                      context: context,
                      message: 'All tutorial hints have been reset.',
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: semanticColors.cancelled.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: semanticColors.cancelled.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.restart_alt_rounded,
                          color: semanticColors.cancelled,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset All Hints & Tours',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: semanticColors.cancelled,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Re-enable all automatic hints as if launching fresh',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: semanticColors.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3l),
          ],
        ),
      ),
    );
  }
}

