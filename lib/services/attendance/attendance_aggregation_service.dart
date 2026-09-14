import '../../models/attendance_log.dart';
import '../../models/attendance_record.dart';
import '../attendance_status_mapper.dart';

/// Clean container holding aggregated attendance records, completed occurrence counts,
/// academic hour totals, and grouped raw records for consistent consumption.
class AggregatedAttendanceData {
  final Map<String, AttendanceRecord> records;
  final Map<String, int> completedCounts;
  final Map<String, int> completedHours;
  final Map<String, int> presentHours;
  final Map<String, int> absentHours;
  final Map<String, int> typicalSessionHours;
  final Map<String, List<AttendanceRecord>> rawGrouped;

  const AggregatedAttendanceData({
    required this.records,
    required this.completedCounts,
    this.completedHours = const {},
    this.presentHours = const {},
    this.absentHours = const {},
    this.typicalSessionHours = const {},
    required this.rawGrouped,
  });
}

class AttendanceAggregationService {
  /// Computes the academic duration in hours for an individual attendance log.
  /// Uses actual start and end times if valid; otherwise applies the standard
  /// component default (Lab = 2h, Theory/Tutorial = 1h).
  static int computeLogDurationHours(AttendanceLog log) {
    if (log.startTime != null &&
        log.endTime != null &&
        log.endTime! > log.startTime!) {
      final mins = log.endTime! - log.startTime!;
      final h = (mins / 60.0).round();
      if (h > 0) return h;
    }
    final normComp = AttendanceLog.normalizeComponent(log.component);
    return normComp == 'Lab' ? 2 : 1;
  }

