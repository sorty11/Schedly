import 'package:flutter/material.dart';
import '../models/tutorial_step.dart';
import '../models/tutorial_tour.dart';
import '../widgets/tutorial_overlay.dart';
import 'tutorial_controller.dart';
import 'tutorial_storage_service.dart';

class FeatureDiscoveryService {
  /// Checks if any tutorial is currently active.
  static bool get _isBusy => TutorialController.instance.isVisible;

  /// Triggered when user enters MonthlyTimetablePage for the first time.
  static Future<void> checkMonthlyTimetableDiscovery(BuildContext context) async {
    const featureId = 'monthly_timetable_discovery';
    if (_isBusy) return;
    if (await TutorialStorageService.hasSeenFeature(featureId)) return;
    if (!context.mounted) return;

    final tour = const TutorialTour(
      tourId: featureId,
      name: 'Monthly Timetable Guide',
      category: TutorialCategory.featureDiscovery,
      steps: [
        TutorialStep(
          targetId: 'monthly_calendar_view',
          title: 'Date-Specific Overrides',
          description:
              'Select any date to view resolved schedules. Schedly dynamically applies cancellations, room changes, and holiday overrides.',
          ccMessage: 'Plan your entire month with confidence.',
          preferredPosition: TooltipPosition.bottom,
          actionLabel: 'Got it',
        ),
      ],
    );

    await TutorialStorageService.markFeatureSeen(featureId);
    TutorialOverlayManager.show(context);
    TutorialController.instance.startTour(tour);
  }

  /// Triggered when user enters AttendancePage for the first time.
  static Future<void> checkAttendanceDiscovery(BuildContext context) async {
    const featureId = 'attendance_discovery';
    if (_isBusy) return;
    if (await TutorialStorageService.hasSeenFeature(featureId)) return;
    if (!context.mounted) return;

    final tour = const TutorialTour(
      tourId: featureId,
      name: 'Smart Attendance Guide',
      category: TutorialCategory.featureDiscovery,
      steps: [
        TutorialStep(
          targetId: 'attendance_page_header',
          title: 'Smart Attendance & Skip Math',
          description:
              'Track lecture completion, see how many classes you can safely miss, or upload your official attendance PDF for auto-sync.',
          ccMessage: 'Stay ahead of your 80% attendance goal with smart skip tracking.',
          preferredPosition: TooltipPosition.bottom,
          actionLabel: 'Explore',
        ),
      ],
    );

    await TutorialStorageService.markFeatureSeen(featureId);
    TutorialOverlayManager.show(context);
    TutorialController.instance.startTour(tour);
  }

  /// Triggered when user enters ThemesPage for the first time.
  static Future<void> checkThemesDiscovery(BuildContext context) async {
    const featureId = 'themes_discovery';
    if (_isBusy) return;
    if (await TutorialStorageService.hasSeenFeature(featureId)) return;
    if (!context.mounted) return;

    final tour = const TutorialTour(
      tourId: featureId,
      name: 'Themes & Visual Skins',
      category: TutorialCategory.themes,
      steps: [
        TutorialStep(
          targetId: 'theme_skin_gallery',
          title: '4 Handcrafted Visual Skins',
          description:
              'Experience Classic Schedly, Heritage (Old School Rust), Neo Future (Cyan HUD), or Bloom (Vibrant Rounded). Tap to preview live!',
          ccMessage: 'Every skin transforms cards, borders, and animations.',
          preferredPosition: TooltipPosition.bottom,
          actionLabel: 'Choose Theme',
        ),
      ],
    );

    await TutorialStorageService.markFeatureSeen(featureId);
    TutorialOverlayManager.show(context);
    TutorialController.instance.startTour(tour);
  }

  /// Triggered when CR opens Timetable Studio for the first time.
  static Future<void> checkTimetableStudioDiscovery(BuildContext context) async {
    const featureId = 'timetable_studio_discovery';
    if (_isBusy) return;
    if (await TutorialStorageService.hasSeenFeature(featureId)) return;
    if (!context.mounted) return;

    final tour = const TutorialTour(
      tourId: featureId,
      name: 'Studio Recurrence Guide',
      category: TutorialCategory.management,
      steps: [
        TutorialStep(
          targetId: 'studio_recurrence_switch',
          title: 'Weekly vs Date-Specific Changes',
          description:
              'Enable "Repeat Weekly" to permanently update the recurring master schedule. Leave it off to override this date only.',
          ccMessage: 'Important: date overrides keep your recurring schedule safe.',
          preferredPosition: TooltipPosition.top,
          actionLabel: 'Understood',
        ),
      ],
    );

    await TutorialStorageService.markFeatureSeen(featureId);
    TutorialOverlayManager.show(context);
    TutorialController.instance.startTour(tour);
  }

  /// Triggered when Faculty opens Faculty SR Connections page for the first time.
  static Future<void> checkFacultySrConnectionsDiscovery(BuildContext context) async {
    const featureId = 'faculty_sr_connections_discovery';
    if (_isBusy) return;
    if (await TutorialStorageService.hasSeenFeature(featureId)) return;
    if (!context.mounted) return;

    final tour = const TutorialTour(
      tourId: featureId,
      name: 'SR Coordination Guide',
      category: TutorialCategory.management,
      steps: [
        TutorialStep(
          targetId: 'faculty_sr_connection_view',
          title: 'Subject Representatives',
          description:
              'View assigned student Subject Representatives for your classes to coordinate lecture conduction, extra sessions, and syllabus progress.',
          ccMessage: 'Direct collaboration with your class representatives.',
          preferredPosition: TooltipPosition.bottom,
          actionLabel: 'Got it',
        ),
      ],
    );

    await TutorialStorageService.markFeatureSeen(featureId);
    TutorialOverlayManager.show(context);
    TutorialController.instance.startTour(tour);
  }

  /// Aliases for discovery checks
  static Future<void> checkStudioRecurrenceDiscovery(BuildContext context) =>
      checkTimetableStudioDiscovery(context);

  static Future<void> checkSrConnectionsDiscovery(BuildContext context) =>
      checkFacultySrConnectionsDiscovery(context);

  /// Backward-compatibility shim for any legacy callers.
  static Future<void> checkNewFeatures(BuildContext context) async {
    // Replaced by WhatsNewService.checkAndShowWhatsNew
  }
}

