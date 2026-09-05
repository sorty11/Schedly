import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/services/attendance/progressive_attendance_reconciler.dart';

void main() {
  group('Large PDF Chunking & Idempotency Tests', () {
    test('1. Chunking 1,000+ operations into 450-op batches partitions correctly', () {
      final totalRecords = 1125;
      final batchSize = 450;
      final expectedBatches = (totalRecords / batchSize).ceil(); // ceil(1125 / 450) = 3 batches

      final batches = <List<int>>[];
      var currentBatch = <int>[];

      for (var i = 1; i <= totalRecords; i++) {
        currentBatch.add(i);
        if (currentBatch.length >= batchSize) {
          batches.add(currentBatch);
          currentBatch = [];
        }
      }
      if (currentBatch.isNotEmpty) {
        batches.add(currentBatch);
      }

      expect(batches.length, equals(expectedBatches));
      expect(batches[0].length, equals(450));
      expect(batches[1].length, equals(450));
      expect(batches[2].length, equals(225));
      expect(batches.fold<int>(0, (sum, b) => sum + b.length), equals(totalRecords));
    });

    test('2. 1,000+ logs reconcile with idempotency and zero duplicates on rerun', () {
      final logs = <AttendanceLog>[];
      final baseDate = DateTime(2026, 1, 1);

      // Generate 1,000 distinct attendance logs across 10 subjects
      for (var i = 0; i < 1000; i++) {
        final dayOffset = i ~/ 5;
        final slotIndex = i % 5;
        final date = baseDate.add(Duration(days: dayOffset));
        final subj = 'SUBJ_${i % 10}';
        final startMins = 540 + slotIndex * 60;
        final endMins = startMins + 60;

        logs.add(
          AttendanceLog(
            id: 'log_$i',
            subjectCode: subj,
            component: 'Merged',
            rawSubjectText: subj,
            normalizedSubject: subj,
            date: date,
            startTime: startMins,
            endTime: endMins,
            status: i % 10 == 0 ? 'absent' : 'present',
            source: 'pdf_import',
            confidence: MatchConfidence.exact,
            importedAt: DateTime(2026, 7, 1),
          ),
        );
      }

      expect(logs.length, equals(1000));

      // First reconciliation into empty database
      final run1 = ProgressiveAttendanceReconciler.reconcile(
        incomingLogs: logs,
        existingLogs: [],
      );

      expect(run1.newRecords, equals(1000));
      expect(run1.updatedRecords, equals(0));
      expect(run1.duplicatesIgnored, equals(0));
      expect(run1.reconciledLogs.length, equals(1000));

      // Second reconciliation with identical logs (rerun simulation)
      final run2 = ProgressiveAttendanceReconciler.reconcile(
        incomingLogs: logs,
        existingLogs: run1.reconciledLogs,
      );

      expect(run2.newRecords, equals(0));
      expect(run2.updatedRecords, equals(0));
      expect(run2.duplicatesIgnored, equals(1000));
      expect(run2.reconciledLogs.length, equals(1000));
    });

    test('3. Simulated retry after network failure preserves dataset consistency', () {
      final logs = <AttendanceLog>[];
      final baseDate = DateTime(2026, 2, 1);

      for (var i = 0; i < 500; i++) {
        final date = baseDate.add(Duration(days: i ~/ 4));
        final slot = i % 4;
        logs.add(
          AttendanceLog(
            id: 'retry_log_$i',
            subjectCode: 'COURSE_${i % 5}',
            component: 'Merged',
            rawSubjectText: 'COURSE_${i % 5}',
            normalizedSubject: 'COURSE_${i % 5}',
            date: date,
            startTime: 540 + slot * 60,
            endTime: 600 + slot * 60,
            status: 'present',
            source: 'pdf_import',
            confidence: MatchConfidence.exact,
            importedAt: DateTime(2026, 7, 1),
          ),
        );
      }

      // Simulate partial commit: only first 300 succeeded before network dropped
      final partialCommitted = logs.take(300).toList();

      // Retry the full 500-item import
      final retryResult = ProgressiveAttendanceReconciler.reconcile(
        incomingLogs: logs,
        existingLogs: partialCommitted,
      );

      expect(retryResult.newRecords, equals(200)); // exactly the remaining 200 items committed
      expect(retryResult.duplicatesIgnored, equals(300)); // the 300 already committed safely skipped
      expect(retryResult.reconciledLogs.length, equals(500));
    });
  });
}
