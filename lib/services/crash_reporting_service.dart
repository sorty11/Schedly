import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReportingService {
  static Future<void> logError(dynamic error, StackTrace? stackTrace, {String? reason, bool isFatal = false}) async {
    try {
      if (kIsWeb) return;
      await FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: reason, fatal: isFatal);
    } catch (e) {
      debugPrint('Failed to log error to Crashlytics: $e');
    }
  }

  static Future<void> logMessage(String message) async {
    try {
      if (kIsWeb) return;
      await FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      debugPrint('Failed to log message to Crashlytics: $e');
    }
  }
}
