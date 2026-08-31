import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_settings.dart';
import '../models/attendance_import_models.dart';
import '../models/attendance_log.dart';
import 'attendance_pdf_parser.dart';
import 'attendance_service.dart';
import 'course_configuration_service.dart';

/// Orchestrates PDF attendance import: parse → preview → commit.
class AttendanceParserService {
  /// Parses PDF bytes and returns a preview for user review.
  static Future<AttendanceImportPreview> parseForPreview({
    required Uint8List bytes,
    required String division,
    AttendanceParseProgress? onProgress,
  }) async {
    final parsed = AttendancePdfParser.parseBytes(
      bytes,
      onProgress: onProgress,
    );

    if (parsed.isImageOnly) {
      return AttendanceImportPreview(
        metadata: parsed.metadata,
        logs: const [],
        errors: parsed.errors,
        warnings: parsed.warnings,
        isImageOnly: true,
        totalPagesParsed: parsed.metadata.pageCount,
      );
    }

    if (parsed.errors.isNotEmpty && parsed.rows.isEmpty) {
      return AttendanceImportPreview(
        metadata: parsed.metadata,
        logs: const [],
        errors: parsed.errors,
        warnings: parsed.warnings,
        totalPagesParsed: parsed.metadata.pageCount,
      );
    }

    final configuredCourses = await CourseConfigurationService.getMetadata(
      division,
    );
    final existingLogs = await AttendanceService.getLogs();

    final preview = AttendancePdfParser.buildPreview(
      metadata: parsed.metadata,
      rows: parsed.rows,
      configuredCourses: configuredCourses,
      existingLogs: existingLogs,
      parseWarnings: parsed.warnings,
      parseErrors: parsed.errors,
      isImageOnly: parsed.isImageOnly,
      totalPagesParsed: parsed.metadata.pageCount,
    );

    await _maybeSaveBatchFromRows(parsed.rows);

    return preview;
  }

  /// Commits a reviewed import preview to Firestore.
  static Future<AttendanceImportResult> commitPreview({
    required String division,
    required AttendanceImportPreview preview,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AttendancePdfParseException(
        'User is not authenticated. Please log in to import attendance.',
      );
    }

    if (!preview.canImport) {
      throw AttendancePdfParseException(
        'Import cannot proceed. Please resolve errors first.',
        details: preview.errors,
      );
    }

    try {
      return await AttendanceService.commitPdfImport(
        division: division,
        logs: preview.logs,
      );
    } on Exception catch (e) {
      debugPrint('PDF IMPORT COMMIT ERROR: $e');
      rethrow;
    }
  }

  /// Detects batch from parsed rows and saves if found.
  static Future<void> _maybeSaveBatchFromRows(
    List<ParsedAttendanceRow> rows,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (final row in rows) {
      final batch = row.batchOrSection;
      if (batch != null && RegExp(r'^[CDT][1-9]$').hasMatch(batch)) {
        try {
          await AppSettings.saveStudentBatch(batch);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'batch': batch});
          debugPrint('PDF PARSER: Auto-detected batch -> $batch');
        } catch (e) {
          debugPrint('Failed to save auto-detected batch: $e');
        }
        return;
      }
    }
  }

  /// Deletes all PDF-imported logs for the current user.
  static Future<int> undoPdfImport(String division) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw AttendancePdfParseException('Not signed in');

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('attendance_logs')
        .where('source', isEqualTo: 'pdf_import')
        .get();

    if (snap.docs.isEmpty) return 0;

    final batch = FirebaseFirestore.instance.batch();
    final affected = <String, String>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final subject = data['subjectCode'] as String? ?? '';
      final component = data['component'] as String? ?? 'Theory';
      if (subject.isNotEmpty) affected[subject] = component;
      batch.delete(doc.reference);
    }
    await batch.commit();

    for (final entry in affected.entries) {
      await AttendanceService.recomputeAggregateForSubject(
        division: division,
        subjectCode: entry.key,
        component: entry.value,
      );
    }

    return snap.docs.length;
  }
}
