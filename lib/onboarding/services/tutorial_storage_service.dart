import 'package:shared_preferences/shared_preferences.dart';

class TutorialStorageService {
  static const String _tourPrefix = 'tour_seen_v_';
  static const String _masteryPrefix = 'mastery_';
  
  // Update this constant whenever the onboarding framework is significantly redesigned
  static const int currentFrameworkVersion = 1;

  static Future<bool> hasSeenTour(String tourId) async {
    final prefs = await SharedPreferences.getInstance();
    final seenVersion = prefs.getInt('$_tourPrefix$tourId') ?? 0;
    return seenVersion >= currentFrameworkVersion;
  }

  static Future<void> markTourSeen(String tourId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_tourPrefix$tourId', currentFrameworkVersion);
  }

  static Future<bool> hasMastery(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_masteryPrefix$featureId') ?? false;
  }

  static Future<void> markMastery(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_masteryPrefix$featureId', true);
  }

  static Future<int> getLastSeenFeatureVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_seen_feature_version') ?? 0;
  }
  
  static Future<void> setLastSeenFeatureVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_seen_feature_version', version);
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_tourPrefix) || key.startsWith(_masteryPrefix) || key.startsWith('tour_seen_')) {
        await prefs.remove(key);
      }
    }
  }
}
