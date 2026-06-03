import 'package:shared_preferences/shared_preferences.dart';

import 'user_roles.dart';

class AppSettings {
  static UserRole currentRole =
      UserRole.student;

  static String? srSubject;
  static String? srDivision;

  static Future<void> loadRole() async {
    final prefs =
        await SharedPreferences.getInstance();

    final role =
        prefs.getString('user_role');

    switch (role) {
      case 'cr':
        currentRole = UserRole.cr;
        break;

      case 'sr':
        currentRole = UserRole.sr;
        break;

      default:
        currentRole = UserRole.student;
    }
  }

  static Future<void> loadSRDetails() async {
    final prefs =
        await SharedPreferences.getInstance();

    srDivision =
        prefs.getString('sr_division');

    srSubject =
        prefs.getString('sr_subject');
  }

  static Future<void> saveRole(
    UserRole role,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    currentRole = role;

    await prefs.setString(
      'user_role',
      role.name,
    );
  }

  static Future<void> saveSRDetails({
    required String division,
    required String subject,
  }) async {
    final prefs =
        await SharedPreferences.getInstance();

    srDivision = division;
    srSubject = subject;

    await prefs.setString(
      'sr_division',
      division,
    );

    await prefs.setString(
      'sr_subject',
      subject,
    );
  }

  static Future<void> resetRole() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove('user_role');
    await prefs.remove('sr_division');
    await prefs.remove('sr_subject');

    currentRole = UserRole.student;

    srDivision = null;
    srSubject = null;
  }
}