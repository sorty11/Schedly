import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedly/user_roles.dart';
import 'package:schedly/onboarding/models/tutorial_step.dart';
import 'package:schedly/onboarding/models/tutorial_tour.dart';
import 'package:schedly/onboarding/services/tutorial_controller.dart';
import 'package:schedly/onboarding/services/tutorial_registry.dart';
import 'package:schedly/onboarding/services/whats_new_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TutorialController.instance.forceDismiss();
  });

  group('TutorialController - Lifecycle & Flow', () {
    test('startTour initializes state and current step', () {
      final controller = TutorialController.instance;
      const step1 = TutorialStep(
        targetId: 'tab_home',
        title: 'Home',
        description: 'Home screen',
      );
      const step2 = TutorialStep(
        targetId: 'tab_profile',
        title: 'Profile',
        description: 'Profile screen',
      );
      const tour = TutorialTour(
        tourId: 'test_tour',
        name: 'Test Tour',
        steps: [step1, step2],
      );

      controller.startTour(tour);

      expect(controller.currentTour, equals(tour));
      expect(controller.currentStepIndex, equals(0));
      expect(controller.currentStep, equals(step1));
      expect(controller.isVisible, isTrue);
      expect(controller.totalSteps, equals(2));
      expect(controller.isFirstStep, isTrue);
      expect(controller.isLastStep, isFalse);
    });

    test('completeStep advances step and completes tour on last step', () {
      final controller = TutorialController.instance;
      const step1 = TutorialStep(
        targetId: 'tab_home',
        title: 'Home',
        description: 'Home screen',
      );
      const step2 = TutorialStep(
        targetId: 'tab_profile',
        title: 'Profile',
        description: 'Profile screen',
      );
      const tour = TutorialTour(
        tourId: 'test_tour',
        name: 'Test Tour',
        steps: [step1, step2],
      );

      controller.startTour(tour);
      expect(controller.currentStepIndex, equals(0));

      // Advance to step 2
      controller.advanceStep();
      expect(controller.currentStepIndex, equals(1));
      expect(controller.currentStep, equals(step2));
      expect(controller.isLastStep, isTrue);

      // Complete last step
      controller.advanceStep();
      expect(controller.isVisible, isFalse);
      expect(controller.currentTour, isNull);
    });

    test('skipTour ends tour immediately', () {
      final controller = TutorialController.instance;
      const tour = TutorialTour(
        tourId: 'test_tour',
        name: 'Test Tour',
        steps: [
          TutorialStep(
            targetId: 'tab_home',
            title: 'Home',
            description: 'Home screen',
          ),
        ],
      );

      controller.startTour(tour);
      expect(controller.isVisible, isTrue);

      controller.skipTour();
      expect(controller.isVisible, isFalse);
      expect(controller.currentTour, isNull);
    });

    test('target key registration and retrieval works correctly', () {
      final controller = TutorialController.instance;
      final key = GlobalKey();

      controller.registerTarget('button_add', key);
      expect(controller.getTargetKey('button_add'), equals(key));

      controller.unregisterTarget('button_add');
      expect(controller.getTargetKey('button_add'), isNull);
    });
  });

  group('TutorialRegistry - Role Tour Verification', () {
    test('Registry initializes with tours for all 4 roles', () {
      final studentTours = TutorialRegistry.getToursForRole(UserRole.student);
      final crTours = TutorialRegistry.getToursForRole(UserRole.cr);
      final srTours = TutorialRegistry.getToursForRole(UserRole.sr);
      final facultyTours = TutorialRegistry.getToursForRole(UserRole.faculty);

      expect(studentTours.any((t) => t.tourId == 'student_tour'), isTrue);
      expect(crTours.any((t) => t.tourId == 'cr_tour'), isTrue);
      expect(srTours.any((t) => t.tourId == 'sr_tour'), isTrue);
      expect(facultyTours.any((t) => t.tourId == 'faculty_tour'), isTrue);
    });

    test('Student tour contains core learning steps', () {
      final tour = TutorialRegistry.getTour('student_tour');
      expect(tour, isNotNull);
      expect(tour!.steps.length, greaterThanOrEqualTo(4));
      final targetIds = tour.steps.map((s) => s.targetId).toList();
      expect(targetIds, contains('dashboard_tab'));
      expect(targetIds, contains('timetable_tab'));
      expect(targetIds, contains('attendance_tab'));
    });

    test('CR tour contains CR panel and studio references', () {
      final tour = TutorialRegistry.getTour('cr_tour');
      expect(tour, isNotNull);
      final targetIds = tour!.steps.map((s) => s.targetId).toList();
      expect(targetIds, contains('admin_tab'));
      expect(targetIds, contains('announcements_tab'));
    });

    test('Faculty tour contains faculty tabs', () {
      final tour = TutorialRegistry.getTour('faculty_tour');
      expect(tour, isNotNull);
      final targetIds = tour!.steps.map((s) => s.targetId).toList();
      expect(targetIds, contains('faculty_home_tab'));
      expect(targetIds, contains('faculty_timetable_tab'));
      expect(targetIds, contains('faculty_panel_tab'));
      expect(targetIds, contains('faculty_profile_tab'));
    });
  });

  group('WhatsNewService - V11 Feature Release', () {
    test('WhatsNewRelease for v11 is defined and has features', () {
      final release = WhatsNewService.v11Release;
      expect(release.versionName, equals('1.0.11'));
      expect(release.buildNumber, equals(11));
      expect(release.features, isNotEmpty);
    });

    test('Role filtering includes relevant features', () {
      final studentFeatures = WhatsNewService.getFeaturesForRole(UserRole.student);
      final facultyFeatures = WhatsNewService.getFeaturesForRole(UserRole.faculty);

      expect(studentFeatures, isNotEmpty);
      expect(facultyFeatures, isNotEmpty);

      // Student should have attendance/themes
      expect(studentFeatures.any((f) => f.title.contains('Themes') || f.title.contains('Visual')), isTrue);
      // Faculty should have faculty portal / SR features
      expect(facultyFeatures.any((f) => f.title.contains('Faculty') || f.title.contains('SR')), isTrue);
    });
  });
}

