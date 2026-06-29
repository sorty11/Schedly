import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'upload_timetable_pdf_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'add_lecture_page.dart';
import 'timetable_manager.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'delete_lecture_page.dart';
import 'create_announcement_page.dart';
import 'weekly_timetable_page.dart';
import 'student_roster_page.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/animated_button.dart';
import 'onboarding/widgets/tutorial_target.dart';

class CRPanelPage extends StatefulWidget {
  const CRPanelPage({super.key});

  @override
  State<CRPanelPage> createState() => _CRPanelPageState();
}

class _CRPanelPageState extends State<CRPanelPage> {
  Future<void> _logoutCR(BuildContext context) async {
    await AppSettings.resetRole();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exited role mode',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _addLecture() async {
    final lecture = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddLecturePage()),
    );
    if (lecture == null) return;

    final prefs = await SharedPreferences.getInstance();
    final division = prefs.getString('selected_division');
    if (division == null) return;

    await TimetableManager.addLecture(
      division: division,
      day: lecture['day'],
      entry: TimetableEntry(
        id: '${lecture['subject']}_${DateTime.now().millisecondsSinceEpoch}',
        subject: lecture['subject'],
        batch: lecture['batch'] ?? 'Whole Class',
        startTime: TimetableManager.parseTime(lecture['time'].split('-')[0].trim()),
        endTime: TimetableManager.parseTime(lecture['time'].split('-')[1].trim()),
        room: lecture['room'],
        category: EventCategory.academic,
        durationMinutes: 60,
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${lecture['subject']} added to ${lecture['day']}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  // ─── Action card: full-width row card ─────────────────────────────────────
  Widget _buildActionCard({
    required int staggerIndex,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    String? targetId,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

    Widget cardContent = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AnimatedCard(
        onTap: onTap,
          borderRadius: AppRadius.xl,
          backgroundColor: semanticColors.surfaceElevated,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: semanticColors.borderSubtle,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: AppSpacing.lg),

                // Text block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: semanticColors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: semanticColors.onSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      );

    if (targetId != null) {
      cardContent = TutorialTarget(
        id: targetId,
        child: cardContent,
      );
    }

    return StaggeredListItem(
      index: staggerIndex,
      child: cardContent,
    );
  }

  // ─── Section label ─────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label, {int staggerIndex = 0}) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return StaggeredListItem(
      index: staggerIndex,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xs,
          bottom: AppSpacing.sm,
          top: AppSpacing.lg,
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: semanticColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppSettings.currentRole != UserRole.cr &&
        AppSettings.currentRole != UserRole.sr) {
      return Scaffold(
        body: Center(
          child: Text(
            'Access Denied',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final isCR = AppSettings.currentRole == UserRole.cr;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final sectionId = AppSettings.sectionId ?? AppSettings.division ?? 'Division';

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          isCR ? 'CR Control Panel' : 'SR Control Panel',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient header card ────────────────────────────────────────
            StaggeredListItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.x2l),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCR
                        ? [AppColors.primary, AppColors.secondary]
                        : [AppColors.secondary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: (isCR ? AppColors.primary : AppColors.secondary)
                          .withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        isCR
                            ? Icons.star_rounded
                            : Icons.assignment_ind_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sectionId,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              isCR
                                  ? 'Class Representative'
                                  : 'Subject Representative${AppSettings.srSubject != null ? ' · ${AppSettings.srSubject}' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Timetable section ────────────────────────────────────────────
            _buildSectionLabel('Timetable', staggerIndex: 1),

            _buildActionCard(
              staggerIndex: 2,
              targetId: 'manage_lectures_btn',
              icon: Icons.edit_calendar_rounded,
              title: 'Edit Lectures',
              subtitle: isCR
                  ? 'Open full timetable editor'
                  : 'Edit your subject lectures',
              color: colorScheme.primary,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final division = prefs.getString('selected_division');
                if (!mounted || division == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeeklyTimetablePage(division: division),
                  ),
                );
              },
            ),

            _buildActionCard(
              staggerIndex: 3,
              icon: Icons.add_circle_outline_rounded,
              title: 'Add Lecture',
              subtitle: isCR
                  ? 'Add a new lecture to the timetable'
                  : 'Add a replacement or extra lecture',
              color: semanticColors.success,
              onTap: _addLecture,
            ),

            _buildActionCard(
              staggerIndex: 4,
              targetId: 'import_timetable_btn',
              icon: Icons.picture_as_pdf_rounded,
              title: 'Upload Timetable PDF',
              subtitle: 'Import schedule from official PDF',
              color: semanticColors.accent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UploadTimetablePdfPage(),
                  ),
                );
              },
            ),

            // ── Communication section (CR only) ─────────────────────────────
            if (isCR) ...[
              _buildSectionLabel('Communication', staggerIndex: 5),

              _buildActionCard(
                staggerIndex: 6,
                targetId: 'create_announcement_btn',
                icon: Icons.campaign_rounded,
                title: 'Announcements',
                subtitle: 'Broadcast messages to all students',
                color: colorScheme.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateAnnouncementPage(),
                    ),
                  );
                },
              ),
            ],

            // ── Roster section (CR only) ─────────────────────────────────────
            if (isCR) ...[
              _buildSectionLabel('Roster', staggerIndex: 7),

              _buildActionCard(
                staggerIndex: 8,
                icon: Icons.group_rounded,
                title: 'Class Roster',
                subtitle: 'View and manage registered students',
                color: semanticColors.pending,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final division = prefs.getString('selected_division');
                  if (!mounted || division == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentRosterPage(division: division),
                    ),
                  );
                },
              ),

              _buildActionCard(
                staggerIndex: 9,
                icon: Icons.delete_outline_rounded,
                title: 'Delete Lecture',
                subtitle: 'Remove a scheduled lecture',
                color: semanticColors.cancelled,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeleteLecturePage(),
                    ),
                  );
                },
              ),
            ],

            // ── Exit role card (subtle, warning-tinted) ──────────────────────
            const SizedBox(height: AppSpacing.sm),
            StaggeredListItem(
              index: isCR ? 10 : 5,
              child: Container(
                decoration: BoxDecoration(
                  color: semanticColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: semanticColors.warning.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: AnimatedCard(
                  borderRadius: AppRadius.xl,
                  backgroundColor: Colors.transparent,
                  onTap: () => _logoutCR(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: semanticColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          isCR ? 'Exit CR Mode' : 'Exit SR Mode',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: semanticColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x4l),
          ],
        ),
      ),
    );
  }
}
