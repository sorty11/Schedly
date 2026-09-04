import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedly/onboarding/services/tutorial_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TutorialStorageService - User Classification & Versioning', () {
    test('Fresh user returns isV10Migrator == false', () async {
      SharedPreferences.setMockInitialValues({});
      final isMigrator = await TutorialStorageService.isV10Migrator();
      expect(isMigrator, isFalse);
    });

    test('V10 user (wizard completed, no app_build) returns isV10Migrator == true', () async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding_wizard': true,
      });
      final isMigrator = await TutorialStorageService.isV10Migrator();
      expect(isMigrator, isTrue);
    });

    test('Already upgraded V11 user returns isV10Migrator == false', () async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding_wizard': true,
        'last_seen_app_build': 11,
      });
      final isMigrator = await TutorialStorageService.isV10Migrator();
      expect(isMigrator, isFalse);
    });

    test('recordAppLaunch stores the current build version', () async {
      SharedPreferences.setMockInitialValues({});
      await TutorialStorageService.recordAppLaunch(11);
      final lastBuild = await TutorialStorageService.getLastSeenAppBuild();
      expect(lastBuild, equals(11));
    });
  });

  group('TutorialStorageService - Granular Tour & Feature Tracking', () {
    test('hasSeenTour returns false initially and true after markTourSeen', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await TutorialStorageService.hasSeenTour('student_tour'), isFalse);

      await TutorialStorageService.markTourSeen('student_tour');
      expect(await TutorialStorageService.hasSeenTour('student_tour'), isTrue);
    });

    test('hasSeenFeature returns false initially and true after markFeatureSeen', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await TutorialStorageService.hasSeenFeature('monthly_timetable_discovery'), isFalse);

      await TutorialStorageService.markFeatureSeen('monthly_timetable_discovery');
      expect(await TutorialStorageService.hasSeenFeature('monthly_timetable_discovery'), isTrue);
    });

    test('hasSeenWhatsNew tracks release version correctly', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await TutorialStorageService.hasSeenWhatsNew(11), isFalse);

      await TutorialStorageService.markWhatsNewSeen(11);
      expect(await TutorialStorageService.hasSeenWhatsNew(11), isTrue);
    });

    test('resetHints resets feature flags but preserves tours', () async {
      SharedPreferences.setMockInitialValues({});
      await TutorialStorageService.markTourSeen('student_tour');
      await TutorialStorageService.markFeatureSeen('themes_discovery');

      await TutorialStorageService.resetHints();

      expect(await TutorialStorageService.hasSeenTour('student_tour'), isTrue);
      expect(await TutorialStorageService.hasSeenFeature('themes_discovery'), isFalse);
    });

    test('resetAll clears both tours and feature flags', () async {
      SharedPreferences.setMockInitialValues({});
      await TutorialStorageService.markTourSeen('student_tour');
      await TutorialStorageService.markFeatureSeen('themes_discovery');

      await TutorialStorageService.resetAll();

      expect(await TutorialStorageService.hasSeenTour('student_tour'), isFalse);
      expect(await TutorialStorageService.hasSeenFeature('themes_discovery'), isFalse);
    });
  });
}

