/// Maps official NMIMS/SVKM PDF attendance status codes to Schedly values.
class AttendanceStatusMapper {
  static const Map<String, String> _statusMap = {
    'P': 'present',
    'A': 'absent',
    'E': 'exemption',
    'L': 'late_admission',
    'NU': 'not_updated',
  };

  static const Set<String> validRawStatuses = {'P', 'A', 'E', 'L', 'NU'};

  /// Returns the Schedly-normalized status, or null if unknown.
  static String? normalize(String raw) {
    final trimmed = raw.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    return _statusMap[trimmed];
  }

  static bool isKnown(String raw) =>
      _statusMap.containsKey(raw.trim().toUpperCase());

  /// Statuses that count toward present/absent percentage calculations.
  static bool countsTowardPercentage(String normalizedStatus) {
    return normalizedStatus == 'present' || normalizedStatus == 'absent';
  }

  static String displayLabel(String normalizedStatus) {
    switch (normalizedStatus) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'exemption':
        return 'Exemption';
      case 'late_admission':
        return 'Late Admission';
      case 'not_updated':
        return 'Not Updated';
      default:
        return normalizedStatus;
    }
  }
}
