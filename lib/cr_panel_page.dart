import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'upload_timetable_pdf_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'widgets/timetable_studio_sheet.dart';
import 'timetable_manager.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'delete_lecture_page.dart';
import 'create_announcement_page.dart';
import 'draft_studio_page.dart';
import 'manual_timetable_studio.dart';
import 'student_roster_page.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/app_dialogs.dart';

import 'onboarding/widgets/tutorial_target.dart';
import 'services/subject_metadata_service.dart';
import 'course_details_setup_page.dart';

class CRPanelPage extends StatefulWidget {
  const CRPanelPage({super.key});

  @override
  State<CRPanelPage> createState() => _CRPanelPageState();
}

class _CRPanelPageState extends State<CRPanelPage> {
  bool _setupComplete = true;
  bool _isCheckingSetup = true;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final sectionId = AppSettings.sectionId ?? AppSettings.division;
    if (sectionId == null) {
      if (mounted) setState(() => _isCheckingSetup = false);
      return;
    }
    try {
      final complete = await SubjectMetadataService.isSetupComplete(sectionId);
      if (mounted) setState(() { _setupComplete = complete; _isCheckingSetup = false; });
    } catch (_) {
      if (mounted) setState(() => _isCheckingSetup = false);
    }
  }

  Future<void> _logoutCR(BuildContext context) async {
    await AppSettings.resetRole();
    if (!context.mounted) return;
    AppDialogs.showSnackBar(
      context: context,
      message: 'Exited role mode',
    );
    Navigator.pop(context);
  }

  Future<void> _addLecture() async {
    final prefs = await SharedPreferences.getInstance();
    final division = prefs.getString('selected_division');
    if (division == null) return;

    if (!mounted) return;
    await TimetableStudioSheet.show(
      context,
      division: division,
      initialDay: 'Monday', // Provide a default day, user can change it
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
            if (isCR && !_isCheckingSetup && !_setupComplete) ...[
              _buildSectionLabel('Action Required', staggerIndex: 0),
              _buildActionCard(
                staggerIndex: 1,
                icon: Icons.warning_amber_rounded,
                title: 'Complete Course Details',
                subtitle: 'Required for Analytics and Semester Progress',
                color: semanticColors.warning,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailsSetupPage(
                        division: sectionId,
                      ),
                    ),
                  );
                  _checkSetup(); // recheck when back
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
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
                if (!context.mounted || division == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManualTimetableStudio(
                        division: division, editMode: true),
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
              title: 'Upload Timetable PDF (BETA)',
              subtitle: 'Import schedule from official PDF',
              color: Colors.amber, // Highlight that it's an amber badge feature
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
                  if (!context.mounted || division == null) return;
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

              _buildActionCard(
                staggerIndex: 10,
                icon: Icons.delete_forever_rounded,
                title: 'Delete Timetable',
                subtitle: 'Permanently remove the entire published timetable',
                color: Colors.red,
                onTap: () => _deleteTimetable(context, sectionId),
              ),
            ],

            // ── Exit role card (subtle, warning-tinted) ──────────────────────
            const SizedBox(height: AppSpacing.sm),
            StaggeredListItem(
              index: isCR ? 11 : 5,
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

  Future<void> _deleteTimetable(BuildContext context, String division) async {
    final TextEditingController _ctrl = TextEditingController();
    bool confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Delete Timetable?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete the published timetable and all drafts. Students will see "No Timetable".', style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 16),
            Text('Type DELETE to confirm:', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (_ctrl.text.trim() == 'DELETE') {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed || !context.mounted) return;

    // Execute deletion
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    for (final day in days) {
      final snap = await FirebaseFirestore.instance.collection('timetables').doc(division).collection(day).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timetablePublished', false);
    final keys = prefs.getKeys().where((k) => k.startsWith('studio_draft_'));
    for (final k in keys) {
      await prefs.remove(k);
    }

    if (context.mounted) {
      AppDialogs.showSnackBar(
        context: context,
        message: 'Timetable deleted permanently.',
        isError: true,
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }
}
