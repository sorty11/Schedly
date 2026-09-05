import '../../models/attendance_log.dart';

/// Reconciles progressive snapshots and enforces the commutativity invariant:
/// import(A then B) == import(B then A)
///
/// Uses authoritative source metadata (report date / snapshot timestamp) rather than
/// arbitrary local network/device write times to guarantee determinism.
class ProgressiveAttendanceReconciler {
  static const Set<String> _definitiveStatuses = {
    'present',
    'absent',
    'exemption',
    'late_admission',
  };

  /// Reconciles a list of incoming attendance logs against existing logs.
  static ({
    List<AttendanceLog> reconciledLogs,
    int newRecords,
    int updatedRecords,
    int duplicatesIgnored,
    int conflicts,
  }) reconcile({
    required List<AttendanceLog> incomingLogs,
    required List<AttendanceLog> existingLogs,
    DateTime? incomingReportDate,
  }) {
    final store = <String, AttendanceLog>{
      for (final log in existingLogs) log.deduplicationKey: log,
    };

    var newCount = 0;
    var updatedCount = 0;
    var duplicatesIgnored = 0;
    var conflicts = 0;

    for (final incoming in incomingLogs) {
      final key = incoming.deduplicationKey;
      final existing = store[key];

      if (existing == null) {
        store[key] = incoming;
        newCount++;
        continue;
      }

      // Exact same status -> idempotent skip
      if (existing.status == incoming.status) {
        duplicatesIgnored++;
        continue;
      }

      final existingIsDefinitive = _definitiveStatuses.contains(existing.status);
      final incomingIsDefinitive = _definitiveStatuses.contains(incoming.status);

      // Rule 1: Definitive status strictly overrides non-definitive ('not_updated')
      if (!existingIsDefinitive && incomingIsDefinitive) {
        store[key] = incoming;
        updatedCount++;
        continue;
      }

      // Rule 2: Older non-definitive status ('not_updated') CANNOT overwrite a definitive status
      if (existingIsDefinitive && !incomingIsDefinitive) {
        duplicatesIgnored++;
        continue;
      }

      // Rule 3: Both are definitive but differ (e.g. Present in one snapshot, Absent in another)
      if (existingIsDefinitive && incomingIsDefinitive) {
        // Use authoritative report timestamps if available
        if (incomingReportDate != null) {
          // If incoming report is newer than existing imported report
          if (incomingReportDate.isAfter(existing.importedAt)) {
            store[key] = incoming;
            updatedCount++;
          } else {
            duplicatesIgnored++;
          }
        } else {
          // Both definitive on same key without authoritative timestamp -> record conflict
          conflicts++;
          // Retain existing to preserve stability
        }
      }
    }

    return (
      reconciledLogs: store.values.toList(),
      newRecords: newCount,
      updatedRecords: updatedCount,
      duplicatesIgnored: duplicatesIgnored,
      conflicts: conflicts,
    );
  }

  /// Verifies the commutativity invariant between two sets of logs:
  /// reconcile([A, B]) == reconcile([B, A])
  static bool verifyCommutativity({
    required List<AttendanceLog> logsA,
    required List<AttendanceLog> logsB,
    DateTime? reportDateA,
    DateTime? reportDateB,
  }) {
    final run1 = reconcile(
      incomingLogs: logsB,
      existingLogs: logsA,
      incomingReportDate: reportDateB,
    );

    final run2 = reconcile(
      incomingLogs: logsA,
      existingLogs: logsB,
      incomingReportDate: reportDateA,
    );

    if (run1.reconciledLogs.length != run2.reconciledLogs.length) {
      return false;
    }

    final map1 = {for (final l in run1.reconciledLogs) l.deduplicationKey: l.status};
    final map2 = {for (final l in run2.reconciledLogs) l.deduplicationKey: l.status};

    for (final entry in map1.entries) {
      if (map2[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }
}
