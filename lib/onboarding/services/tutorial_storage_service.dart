import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages persistent state for Schedly tutorials, contextual feature discovery,
/// and version-aware What's New releases.
class TutorialStorageService {
  static const String _tourPrefix = 'tour_seen_v_';
  static const String _tourSkippedPrefix = 'tour_skipped_';
  static const String _featurePrefix = 'feature_discovered_';
  static const String _whatsNewPrefix = 'whats_new_seen_b_';
  static const String _masteryPrefix = 'mastery_';

  // Schedly V11 Constants
  static const int currentFrameworkVersion = 2;
  static const int currentAppBuild = 11;
  static const String currentAppVersion = '1.0.11';

  // ── Version & Migration Detection ──────────────────────────────────────────

  /// Returns the build number recorded when the user last launched the app.
  static Future<int> getLastSeenAppBuild() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('last_seen_app_build') ?? 0;
    } catch (e) {
      debugPrint('TutorialStorageService.getLastSeenAppBuild error: $e');
      return 0;
    }
  }

  /// Records the current build number to persist that the user has launched V11.
  static Future<void> recordCurrentAppBuild() => recordAppLaunch(currentAppBuild);

  /// Records an app launch for a specific build.
  static Future<void> recordAppLaunch([int? build]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_seen_app_build', build ?? currentAppBuild);
      await prefs.setString('last_seen_app_version', currentAppVersion);
      await prefs.setInt('tutorial_schema_version', currentFrameworkVersion);
    } catch (e) {
      debugPrint('TutorialStorageService.recordAppLaunch error: $e');
    }
  }

  /// Determines whether the user is an existing V10 user upgrading to V11.
  /// An existing user has saved division/student/role data or legacy tour data,
  /// but their recorded build number is less than 11.
  static Future<bool> isV10Migrator() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBuild = prefs.getInt('last_seen_app_build') ?? 0;
      if (lastBuild >= currentAppBuild) return false;

      // Check if user has pre-existing app data from V10
      final hasDivision = prefs.getString('selected_division') != null ||
          prefs.getString('section_id') != null ||
          prefs.getString('division') != null;
      final hasStudent = prefs.getString('student_name') != null;
      final hasFaculty = prefs.getString('faculty_name') != null;
      final hasLegacyTour = prefs.getInt('tour_seen_v_welcome') != null ||
          prefs.getInt('last_seen_feature_version') != null;
      final hasCompletedWizard =
          prefs.getBool('has_completed_onboarding_wizard') == true;

      return hasDivision ||
          hasStudent ||
          hasFaculty ||
          hasLegacyTour ||
          hasCompletedWizard;
    } catch (e) {
      debugPrint('TutorialStorageService.isV10Migrator error: $e');
      return false;
    }
  }

  // ── Tour State Management ──────────────────────────────────────────────────

  /// Checks whether a specific tour has been completed.
  static Future<bool> hasSeenTour(String tourId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenVersion = prefs.getInt('$_tourPrefix$tourId') ?? 0;
      return seenVersion >= currentFrameworkVersion;
    } catch (e) {
      debugPrint('TutorialStorageService.hasSeenTour error: $e');
      return false;
    }
  }

  /// Marks a specific tour as completed under the current framework version.
  static Future<void> markTourSeen(String tourId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_tourPrefix$tourId', currentFrameworkVersion);
      // Remove skipped flag if now completed
      await prefs.remove('$_tourSkippedPrefix$tourId');
    } catch (e) {
      debugPrint('TutorialStorageService.markTourSeen error: $e');
    }
  }

  /// Checks whether a user explicitly skipped a tour.
  static Future<bool> isTourSkipped(String tourId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_tourSkippedPrefix$tourId') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Marks a tour as skipped so the user is not bothered again automatically.
  static Future<void> markTourSkipped(String tourId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_tourSkippedPrefix$tourId', true);
      // Also mark as seen so automatic triggers ignore it
      await prefs.setInt('$_tourPrefix$tourId', currentFrameworkVersion);
    } catch (e) {
      debugPrint('TutorialStorageService.markTourSkipped error: $e');
    }
  }

  // ── Contextual Feature Discovery State ─────────────────────────────────────

  /// Checks whether a one-time contextual discovery hint has been shown.
  static Future<bool> hasSeenFeature(String featureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_featurePrefix$featureId') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Marks a one-time contextual feature hint as shown.
  static Future<void> markFeatureSeen(String featureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_featurePrefix$featureId', true);
    } catch (e) {
      debugPrint('TutorialStorageService.markFeatureSeen error: $e');
    }
  }

  // ── What's New State ───────────────────────────────────────────────────────

  /// Checks whether the What's New dialog has been presented for a build number.
  static Future<bool> hasSeenWhatsNew([int build = currentAppBuild]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_whatsNewPrefix$build') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Marks the What's New dialog as shown for a build number.
  static Future<void> markWhatsNewSeen([int build = currentAppBuild]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_whatsNewPrefix$build', true);
    } catch (e) {
      debugPrint('TutorialStorageService.markWhatsNewSeen error: $e');
    }
  }

  // ── Mastery & Backward Compatibility ───────────────────────────────────────

  static Future<bool> hasMastery(String featureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_masteryPrefix$featureId') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> markMastery(String featureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_masteryPrefix$featureId', true);
    } catch (e) {
      debugPrint('TutorialStorageService.markMastery error: $e');
    }
  }

  static Future<int> getLastSeenFeatureVersion() async {
    return getLastSeenAppBuild();
  }

  static Future<void> setLastSeenFeatureVersion(int version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_seen_feature_version', version);
    } catch (e) {
      debugPrint('TutorialStorageService.setLastSeenFeatureVersion error: $e');
    }
  }

  // ── Reset & Replay ─────────────────────────────────────────────────────────

  /// Resets all tour, feature, and What's New state so they can be replayed.
  static Future<void> resetAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key.startsWith(_tourPrefix) ||
            key.startsWith(_tourSkippedPrefix) ||
            key.startsWith(_featurePrefix) ||
            key.startsWith(_whatsNewPrefix) ||
            key.startsWith(_masteryPrefix) ||
            key.startsWith('tour_seen_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('TutorialStorageService.resetAll error: $e');
    }
  }

  /// Resets only a specific tour for selective replay.
  static Future<void> resetTour(String tourId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_tourPrefix$tourId');
      await prefs.remove('$_tourSkippedPrefix$tourId');
    } catch (e) {
      debugPrint('TutorialStorageService.resetTour error: $e');
    }
  }

  /// Resets only contextual feature discovery flags, preserving completed full tours.
  static Future<void> resetHints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key.startsWith(_featurePrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('TutorialStorageService.resetHints error: $e');
    }
  }
}
