import '../models/timetable_entry.dart';

class ResolvedTimetable {
  final bool isHoliday;
  final String? holidayName;
  final List<TimetableEntry> lectures;

  ResolvedTimetable({
    required this.isHoliday,
    this.holidayName,
    required this.lectures,
  });
}

class TimetableResolverService {
  /// Resolves the raw list of timetable entries for a specific date and user batch.
  /// Applies visibility rules (validForDate, hiddenOnDates).
  /// Detects holidays. If a holiday exists for the date, returns empty lectures.
  static ResolvedTimetable resolve({
    required List<TimetableEntry> rawEntries,
    required String targetDateStr,
    String? userBatch,
    bool isEditMode = false,
  }) {
    // 1. Check for holidays specific to this date
    final holidays = rawEntries
        .where((e) => e.isHoliday && e.validForDate == targetDateStr)
        .toList();

    if (holidays.isNotEmpty) {
      return ResolvedTimetable(
        isHoliday: true,
        holidayName: holidays.first.subject,
        lectures: [],
      );
    }

    // 2. Filter visible lectures
    final visibleLectures = rawEntries.where((e) {
      // Ignore holidays in the normal lecture list
      if (e.isHoliday) return false;

      // Respect validForDate and hiddenOnDates
      if (!e.isVisibleOnDate(targetDateStr)) return false;

      // Respect batch filtering unless in edit mode
      if (!isEditMode) {
        if (!e.shouldIncludeForUserBatch(userBatch)) return false;
      }

      return true;
    }).toList();

    return ResolvedTimetable(isHoliday: false, lectures: visibleLectures);
  }
}
