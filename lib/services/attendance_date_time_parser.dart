/// Parses date/time strings from NMIMS attendance PDFs.
class AttendanceDateTimeParser {
  static const _months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  static final _dateRegex = RegExp(r'^([A-Z][a-z]{2})\s+(\d{1,2}),\s+(\d{4})$');

  static final _timeRegex = RegExp(
    r'^(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  );

  static final _durationDateRegex = RegExp(
    r'(\d{1,2})[./\-](\d{1,2})[./\-](\d{4})',
  );

  /// Parses dates like "Jan 5, 2026" or "Jul 13, 2026" or "Aug 30, 2026".
  static DateTime? parseDate(String raw) {
    final trimmed = raw.trim();
    final match = _dateRegex.firstMatch(trimmed);
    if (match == null) return null;

    final month = _months[match.group(1)];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month == null || day == null || year == null) return null;

    return DateTime(year, month, day);
  }

  /// Parses times like "9:15:00 AM" or "10:14:59 AM" or "1:00:00 PM".
  static int? parseTimeToMinutes(String raw) {
    final trimmed = raw.trim().toUpperCase();
    final match = _timeRegex.firstMatch(trimmed);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final period = match.group(4)?.toUpperCase();
    if (hour == null || minute == null || period == null) return null;

    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return hour * 60 + minute;
  }

  /// Parses duration dates like "02.01.2026" or "13.07.2026" from report header.
  static DateTime? parseDurationDate(String raw) {
    final match = _durationDateRegex.firstMatch(raw.trim());
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;

    return DateTime(year, month, day);
  }

  /// Parses "From 13.07.2026 to 05.08.2026" style duration lines.
  static ({DateTime? start, DateTime? end}) parseReportDuration(String raw) {
    final matches = _durationDateRegex.allMatches(raw).toList();
    if (matches.length >= 2) {
      return (
        start: parseDurationDate(matches[0].group(0)!),
        end: parseDurationDate(matches[1].group(0)!),
      );
    } else if (matches.length == 1) {
      return (start: parseDurationDate(matches[0].group(0)!), end: null);
    }
    return (start: null, end: null);
  }
}
