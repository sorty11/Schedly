import '../app_settings.dart';
import '../user_roles.dart';

class PermissionService {
  /// Checks if the current user has permission to manage a specific lecture.
  /// Used centrally by Timetable, Dashboard, Analytics, and Replacement flows.
  static bool canManageLecture({
    required String lectureSubject,
    required String lectureComponent,
    required String lectureBatch,
  }) {
    if (AppSettings.currentRole == UserRole.cr) return true;
    if (AppSettings.currentRole != UserRole.sr) return false;

    final srSubj = AppSettings.srSubject;
    if (srSubj == null) return false;

    // Strict subject-wide matching. Batch and Component are intentionally ignored.
    if (lectureSubject != srSubj) return false;

    return true;
  }
}
