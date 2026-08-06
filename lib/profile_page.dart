import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/notification_service.dart';

import 'app_settings.dart';
import 'user_roles.dart';
import 'role_verification_page.dart';
import 'cr_panel_page.dart';
import 'sr_conduct_dashboard.dart';
import 'onboarding_flow.dart';
import 'theme/theme.dart';
import 'main.dart';
import 'widgets/animations/animated_list_tile.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'onboarding/widgets/tutorial_target.dart';
import 'onboarding/services/tutorial_storage_service.dart';
import 'onboarding/services/onboarding_service.dart';
import 'onboarding/services/tutorial_controller.dart';
import 'widgets/app_dialogs.dart';

import 'about_schedly_page.dart';
import 'widgets/support/bug_report_sheet.dart';
import 'widgets/support/feature_request_sheet.dart';
import 'admin/admin_session.dart';
import 'admin/admin_auth_sheet.dart';
import 'admin/student_management_page.dart';
import 'admin/faculty_management_page.dart';
import 'admin/section_management_page.dart';

class ProfilePage extends StatefulWidget {
  final String division;

  const ProfilePage({
    super.key,
    required this.division,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _refresh() async {
    await AppSettings.loadRole();
    await AppSettings.loadSRDetails();
    if (mounted) setState(() {});
  }

  String get roleText {
    switch (AppSettings.currentRole) {
      case UserRole.cr:
        return 'CR';
      case UserRole.sr:
        return 'SR';
      default:
        return 'Student';
    }
  }

  // ─── Section header ──────────────────────────────────────────────────────
  Widget _sectionHeader(String label) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
        top: AppSpacing.x2l,
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
          color: semanticColors.onSurfaceMuted,
        ),
      ),
    );
  }

  // ─── Appearance 3-segment pill selector ──────────────────────────────────
  Widget _buildAppearanceSegment() {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
        final current = themeController.themeMode;

        return Container(
          decoration: BoxDecoration(
            color: semanticColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: semanticColors.borderSubtle, width: 1),
          ),
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              _appearancePill(
                label: 'Light',
                icon: Icons.wb_sunny_rounded,
                mode: ThemeMode.light,
                selected: current == ThemeMode.light,
                colorScheme: colorScheme,
                semanticColors: semanticColors,
              ),
              const SizedBox(width: AppSpacing.sm),
              _appearancePill(
                label: 'System',
                icon: Icons.language_rounded,
                mode: ThemeMode.system,
                selected: current == ThemeMode.system,
                colorScheme: colorScheme,
                semanticColors: semanticColors,
              ),
              const SizedBox(width: AppSpacing.sm),
              _appearancePill(
                label: 'Dark',
                icon: Icons.nightlight_round,
                mode: ThemeMode.dark,
                selected: current == ThemeMode.dark,
                colorScheme: colorScheme,
                semanticColors: semanticColors,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _appearancePill({
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required bool selected,
    required ColorScheme colorScheme,
    required AppSemanticColors semanticColors,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => themeController.setThemeMode(mode),
        child: AnimatedContainer(
          duration: AppDuration.standard,
          curve: AppCurves.standard,
          padding: EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? Colors.white
                    : semanticColors.onSurfaceMuted,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : semanticColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Role action tile inside a card container ────────────────────────────
  Widget _buildTileGroup(List<Widget> tiles) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: semanticColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: semanticColors.borderSubtle, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.x2l,
                endIndent: AppSpacing.x2l,
                color: semanticColors.borderSubtle,
              ),
          ],
        ],
      ),
    );
  }

  // ─── Individual role tile ────────────────────────────────────────────────
  Widget _buildRoleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    bool isDestructive = false,
    String? targetId,
  }) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final effectiveColor = isDestructive ? semanticColors.cancelled : iconColor;

    Widget tile = AnimatedListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: effectiveColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDestructive
              ? semanticColors.cancelled
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: semanticColors.onSurfaceMuted,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: isDestructive
            ? semanticColors.cancelled.withValues(alpha: 0.5)
            : semanticColors.onSurfaceMuted,
      ),
    );

    if (targetId != null) {
      return TutorialTarget(
        id: targetId,
        child: tile,
      );
    }
    return tile;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final isCR = AppSettings.currentRole == UserRole.cr;
    final isSR = AppSettings.currentRole == UserRole.sr;
    final name = AppSettings.studentName ?? 'Student';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'My Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero header card ──────────────────────────────────────────
            StaggeredListItem(
              index: 0,
              child: AnimatedCard(
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
                  padding: EdgeInsets.all(AppSpacing.x2l),
                  child: Column(
                    children: [
                      // Avatar — gradient circle with a clean ring, no glow
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Name
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Roll number chip
                      if (AppSettings.studentRollNo != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_rounded,
                                  size: 13, color: colorScheme.primary),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                AppSettings.studentRollNo!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),

                      // Division + Role chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _infoChip(
                            icon: Icons.class_rounded,
                            label: widget.division,
                            bgColor:
                                semanticColors.accent.withValues(alpha: 0.1),
                            textColor: semanticColors.accent,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _infoChip(
                            icon: isCR
                                ? Icons.star_rounded
                                : isSR
                                    ? Icons.assignment_ind_rounded
                                    : Icons.school_rounded,
                            label: roleText,
                            bgColor:
                                colorScheme.secondary.withValues(alpha: 0.1),
                            textColor: colorScheme.secondary,
                          ),
                          if (isSR && AppSettings.srSubject != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _infoChip(
                              icon: Icons.menu_book_rounded,
                              label: AppSettings.srSubject!,
                              bgColor: semanticColors.success
                                  .withValues(alpha: 0.1),
                              textColor: semanticColors.success,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 🎓 Academic Profile 🎓
            if (!isCR && !isSR && AppSettings.currentRole == UserRole.student) ...[
              _sectionHeader('Academic Profile'),
              StaggeredListItem(
                index: 1, // reuse index for animation
                child: _buildTileGroup([
                  _buildRoleTile(
                    icon: Icons.group_work_rounded,
                    title: 'My Batch',
                    subtitle: AppSettings.studentBatch ?? 'Tap to select your batch (e.g., C1)',
                    iconColor: colorScheme.primary,
                    onTap: () => _showBatchSelector(context),
                  ),
                ]),
              ),
            ],

            // ── Appearance section ────────────────────────────────────────
            _sectionHeader('Appearance'),
            StaggeredListItem(
              index: 1,
              child: _buildAppearanceSegment(),
            ),

            // ── My Role section ───────────────────────────────────────────
            _sectionHeader('My Role'),
            StaggeredListItem(
              index: 2,
              child: _buildTileGroup([
                if (isSR)
                  _buildRoleTile(
                    icon: Icons.checklist_rtl_rounded,
                    title: 'Conduct Dashboard',
                    subtitle: 'Verify pending lectures for your subject',
                    iconColor: colorScheme.secondary,
                    targetId: 'conduct_dashboard_tab',
                    onTap: () {
                      if (AppSettings.srSubject != null) {
                        TutorialController.instance.completeStep();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SrConductDashboard(
                              division: widget.division,
                              subject: AppSettings.srSubject ?? '',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                if (!isCR)
                  _buildRoleTile(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'CR Login',
                    subtitle: 'Authenticate as Class Representative',
                    iconColor: colorScheme.primary,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoleVerificationPage(
                            division: widget.division,
                            role: 'CR',
                          ),
                        ),
                      );
                      _refresh();
                    },
                  ),
                if (!isSR && !isCR)
                  _buildRoleTile(
                    icon: Icons.assignment_ind_rounded,
                    title: 'SR Login',
                    subtitle: 'Authenticate as Subject Representative',
                    iconColor: semanticColors.success,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoleVerificationPage(
                            division: widget.division,
                            role: 'SR',
                          ),
                        ),
                      );
                      _refresh();
                    },
                  ),
                if (isCR)
                  _buildRoleTile(
                    icon: Icons.dashboard_rounded,
                    title: 'CR Panel',
                    subtitle: 'Manage timetable and announcements',
                    iconColor: colorScheme.primary,
                    targetId: 'cr_panel_btn',
                    onTap: () {
                      TutorialController.instance.completeStep();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CRPanelPage()),
                      );
                    },
                  ),
              ]),
            ),

            // ── App Settings (Web Only for Notifications) ─────────────────
            if (kIsWeb) ...[
              _sectionHeader('App Settings'),
              StaggeredListItem(
                index: 3,
                child: _buildTileGroup([
                  _buildRoleTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Tap to enable notifications on this device',
                    iconColor: semanticColors.accent,
                    onTap: () async {
                      await NotificationService.promptWebPermission();
                      if (!context.mounted) return;
                      AppDialogs.showSnackBar(
                        context: context,
                        message: 'Notification settings updated',
                      );
                    },
                  ),
                ]),
              ),
            ],

            // ── Help & Tutorials ──────────────────────────────────────────
            _sectionHeader('Help & Tutorials'),
            StaggeredListItem(
              index: 3,
              child: _buildTileGroup([
                _buildRoleTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Replay Tutorial',
                  subtitle: 'Replay the interactive guide',
                  iconColor: semanticColors.accent,
                  onTap: () async {
                    await TutorialStorageService.resetAll();
                    if (!context.mounted) return;
                    OnboardingService.instance.startRoleTour(context, AppSettings.currentRole);
                  },
                ),
              ]),
            ),

            // ── Support ───────────────────────────────────────────────────
            _sectionHeader('Support'),
            StaggeredListItem(
              index: 4,
              child: _buildTileGroup([
                _buildRoleTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Report a Bug',
                  subtitle: 'Let us know if something is broken',
                  iconColor: semanticColors.error,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const BugReportSheet(),
                    );
                  },
                ),
                _buildRoleTile(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Suggest a Feature',
                  subtitle: 'Have an idea for Schedly?',
                  iconColor: semanticColors.warning,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const FeatureRequestSheet(),
                    );
                  },
                ),
              ]),
            ),

            // ── Administration section ────────────────────────────────────
            _sectionHeader('Administration'),
            StaggeredListItem(
              index: 5,
              child: _buildTileGroup([
                _buildRoleTile(
                  icon: Icons.school_rounded,
                  title: 'Student',
                  subtitle: 'Manage student profiles',
                  iconColor: colorScheme.primary,
                  onTap: () => _executeAdminAction(() {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentManagementPage()));
                  }),
                ),
                _buildRoleTile(
                  icon: Icons.person_search_rounded,
                  title: 'Faculty',
                  subtitle: 'Manage faculty profiles',
                  iconColor: colorScheme.primary,
                  onTap: () => _executeAdminAction(() {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyManagementPage()));
                  }),
                ),
                _buildRoleTile(
                  icon: Icons.meeting_room_rounded,
                  title: 'Create Section',
                  subtitle: 'Create, edit, clone and archive sections',
                  iconColor: colorScheme.primary,
                  onTap: () => _executeAdminAction(() {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SectionManagementPage()));
                  }),
                ),
              ]),
            ),

            // ── About Schedly section ─────────────────────────────────────
            _sectionHeader('About'),
            StaggeredListItem(
              index: 5,
              child: _buildTileGroup([
                _buildRoleTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About Schedly',
                  subtitle: 'Version, features, and developer info',
                  iconColor: colorScheme.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutSchedlyPage()),
                    );
                  },
                ),
              ]),
            ),

            // ── Account section (destructive) ─────────────────────────────
            _sectionHeader('Account'),
            StaggeredListItem(
              index: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: semanticColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: semanticColors.cancelled.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildRoleTile(
                  icon: Icons.logout_rounded,
                  title: 'Reset App & Logout',
                  subtitle: 'Clear all local data and sign out',
                  iconColor: semanticColors.cancelled,
                  isDestructive: true,
                  onTap: () async {
                    final confirmed = await AppDialogs.showConfirm(
                      context: context,
                      title: 'Reset App & Logout',
                      message: 'Are you sure you want to clear all local data and sign out?',
                      confirmText: 'Logout',
                      isDestructive: true,
                    );

                    if (!confirmed) return;

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    await AppSettings.resetRole();
                    AppSettings.studentName = null;
                    AppSettings.studentRollNo = null;

                    if (!context.mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (c) => const OnboardingFlow()),
                      (_) => false,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x4l),
          ],
        ),
      ),
    );
  }

  // ─── Small info chip ─────────────────────────────────────────────────────
  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: textColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _executeAdminAction(VoidCallback action) {
    if (AdminSession.isAuthenticated) {
      action();
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (ctx) => AdminAuthSheet(onSuccess: action),
      );
    }
  }

  Future<void> _showBatchSelector(BuildContext context) async {
    final batchCtrl = TextEditingController(text: AppSettings.studentBatch);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('My Batch', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: batchCtrl,
            decoration: const InputDecoration(
              labelText: 'Batch (e.g. C1)',
              hintText: 'Enter your batch',
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Batch is required';
              if (val.trim().length > 5) return 'Batch too long';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, batchCtrl.text.trim().toUpperCase());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await AppSettings.saveStudentBatch(result);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'batch': result,
        });
      }
      if (mounted) setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch updated to $result')),
        );
      }
    }
  }
}

