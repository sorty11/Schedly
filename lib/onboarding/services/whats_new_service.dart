import 'package:flutter/material.dart';
import '../../user_roles.dart';
import '../models/whats_new_item.dart';
import '../widgets/whats_new_dialog.dart';
import 'tutorial_storage_service.dart';

class WhatsNewService {
  static const int currentV11Build = 11;
  static const String currentV11Version = '1.0.11';

  static final WhatsNewRelease v11Release = WhatsNewRelease(
    buildNumber: currentV11Build,
    versionName: currentV11Version,
    heroTitle: "What's New in Schedly V11",
    heroSubtitle: "A major evolution with 4 distinct visual skins, intelligent attendance analytics, and refined schedules.",
    features: const [
      // Universal / Student features
      WhatsNewFeature(
        title: '4 Handcrafted Visual Skins',
        description: 'Switch between Classic Schedly, Heritage (Rust & Brass), Neo Future (Cyan HUD), and Bloom (Vibrant Rounded).',
        icon: Icons.palette_rounded,
        tag: 'NEW',
        roleTarget: null,
      ),
      WhatsNewFeature(
        title: 'Smart Skip & Absence Math',
        description: 'See exactly how many classes you can safely miss or need to attend to meet your attendance threshold.',
        icon: Icons.calculate_rounded,
        tag: 'INTELLIGENCE',
        roleTarget: UserRole.student,
      ),
      WhatsNewFeature(
        title: 'Themed Timetable Cards',
        description: 'Enjoy redesigned lecture cards that adapt to the active visual theme with horizontal day gestures.',
        icon: Icons.view_week_rounded,
        tag: 'ENHANCED',
        roleTarget: UserRole.student,
      ),
      WhatsNewFeature(
        title: 'Tuned 60 FPS Scroll Physics',
        description: 'Ultra-smooth scroll deceleration physics eliminating gesture contention on Android, iOS, and Web.',
        icon: Icons.speed_rounded,
        tag: 'PERFORMANCE',
        roleTarget: null,
      ),

      // CR features
      WhatsNewFeature(
        title: 'Timetable Studio & Recurrence Math',
        description: 'Clear distinction between date-specific overrides (this week only) and permanent recurring weekly updates.',
        icon: Icons.edit_calendar_rounded,
        tag: 'MANAGEMENT',
        roleTarget: UserRole.cr,
      ),
      WhatsNewFeature(
        title: 'Batch & Credential Controls',
        description: 'Easily rename section batches (e.g. A1 to Batch Alpha) and manage role passwords securely.',
        icon: Icons.admin_panel_settings_rounded,
        tag: 'SECURITY',
        roleTarget: UserRole.cr,
      ),
      WhatsNewFeature(
        title: 'Faculty Request Approvals',
        description: 'Review and approve or deny extra lecture requests and cancellations from professors in real time.',
        icon: Icons.how_to_reg_rounded,
        tag: 'WORKFLOW',
        roleTarget: UserRole.cr,
      ),

      // SR features
      WhatsNewFeature(
        title: 'SR Conduct Center',
        description: 'Verify lecture status (Conducted, Cancelled, Rescheduled) with live attendance log tracking.',
        icon: Icons.fact_check_rounded,
        tag: 'VERIFICATION',
        roleTarget: UserRole.sr,
      ),
      WhatsNewFeature(
        title: 'Faculty Liaison Hub',
        description: 'Directly view assigned professors and coordination requests for your course.',
        icon: Icons.school_rounded,
        tag: 'CONNECTIONS',
        roleTarget: UserRole.sr,
      ),

      // Faculty features
      WhatsNewFeature(
        title: 'Consolidated Teaching Schedule',
        description: 'Unified timetable across all assigned sections reflecting real-time CR overrides and student batch slots.',
        icon: Icons.calendar_month_rounded,
        tag: 'FACULTY',
        roleTarget: UserRole.faculty,
      ),
      WhatsNewFeature(
        title: 'Timetable Conflict Detection',
        description: 'Automatic overlap detection with one-tap notification alerts to affected section CRs.',
        icon: Icons.warning_amber_rounded,
        tag: 'SMART',
        roleTarget: UserRole.faculty,
      ),
      WhatsNewFeature(
        title: 'SR Student Connections',
        description: 'Direct contact details and coordination status with student Subject Representatives for all your courses.',
        icon: Icons.hub_rounded,
        tag: 'COLLABORATION',
        roleTarget: UserRole.faculty,
      ),
      WhatsNewFeature(
        title: 'Extra Lecture & Cancellation Requests',
        description: 'Propose extra sessions or date cancellations with instant routing to CRs and real-time status tracking.',
        icon: Icons.send_rounded,
        tag: 'REQUESTS',
        roleTarget: UserRole.faculty,
      ),
    ],
  );

  /// Returns list of features relevant to the current role.
  static List<WhatsNewFeature> getFeaturesForRole(UserRole role) {
    return v11Release.features.where((f) {
      if (f.roleTarget == null) return true;
      return f.roleTarget == role;
    }).toList();
  }

  /// Automatically checks and displays What's New if the user hasn't seen V11 yet.
  static Future<void> checkAndShowWhatsNew(
    BuildContext context,
    UserRole role,
  ) async {
    final seen = await TutorialStorageService.hasSeenWhatsNew(currentV11Build);
    if (!seen) {
      if (!context.mounted) return;
      await showWhatsNew(context, role);
    }
  }

  /// Displays the What's New experience in a modal dialog.
  static Future<void> showWhatsNew(
    BuildContext context,
    UserRole role,
  ) async {
    final features = getFeaturesForRole(role);
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WhatsNewDialog(
        release: v11Release,
        features: features,
        role: role,
        onDismiss: () async {
          Navigator.of(ctx).pop();
          await TutorialStorageService.markWhatsNewSeen(currentV11Build);
          await TutorialStorageService.recordCurrentAppBuild();
        },
      ),
    );
  }
}

