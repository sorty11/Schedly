import 'package:flutter/material.dart';
import '../assignments/assignments_page.dart';
import '../faculty/faculty_dashboard_page.dart';
import '../app_settings.dart';

class DeepLinkRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void handle(String? link) {
    if (link == null || link.isEmpty || link == '/') return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (link == 'faculty_dashboard' || link == '/faculty_dashboard') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const FacultyDashboardPage(),
        ),
      );
    } else if (link.startsWith('/assignment') || link.startsWith('assignment')) {
      final division = AppSettings.sectionId ?? AppSettings.division;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssignmentsPage(division: division),
        ),
      );
    }
  }
}
