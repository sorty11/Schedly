import 'package:flutter/material.dart';
import '../../user_roles.dart';
import '../models/tutorial_tour.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/welcome_card.dart';
import 'tutorial_storage_service.dart';
import 'tutorial_controller.dart';
import 'tutorial_registry.dart';
import 'whats_new_service.dart';

class OnboardingService {
  static final OnboardingService instance = OnboardingService._();
  OnboardingService._();

  /// Evaluates app launch state:
  /// - For V10 users upgrading to V11: displays "What's New in Schedly V11"
  /// - For completely new users: displays the progressive Welcome & Role tour
  /// - For existing V11 users: silently ensures build is recorded
  Future<void> initializeAndCheckFirstLaunch(
    BuildContext context,
    UserRole role,
  ) async {
    // 1. Check if user is an existing V10 user upgrading to V11
    final isMigrator = await TutorialStorageService.isV10Migrator();
    if (isMigrator) {
      if (!context.mounted) return;
      await WhatsNewService.checkAndShowWhatsNew(context, role);
      await TutorialStorageService.recordCurrentAppBuild();
      return;
    }

    // 2. Check if user is a new user who has not seen the welcome tour
    final hasSeenWelcome = await TutorialStorageService.hasSeenTour('welcome');
    if (!hasSeenWelcome) {
      if (!context.mounted) return;
      _showWelcomeCard(context, role);
    } else {
      // 3. Current user: ensure build number is persisted
      await TutorialStorageService.recordCurrentAppBuild();
    }
  }

  void _showWelcomeCard(BuildContext context, UserRole role) {
    String message = '';
    switch (role) {
      case UserRole.student:
        message = "Your academic schedule, smart attendance, and class updates all in one place.";
        break;
      case UserRole.cr:
        message = "Your Class Representative command center for timetable management, broadcasts, and student rosters.";
        break;
      case UserRole.sr:
        message = "Your Subject Representative hub to manage subject conduct, verify lecture status, and coordinate with faculty.";
        break;
      case UserRole.faculty:
        message = "Your faculty teaching portal with consolidated schedules, student reps, and conflict detection.";
        break;
    }

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => WelcomeCard(
        roleMessage: message,
        onStartTour: () async {
          entry?.remove();
          await TutorialStorageService.markTourSeen('welcome');
          await TutorialStorageService.recordCurrentAppBuild();
          if (context.mounted) startRoleTour(context, role);
        },
        onSkip: () async {
          entry?.remove();
          await TutorialStorageService.markTourSkipped('welcome');
          await TutorialStorageService.recordCurrentAppBuild();
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  /// Starts the role-specific getting started tour via the TutorialRegistry.
  void startRoleTour(BuildContext context, UserRole role) {
    String tourId;
    switch (role) {
      case UserRole.student:
        tourId = 'student_tour';
        break;
      case UserRole.cr:
        tourId = 'cr_tour';
        break;
      case UserRole.sr:
        tourId = 'sr_tour';
        break;
      case UserRole.faculty:
        tourId = 'faculty_tour';
        break;
    }

    final tour = TutorialRegistry.getTour(tourId);
    if (tour != null) {
      TutorialOverlayManager.show(context);
      TutorialController.instance.startTour(tour);
    }
  }

  /// Convenience method to replay a specific tour on demand.
  Future<void> replayTour(BuildContext context, String tourId) async {
    await TutorialStorageService.resetTour(tourId);
    final tour = TutorialRegistry.getTour(tourId);
    if (tour != null && context.mounted) {
      TutorialOverlayManager.show(context);
      TutorialController.instance.startTour(tour);
    }
  }
}

