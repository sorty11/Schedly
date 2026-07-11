import 'package:flutter/foundation.dart';

class DiagnosticLogger {
  static final List<String> fcmLogs = [];
  static final List<String> sessionLogs = [];
  static const int _maxLogs = 20;

  static void logFCM(String message) {
    if (fcmLogs.length >= _maxLogs) fcmLogs.removeAt(0);
    fcmLogs.add('${DateTime.now().toIso8601String().split('T').last}: $message');
    debugPrint(message);
  }

  static void logSession(String message) {
    if (sessionLogs.length >= _maxLogs) sessionLogs.removeAt(0);
    sessionLogs.add('${DateTime.now().toIso8601String().split('T').last}: $message');
    debugPrint(message);
  }
}