  /// Aggregates attendance records and logs into a single authoritative set of records,
  /// session counts, and academic hour totals (strictly separated).
  static AggregatedAttendanceData aggregate({
    required List<AttendanceRecord> rawRecords,
    required List<AttendanceLog> logs,
    required String division,
  }) {
    final Map<String, AttendanceRecord> records = {};
    final Map<String, List<AttendanceRecord>> rawGrouped = {};
    final Map<String, int> completedCounts = {};
    final Map<String, int> completedHours = {};
    final Map<String, int> presentHours = {};
    final Map<String, int> absentHours = {};
    final Map<String, int> typicalSessionHours = {};

    // 1. If logs exist, they are the ground truth for imported lectures
    if (logs.isNotEmpty) {
      final uniqueLogs = <String, AttendanceLog>{};
      for (final log in logs) {
        if (log.subjectCode.isEmpty) continue;
        final key = log.deduplicationKey;
        final existing = uniqueLogs[key];
        if (existing == null || log.importedAt.isAfter(existing.importedAt)) {
          uniqueLogs[key] = log;
        }
      }
      final deduplicatedLogs = uniqueLogs.values.toList();

      final aggregatedLogs =
          <
            String,
            ({
              String subjectCode,
              String component,
              int presentSessions,
              int absentSessions,
              int cancelled,
              int presentHours,
              int absentHours,
              int totalCompletedHours,
            })
          >{};

      for (final log in deduplicatedLogs) {
        final canonSubj = AttendanceLog.canonicalSubjectCode(log.subjectCode);
        final displayComponent = AttendanceLog.canonicalComponent(
          canonSubj,
          log.component,
        );
        final groupKey = AttendanceLog.canonicalGroupKey(
          canonSubj,
          log.component,
        );

        final cur =
            aggregatedLogs[groupKey] ??
            (
              subjectCode: canonSubj,
              component: displayComponent,
              presentSessions: 0,
              absentSessions: 0,
              cancelled: 0,
              presentHours: 0,
              absentHours: 0,
              totalCompletedHours: 0,
            );

        final durHours = computeLogDurationHours(log);

        int pSessions = cur.presentSessions;
        int aSessions = cur.absentSessions;
        int pHours = cur.presentHours;
        int aHours = cur.absentHours;
        int compHours = cur.totalCompletedHours;

        if (log.status == 'present') {
          pSessions++;
          pHours += durHours;
        } else if (log.status == 'absent') {
          aSessions++;
          aHours += durHours;
        }

        if (AttendanceStatusMapper.countsAsCompletedOccurrence(log.status)) {
          completedCounts[groupKey] = (completedCounts[groupKey] ?? 0) + 1;
          compHours += durHours;
        }

        aggregatedLogs[groupKey] = (
          subjectCode: canonSubj,
          component: displayComponent,
          presentSessions: pSessions,
          absentSessions: aSessions,
          cancelled: cur.cancelled,
          presentHours: pHours,
          absentHours: aHours,
          totalCompletedHours: compHours,
        );
      }

      for (final entry in aggregatedLogs.entries) {
        final val = entry.value;
        final recordDivision = rawRecords.isNotEmpty
            ? rawRecords.first.division
            : division;
        final rec = AttendanceRecord(
          id: '__',
          division: recordDivision,
          subjectCode: val.subjectCode,
          component: val.component,
          present: val.presentSessions,
          absent: val.absentSessions,
          cancelled: val.cancelled,
        );
        records[entry.key] = rec;
        rawGrouped[entry.key] = [rec];

        presentHours[entry.key] = val.presentHours;
        absentHours[entry.key] = val.absentHours;
        completedHours[entry.key] = val.totalCompletedHours;

        final compCount = completedCounts[entry.key] ?? 0;
        if (compCount > 0) {
          typicalSessionHours[entry.key] =
              (val.totalCompletedHours / compCount).round().clamp(1, 4);
        } else {
          final norm = AttendanceLog.normalizeComponent(val.component);
          typicalSessionHours[entry.key] = norm == 'Lab' ? 2 : 1;
        }
      }

      // Include any subject/component that exists in rawRecords but NOT in logs.
      // Crucial: Check by canonical GROUP KEY, never suppress an independent component (e.g. Lab)
      // just because logs exist for another component (e.g. Theory).
      final groupKeysInLogs = deduplicatedLogs
          .map((l) {
            final canon = AttendanceLog.canonicalSubjectCode(l.subjectCode);
            return AttendanceLog.canonicalGroupKey(canon, l.component);
          })
          .toSet();

      for (final r in rawRecords) {
        final canonSubj = AttendanceLog.canonicalSubjectCode(r.subjectCode);
        final displayComponent = AttendanceLog.canonicalComponent(
          canonSubj,
          r.component,
        );
        final groupKey = AttendanceLog.canonicalGroupKey(
          canonSubj,
          r.component,
        );

        if (groupKeysInLogs.contains(groupKey)) {
          continue;
        }

        final normComp = AttendanceLog.normalizeComponent(r.component);
        final defDuration = normComp == 'Lab' ? 2 : 1;

        if (records.containsKey(groupKey)) {
          final existing = records[groupKey]!;
          if (r.total > existing.total) {
            records[groupKey] = AttendanceRecord(
              id: r.id,
              division: r.division,
              subjectCode: canonSubj,
              component: displayComponent,
              present: r.present,
              absent: r.absent,
              cancelled: r.cancelled,
            );
            rawGrouped[groupKey] = [r];
            completedCounts[groupKey] = r.present + r.absent;
            presentHours[groupKey] = r.present * defDuration;
            absentHours[groupKey] = r.absent * defDuration;
            completedHours[groupKey] = (r.present + r.absent) * defDuration;
            typicalSessionHours[groupKey] = defDuration;
          }
        } else {
          records[groupKey] = AttendanceRecord(
            id: r.id,
            division: r.division,
            subjectCode: canonSubj,
            component: displayComponent,
            present: r.present,
            absent: r.absent,
            cancelled: r.cancelled,
          );
          rawGrouped[groupKey] = [r];
          completedCounts[groupKey] = r.present + r.absent;
          presentHours[groupKey] = r.present * defDuration;
          absentHours[groupKey] = r.absent * defDuration;
          completedHours[groupKey] = (r.present + r.absent) * defDuration;
          typicalSessionHours[groupKey] = defDuration;
        }
      }
    } else {
      // 2. Fallback: Aggregate raw Firestore records
      final Map<String, List<AttendanceRecord>> recordsByGroup = {};

      for (final r in rawRecords) {
        final canonSubj = AttendanceLog.canonicalSubjectCode(r.subjectCode);
        final groupKey = AttendanceLog.canonicalGroupKey(
          canonSubj,
          r.component,
        );
        recordsByGroup.putIfAbsent(groupKey, () => []).add(r);
      }

      for (final entry in recordsByGroup.entries) {
        final groupKey = entry.key;
        final recList = entry.value;
        final first = recList.first;
        final canonSubj = AttendanceLog.canonicalSubjectCode(first.subjectCode);
        final displayComponent = AttendanceLog.canonicalComponent(
          canonSubj,
          first.component,
        );

        final distinctComponents = recList
            .map((r) => AttendanceLog.normalizeComponent(r.component))
            .toSet();
        final hasMerged =
            distinctComponents.contains('Merged') ||
            recList.any((r) => r.component == 'Merged');

        int totalPresent = 0;
        int totalAbsent = 0;
        int totalCancelled = 0;

        if (hasMerged || distinctComponents.length == 1) {
          recList.sort((a, b) {
            final cmp = b.total.compareTo(a.total);
            if (cmp != 0) return cmp;
            return b.updatedAt.compareTo(a.updatedAt);
          });
          final best = recList.first;
          totalPresent = best.present;
          totalAbsent = best.absent;
          totalCancelled = best.cancelled;
        } else {
          for (final r in recList) {
            totalPresent += r.present;
            totalAbsent += r.absent;
            totalCancelled += r.cancelled;
          }
        }

        records[groupKey] = AttendanceRecord(
          id: '__',
          division: first.division,
          subjectCode: canonSubj,
          component: displayComponent,
          present: totalPresent,
          absent: totalAbsent,
          cancelled: totalCancelled,
        );
        rawGrouped[groupKey] = recList;
        completedCounts[groupKey] = totalPresent + totalAbsent;

        final normComp = AttendanceLog.normalizeComponent(first.component);
        final defDuration = normComp == 'Lab' ? 2 : 1;
        presentHours[groupKey] = totalPresent * defDuration;
        absentHours[groupKey] = totalAbsent * defDuration;
        completedHours[groupKey] = (totalPresent + totalAbsent) * defDuration;
        typicalSessionHours[groupKey] = defDuration;
      }
    }

    return AggregatedAttendanceData(
      records: records,
      completedCounts: completedCounts,
      completedHours: completedHours,
      presentHours: presentHours,
      absentHours: absentHours,
      typicalSessionHours: typicalSessionHours,
      rawGrouped: rawGrouped,
    );
  }
}
