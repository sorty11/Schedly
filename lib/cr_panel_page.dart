import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diagnostic_service.dart';
import 'home_page.dart';
import 'services/notification_service.dart';

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
import 'weekly_timetable_page.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/app_dialogs.dart';

import 'onboarding/widgets/tutorial_target.dart';
import 'services/course_configuration_service.dart';
import 'course_details_setup_page.dart';
import 'cr/cr_faculty_requests_page.dart';
import 'cr/cr_faculty_view_page.dart';
import 'cr/sr_faculty_view_page.dart';
import 'cr/cr_password_management_page.dart';
import 'settings/batch_management_page.dart';

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
      final complete = await CourseConfigurationService.isSetupComplete(
        sectionId,
      );
      if (mounted)
        setState(() {
          _setupComplete = complete;
          _isCheckingSetup = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isCheckingSetup = false);
    }
  }

  Future<void> _logoutCR(BuildContext context) async {
    final isCR = AppSettings.currentRole == UserRole.cr;
    final division = AppSettings.sectionId ?? AppSettings.division;

    final confirmed = await AppDialogs.showConfirm(
      context: context,
      title: isCR ? 'Exit CR Mode?' : 'Exit SR Mode?',
      message: isCR
          ? 'You will return to student mode for this division. You can switch back to CR mode anytime with your section password.'
          : 'You will return to student mode for this division.',
      confirmText: 'Exit',
      isDestructive: false,
    );

    if (!confirmed || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Update Firestore user role to Student
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'role': 'Student',
          'srSubject': FieldValue.delete(),
          'srComponent': FieldValue.delete(),
          'srBatch': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Update section membership role to Student if division is known
        if (division != null && division.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('section_memberships')
              .doc('${division}_${user.uid}')
              .set({
                'role': 'Student',
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      }

      // 3. Save local role as Student
      await AppSettings.saveRole(UserRole.student);

      // 4. Clear SR-specific local fields
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sr_division');
      await prefs.remove('sr_subject');
      await prefs.remove('sr_component');
      await prefs.remove('sr_section_id');
      await prefs.remove('sr_batch');
      AppSettings.srDivision = null;
      AppSettings.srSubject = null;
      AppSettings.srComponent = null;
      AppSettings.srSectionId = null;
      AppSettings.srBatch = null;

      // 5. Update FCM topic subscriptions for student role
      if (division != null && division.isNotEmpty) {
        NotificationService.updateDivisionSubscription(division).catchError((
          e,
        ) {
          debugPrint('Exit CR: Notification subscription update error: $e');
        });
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      AppDialogs.showSnackBar(
        context: context,
        message: isCR
            ? 'Exited CR Mode. You are now in Student mode.'
            : 'Exited SR Mode. You are now in Student mode.',
      );

      final targetDivision = division ?? AppSettings.division ?? 'CE';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(division: targetDivision)),
        (_) => false,
      );
    } catch (e) {
      debugPrint('Error exiting role mode: $e');
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
        AppDialogs.showError(
          context: context,
          title: 'Error',
          message: 'Failed to exit role mode: $e',
        );
      }
    }
  }

  Future<void> _addLecture() async {
    final division = AppSettings.sectionId ?? AppSettings.division;
    if (division == null) return;

    if (!mounted) return;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final weekday = DateTime.now().weekday;
    final initialDay = weekday >= 1 && weekday <= 6
        ? days[weekday - 1]
        : 'Monday';

    await TimetableStudioSheet.show(
      context,
      division: division,
      initialDay: initialDay,
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
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: AnimatedCard(
        onTap: onTap,
        borderRadius: AppRadius.xl,
        backgroundColor: semanticColors.surfaceElevated,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: semanticColors.borderSubtle, width: 1),
          ),
          padding: EdgeInsets.all(AppSpacing.xl),
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
      cardContent = TutorialTarget(id: targetId, child: cardContent);
    }

    return StaggeredListItem(index: staggerIndex, child: cardContent);
  }

  // ─── CR Hero Card ─────────────────────────────────────────────────────────
  Widget _buildCRHeroCard({
    required BuildContext context,
    required String sectionId,
  }) {
    final skin = VisualSkin.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _CRHeroCardPalette.resolve(skin.visualTheme, isDark);

    return StaggeredListItem(
      index: 0,
      child: AnimatedCard(
        borderRadius: AppRadius.xl,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.cardGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: palette.borderColor,
              width: 1.2,
            ),
            boxShadow: [
              if (palette.specularColor != null)
                BoxShadow(
                  color: palette.specularColor!,
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              BoxShadow(
                color: palette.shadowColor,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: palette.iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: palette.iconBorderColor,
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadowColor,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: palette.iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              // Title and Role badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sectionId,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: palette.titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.badgeBg,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: palette.badgeBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle: 0.785398, // 45 deg diamond pip
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: palette.pipColor,
                                shape: BoxShape.rectangle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Class Representative',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: palette.badgeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section label ─────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label, {int staggerIndex = 0}) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return StaggeredListItem(
      index: staggerIndex,
      child: Padding(
        padding: EdgeInsets.only(
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
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final isCR = AppSettings.currentRole == UserRole.cr;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final sectionId =
        AppSettings.sectionId ?? AppSettings.division ?? 'Division';

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
        padding: EdgeInsets.symmetric(
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
                      builder: (context) =>
                          CourseDetailsSetupPage(division: sectionId),
                    ),
                  );
                  _checkSetup(); // recheck when back
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // ── Header card: Clean modern surface card for SR; gradient card for CR ──
            if (!isCR)
              StaggeredListItem(
                index: 0,
                child: AnimatedCard(
                  borderRadius: AppRadius.xl,
                  backgroundColor: semanticColors.surfaceElevated,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: semanticColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            Icons.assignment_ind_rounded,
                            color: colorScheme.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sectionId,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondary.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.full,
                                        ),
                                        border: Border.all(
                                          color: colorScheme.secondary
                                              .withValues(alpha: 0.18),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Subject Representative${AppSettings.srSubject != null ? ' · ${AppSettings.srSubject}' : ''}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.secondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              _buildCRHeroCard(
                context: context,
                sectionId: sectionId,
              ),

            // ── Timetable section ────────────────────────────────────────────
            _buildSectionLabel('Timetable', staggerIndex: 1),

            _buildActionCard(
              staggerIndex: 2,
              targetId: 'edit_lecture_btn',
              icon: Icons.edit_calendar_rounded,
              title: 'Edit Lectures',
              subtitle: isCR
                  ? 'Open full timetable editor'
                  : 'Edit your subject lectures',
              color: colorScheme.primary,
              onTap: () async {
                final division = AppSettings.sectionId ?? AppSettings.division;
                if (!context.mounted || division == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeeklyTimetablePage(
                      division: division,
                      isEditMode: true,
                    ),
                  ),
                );
              },
            ),

            _buildActionCard(
              staggerIndex: 3,
              targetId: 'replace_lecture_btn',
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

            // ── Settings section (CR only) ─────────────────────────────
            if (isCR) ...[
              _buildSectionLabel('Settings', staggerIndex: 6),
              _buildActionCard(
                staggerIndex: 7,
                targetId: 'role_password_management_btn',
                icon: Icons.lock_outline_rounded,
                title: 'Role Password Management',
                subtitle: 'Manage CR and SR passwords securely',
                color: colorScheme.error,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CRPasswordManagementPage(division: sectionId),
                    ),
                  );
                },
              ),
              _buildActionCard(
                staggerIndex: 8,
                targetId: 'batch_management_btn',
                icon: Icons.group_rounded,
                title: 'Batch Management',
                subtitle:
                    'Rename batches (e.g., ${(AppSettings.division ?? 'A').split('_').last}1 → Batch Alpha)',
                color: colorScheme.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BatchManagementPage(),
                    ),
                  );
                },
              ),
            ],

            // ── Roster section (CR only) ─────────────────────────────────────
            if (isCR) ...[
              _buildSectionLabel('Roster', staggerIndex: 8),

              _buildActionCard(
                staggerIndex: 9,
                icon: Icons.group_rounded,
                title: 'Class Roster',
                subtitle: 'View and manage registered students',
                color: semanticColors.pending,
                targetId: 'student_roster_btn',
                onTap: () async {
                  final division =
                      AppSettings.sectionId ?? AppSettings.division;
                  await DiagnosticService.logNavigation(
                    'StudentRosterPage',
                    division,
                  );
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
                icon: Icons.school_rounded,
                title: 'Faculty Roster',
                subtitle: 'View assigned faculty and subjects',
                targetId: 'faculty_roster_btn',
                color: semanticColors.pending,
                onTap: () async {
                  final division =
                      AppSettings.sectionId ?? AppSettings.division;
                  await DiagnosticService.logNavigation(
                    'CRFacultyViewPage',
                    division,
                  );
                  if (!context.mounted || division == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CRFacultyViewPage(division: division),
                    ),
                  );
                },
              ),

              _buildActionCard(
                staggerIndex: 10,
                icon: Icons.hourglass_empty_rounded,
                title: 'Pending Faculty Requests',
                subtitle: 'Approve or deny lecture changes',
                targetId: 'faculty_requests_btn',
                color: semanticColors.pending,
                onTap: () async {
                  final division =
                      AppSettings.sectionId ?? AppSettings.division;
                  await DiagnosticService.logNavigation(
                    'CRFacultyRequestsPage',
                    division,
                  );
                  if (!context.mounted || division == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CRFacultyRequestsPage(division: division),
                    ),
                  );
                },
              ),

              _buildActionCard(
                staggerIndex: 11,
                targetId: 'cancel_lecture_btn',
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
                staggerIndex: 12,
                icon: Icons.delete_forever_rounded,
                title: 'Delete Timetable',
                subtitle: 'Permanently remove the entire published timetable',
                color: Colors.red,
                onTap: () => _deleteTimetable(context, sectionId),
              ),
            ],

            if (!isCR) ...[
              _buildSectionLabel('Faculty Connection', staggerIndex: 8),
              _buildActionCard(
                staggerIndex: 9,
                icon: Icons.school_rounded,
                title: 'Assigned Faculty',
                subtitle:
                    'View faculty teaching ${AppSettings.srSubject ?? 'your subject'}',
                color: colorScheme.primary,
                onTap: () {
                  final division =
                      AppSettings.sectionId ?? AppSettings.division;
                  if (division == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SRFacultyViewPage(
                        division: division,
                        subject: AppSettings.srSubject ?? '',
                      ),
                    ),
                  );
                },
              ),
              _buildActionCard(
                staggerIndex: 10,
                icon: Icons.hourglass_empty_rounded,
                title: 'Faculty Requests',
                subtitle:
                    'View lecture requests for ${AppSettings.srSubject ?? 'your subject'}',
                color: semanticColors.pending,
                onTap: () {
                  final division =
                      AppSettings.sectionId ?? AppSettings.division;
                  if (division == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CRFacultyRequestsPage(division: division),
                    ),
                  );
                },
              ),
            ],

            // ── Exit role card (subtle, warning-tinted) ──────────────────────
            const SizedBox(height: AppSpacing.sm),
            StaggeredListItem(
              index: isCR ? 11 : 5,
              child: AnimatedCard(
                borderRadius: AppRadius.xl,
                backgroundColor: semanticColors.surfaceElevated,
                onTap: () => _logoutCR(context),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: semanticColors.warning.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
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
            const SizedBox(height: AppSpacing.x4l),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          showDialog(
            context: context,
            builder: (_) =>
                const AlertDialog(content: CircularProgressIndicator()),
          );

          final result = await DiagnosticService.runDiagnostics();

          if (!context.mounted) return;
          Navigator.pop(context); // pop loading

          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Diagnostics'),
              content: SingleChildScrollView(child: SelectableText(result)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.bug_report),
      ),
    );
  }

  Future<void> _deleteTimetable(BuildContext context, String division) async {
    final TextEditingController _ctrl = TextEditingController();
    bool confirmed =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            title: Text(
              'Delete Timetable?',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete the published timetable and all drafts. Students will see "No Timetable".',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'Type DELETE to confirm:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
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
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    // Execute deletion
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    for (final day in days) {
      final snap = await FirebaseFirestore.instance
          .collection('timetables')
          .doc(division)
          .collection(day)
          .get();
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

class _CRHeroCardPalette {
  final List<Color> cardGradient;
  final Color borderColor;
  final Color? specularColor;
  final Color shadowColor;
  final List<Color> iconGradient;
  final Color iconBorderColor;
  final Color iconColor;
  final Color titleColor;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeText;
  final Color pipColor;

  const _CRHeroCardPalette({
    required this.cardGradient,
    required this.borderColor,
    this.specularColor,
    required this.shadowColor,
    required this.iconGradient,
    required this.iconBorderColor,
    required this.iconColor,
    required this.titleColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeText,
    required this.pipColor,
  });

  factory _CRHeroCardPalette.resolve(SchedlyVisualTheme theme, bool isDark) {
    switch (theme) {
      case SchedlyVisualTheme.champion:
        return _CRHeroCardPalette(
          cardGradient: isDark
              ? const [Color(0xFF1E1828), Color(0xFF120E1A)]
              : const [Color(0xFFFFFDF8), Color(0xFFF7F1E3)],
          borderColor: isDark
              ? const Color(0xFFFFD700).withValues(alpha: 0.40)
              : const Color(0xFFB4831B).withValues(alpha: 0.35),
          specularColor: isDark
              ? const Color(0xFFFFE57F).withValues(alpha: 0.22)
              : const Color(0xFFFFE57F).withValues(alpha: 0.14),
          shadowColor: isDark
              ? const Color(0xFFFFD700).withValues(alpha: 0.08)
              : const Color(0xFFB4831B).withValues(alpha: 0.06),
          iconGradient: isDark
              ? const [Color(0xFF2C223A), Color(0xFF181222)]
              : const [Color(0xFFFBF4E2), Color(0xFFEFE2C2)],
          iconBorderColor: isDark
              ? const Color(0xFFFFD700).withValues(alpha: 0.50)
              : const Color(0xFFB4831B).withValues(alpha: 0.40),
          iconColor: const Color(0xFFFFD700),
          titleColor: isDark ? const Color(0xFFFFFDF5) : const Color(0xFF1A1408),
          badgeBg: const Color(0xFFFFD700).withValues(alpha: isDark ? 0.14 : 0.10),
          badgeBorder: const Color(0xFFFFD700).withValues(alpha: isDark ? 0.38 : 0.28),
          badgeText: isDark ? const Color(0xFFFFE57F) : const Color(0xFF8A6205),
          pipColor: const Color(0xFFFFD700),
        );
      case SchedlyVisualTheme.heritage:
        return _CRHeroCardPalette(
          cardGradient: isDark
              ? const [Color(0xFF251C17), Color(0xFF17110D)]
              : const [Color(0xFFFAF6F0), Color(0xFFF1E9DC)],
          borderColor: isDark
              ? const Color(0xFFC25E38).withValues(alpha: 0.38)
              : const Color(0xFFD9822B).withValues(alpha: 0.32),
          specularColor: isDark
              ? const Color(0xFFD9822B).withValues(alpha: 0.18)
              : null,
          shadowColor: isDark
              ? const Color(0xFFC25E38).withValues(alpha: 0.08)
              : const Color(0xFFD9822B).withValues(alpha: 0.06),
          iconGradient: isDark
              ? const [Color(0xFF36271F), Color(0xFF201611)]
              : const [Color(0xFFF3ECE0), Color(0xFFE5DAC9)],
          iconBorderColor: const Color(0xFFC25E38).withValues(alpha: 0.45),
          iconColor: const Color(0xFFD9822B),
          titleColor: isDark ? const Color(0xFFFDF8F3) : const Color(0xFF2B1D14),
          badgeBg: const Color(0xFFC25E38).withValues(alpha: isDark ? 0.15 : 0.10),
          badgeBorder: const Color(0xFFC25E38).withValues(alpha: 0.35),
          badgeText: isDark ? const Color(0xFFF5B57F) : const Color(0xFF9E401E),
          pipColor: const Color(0xFFD9822B),
        );
      case SchedlyVisualTheme.future:
        return _CRHeroCardPalette(
          cardGradient: isDark
              ? const [Color(0xFF111724), Color(0xFF0A0E17)]
              : const [Color(0xFFF0FDFF), Color(0xFFE2F7FB)],
          borderColor: isDark
              ? const Color(0xFF00F2FE).withValues(alpha: 0.38)
              : const Color(0xFF00B4D8).withValues(alpha: 0.35),
          specularColor: isDark
              ? const Color(0xFF00F2FE).withValues(alpha: 0.20)
              : null,
          shadowColor: isDark
              ? const Color(0xFF00F2FE).withValues(alpha: 0.10)
              : const Color(0xFF00B4D8).withValues(alpha: 0.06),
          iconGradient: isDark
              ? const [Color(0xFF182338), Color(0xFF0E1624)]
              : const [Color(0xFFDEF7FB), Color(0xFFCBEFF7)],
          iconBorderColor: const Color(0xFF00F2FE).withValues(alpha: 0.50),
          iconColor: const Color(0xFF00F2FE),
          titleColor: isDark ? const Color(0xFFF0FBFF) : const Color(0xFF0A1F2C),
          badgeBg: const Color(0xFF00F2FE).withValues(alpha: isDark ? 0.15 : 0.10),
          badgeBorder: const Color(0xFF00F2FE).withValues(alpha: 0.40),
          badgeText: isDark ? const Color(0xFF7DF9FF) : const Color(0xFF007799),
          pipColor: const Color(0xFF00F2FE),
        );
      case SchedlyVisualTheme.bloom:
        return _CRHeroCardPalette(
          cardGradient: isDark
              ? const [Color(0xFF251622), Color(0xFF160E15)]
              : const [Color(0xFFFFF6F9), Color(0xFFFCEBF2)],
          borderColor: isDark
              ? const Color(0xFFDE527B).withValues(alpha: 0.38)
              : const Color(0xFFDE527B).withValues(alpha: 0.32),
          specularColor: isDark
              ? const Color(0xFFFF8DA9).withValues(alpha: 0.18)
              : null,
          shadowColor: isDark
              ? const Color(0xFFDE527B).withValues(alpha: 0.08)
              : const Color(0xFFDE527B).withValues(alpha: 0.06),
          iconGradient: isDark
              ? const [Color(0xFF381F32), Color(0xFF22121E)]
              : const [Color(0xFFFDE7F0), Color(0xFFF9D6E4)],
          iconBorderColor: const Color(0xFFDE527B).withValues(alpha: 0.45),
          iconColor: const Color(0xFFDE527B),
          titleColor: isDark ? const Color(0xFFFFF4F7) : const Color(0xFF2C101B),
          badgeBg: const Color(0xFFDE527B).withValues(alpha: isDark ? 0.15 : 0.10),
          badgeBorder: const Color(0xFFDE527B).withValues(alpha: 0.35),
          badgeText: isDark ? const Color(0xFFFF9EB5) : const Color(0xFFA8264D),
          pipColor: const Color(0xFFDE527B),
        );
      case SchedlyVisualTheme.defaultTheme:
        return _CRHeroCardPalette(
          cardGradient: isDark
              ? const [Color(0xFF161E2E), Color(0xFF0E1320)]
              : const [Color(0xFFFFFFFF), Color(0xFFF4F7FC)],
          borderColor: isDark
              ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
              : const Color(0xFFCBD5E1),
          specularColor: isDark
              ? const Color(0xFF60A5FA).withValues(alpha: 0.16)
              : null,
          shadowColor: isDark
              ? const Color(0xFF020617).withValues(alpha: 0.50)
              : const Color(0xFF64748B).withValues(alpha: 0.08),
          iconGradient: isDark
              ? const [Color(0xFF1E293B), Color(0xFF131C2E)]
              : const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          iconBorderColor: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
              : const Color(0xFFBFDBFE),
          iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          titleColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          badgeBg: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.14)
              : const Color(0xFFDBEAFE),
          badgeBorder: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.32)
              : const Color(0xFF93C5FD),
          badgeText: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
          pipColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
        );
    }
  }
}
