import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import '../data/course_aliases.dart';

class AttendanceParserService {
  /// Allows user to pick a PDF and parses it immediately.
  static String _formatTime24h(String t) {
    t = t.trim().toUpperCase();
    if (t.isEmpty) return t;
    final isPM = t.contains('PM');
    final clean = t.replaceAll(RegExp(r'[A-Z\s]'), '');
    final parts = clean.split(':');
    if (parts.isEmpty) return t;
    
    int h = int.tryParse(parts[0]) ?? 0;
    int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    
    if (isPM && h < 12) h += 12;
    if (!isPM && h == 12) h = 0;
    
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static Future<void> pickAndParseAttendancePDF(String division) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);
        await parsePDFAndUpload(file.readAsBytesSync(), division);
      }
    } catch (e) {
      debugPrint("Error picking/parsing PDF: $e");
      rethrow;
    }
  }

  static Future<void> parsePDFAndUpload(List<int> bytes, String division) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User is not authenticated. Please log in to import attendance.");
    }
    
    final uid = user.uid;

    try {

    // Extract text from PDF
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final String text = PdfTextExtractor(document).extractText();
    document.dispose();

    // debugPrint("Extracted text: \n$text"); // Eyeball the output if needed

    // Explicitly use multiLine: false since we're splitting by \n and matching per line
    final rowRegex = RegExp(r"^\s*(\d+)\s+(.+?)\s+([A-Z][a-z]{2} \d{1,2}, \d{4})\s+(\d{1,2}:\d{2}:\d{2} [AP]M)\s+(\d{1,2}:\d{2}:\d{2} [AP]M)\s+(P|A|E|L|NU)\s*$");
    final courseRegex = RegExp(r"^(.*?)(?:[A-Z]\d\s*(?:CE)?\s*(?:Sem)?\s*(?:III|II|IV|V|VI|VII|VIII|I)?\s*(?:C\d)?)\s*$");
    final dateRegex = RegExp(r"^[A-Z][a-z]{2} \d{1,2}, \d{4}$");

    final rawLines = text.split('\n');
    final lines = rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    debugPrint('PDF PARSER: Extracted ${rawLines.length} raw lines, ${lines.length} non-empty lines from PDF');

    final uniqueCoursesMap = <String, Map<String, String>>{}; // Maps shortCode to {subjectCode, component}
    
    final db = FirebaseFirestore.instance;
    var currentBatch = db.batch();
    int operationCount = 0;
    int validLogsCount = 0;
    Map<String, dynamic>? sampleLog;

    Future<void> commitBatch() async {
      if (operationCount > 0) {
        await currentBatch.commit();
        currentBatch = db.batch();
        operationCount = 0;
      }
    }

    for (int i = 1; i < lines.length - 3; i++) {
      final line = lines[i];

      if (RegExp(r'^[A-Z][a-z]{2}\s\d{1,2},\s\d{4}$').hasMatch(line)) {
        final courseRaw = lines[i - 1];
        final date = line;
        final startTimeRaw = lines[i + 1];
        final endTimeRaw = lines[i + 2];
        final statusRaw = lines[i + 3];

        debugPrint('Found Class: $courseRaw on $date -> $statusRaw');

        // Only process if status is valid (prevent matching random dates in headers)
        if (!['P', 'A', 'NU', 'E', 'L'].contains(statusRaw)) continue;

        final startTime = _formatTime24h(startTimeRaw);
        final endTime = _formatTime24h(endTimeRaw);

        String course = courseRaw;
        final courseMatch = courseRegex.firstMatch(courseRaw);
        if (courseMatch != null) {
          course = courseMatch.group(1)!.trim();
        }

        final rawKeyDate = date.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        
        // Component Derivation Logic
        String component = 'Theory';
        if (courseRaw.toUpperCase().contains('P4') || courseRaw.toUpperCase().contains('PRACTICAL') || courseRaw.toUpperCase().contains('LAB')) {
          component = 'Lab';
        } else if (courseRaw.toUpperCase().contains('U4') || courseRaw.toUpperCase().contains('TUTORIAL')) {
          component = 'Tutorial';
        }

        // Reverse Lookup for Short Code
        String subjectCode = course;
        bool aliasFound = false;
        for (final entry in courseAliases.entries) {
          if (course.toUpperCase().contains(entry.value.toUpperCase())) {
            subjectCode = entry.key;
            aliasFound = true;
            break;
          }
        }
        if (!aliasFound) {
          debugPrint("WARNING: No alias found for '$course'. UI lookup might fail!");
        }

        uniqueCoursesMap[subjectCode] = {'subjectCode': subjectCode, 'component': component};

        // Convert times to integers (minutes from midnight) for AttendanceLog
        final startParts = startTime.split(':');
        final endParts = endTime.split(':');
        final startMins = (int.tryParse(startParts[0]) ?? 0) * 60 + (int.tryParse(startParts[1]) ?? 0);
        final endMins = (int.tryParse(endParts[0]) ?? 0) * 60 + (int.tryParse(endParts[1]) ?? 0);

        // Convert status string
        String statusStr = 'unknown';
        if (statusRaw == 'P') statusStr = 'present';
        else if (statusRaw == 'A') statusStr = 'absent';
        else if (statusRaw == 'NU') statusStr = 'not updated';
        
        // Parse date for Timestamp
        // Date is like "Jul 13, 2026"
        final months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
        final dateSplit = date.replaceAll(',', '').split(' ');
        final month = months[dateSplit[0]] ?? 1;
        final day = int.tryParse(dateSplit[1]) ?? 1;
        final year = int.tryParse(dateSplit[2]) ?? 2024;
        final dateObj = DateTime(year, month, day);

        final deduplicationKey = '${division}_$year-$month-${day}_${startMins}_${subjectCode}_$component';
        final docRef = db.collection('users').doc(uid).collection('attendance_logs').doc(deduplicationKey);
        
        final docData = {
          'subjectCode': subjectCode,
          'component': component,
          'rawSubjectText': courseRaw,
          'normalizedSubject': course,
          'date': Timestamp.fromDate(dateObj),
          'startTime': startMins,
          'endTime': endMins,
          'status': statusStr,
          'source': 'pdf_import',
          'confidenceScore': 100, // MatchConfidence.exact
          'importedAt': FieldValue.serverTimestamp(),
        };

        if (sampleLog == null) {
          sampleLog = docData;
          debugPrint('PDF PARSER SAMPLE: $docData');
        }
        validLogsCount++;

        currentBatch.set(docRef, docData, SetOptions(merge: true));
        operationCount++;

        if (operationCount >= 450) {
          await commitBatch();
        }
      }
    }
    
    debugPrint('PDF PARSER: Generated $validLogsCount valid log objects');

    // Commit any remaining writes
    await commitBatch();

    // -----------------------------------------------------
    // SUMMARY RECOMPUTATION
    // -----------------------------------------------------
    const double threshold = 0.75;
    var summaryBatch = db.batch();
    int summaryOps = 0;

    Future<void> commitSummaryBatch() async {
      if (summaryOps > 0) {
        await summaryBatch.commit();
        summaryBatch = db.batch();
        summaryOps = 0;
      }
    }

    // First, find all distinct subject codes from the map
    final uniqueSubjects = uniqueCoursesMap.values.map((e) => e['subjectCode']!).toSet();

    for (final subjectCode in uniqueSubjects) {
      // SnS and PnS merge all components into a single 'Theory' summary document
      if (subjectCode == 'SnS' || subjectCode == 'PnS') {
        final snapshot = await db.collection('users').doc(uid).collection('attendance_logs')
            .where('subjectCode', isEqualTo: subjectCode)
            .where('status', whereIn: ['present', 'absent']) // Ignores component, grabs all
            .get();

        int present = 0;
        final int held = snapshot.docs.length;
        for (var doc in snapshot.docs) {
          if (doc.data()['status'] == 'present') present++;
        }
        final int absent = held - present;

        final recordId = '${division}_${subjectCode}_Theory'.replaceAll(RegExp(r'\s+'), '_');
        final summaryRef = db.collection('users').doc(uid).collection('attendance').doc(recordId);

        summaryBatch.set(summaryRef, {
          'division': division,
          'subjectCode': subjectCode,
          'component': 'Theory', // Force 'Theory' so the UI doesn't spawn an extra Lab card
          'present': present,
          'absent': absent,
          'cancelled': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        summaryOps++;
      } else {
        // DSA and others split strictly by their distinct components
        final componentsForSubject = uniqueCoursesMap.values
            .where((e) => e['subjectCode'] == subjectCode)
            .map((e) => e['component']!)
            .toSet();

        for (final component in componentsForSubject) {
          final snapshot = await db.collection('users').doc(uid).collection('attendance_logs')
              .where('subjectCode', isEqualTo: subjectCode)
              .where('component', isEqualTo: component)
              .where('status', whereIn: ['present', 'absent'])
              .get();

          int present = 0;
          final int held = snapshot.docs.length;
          for (var doc in snapshot.docs) {
            if (doc.data()['status'] == 'present') present++;
          }
          final int absent = held - present;

          final recordId = '${division}_${subjectCode}_$component'.replaceAll(RegExp(r'\s+'), '_');
          final summaryRef = db.collection('users').doc(uid).collection('attendance').doc(recordId);

          summaryBatch.set(summaryRef, {
            'division': division,
            'subjectCode': subjectCode,
            'component': component,
            'present': present,
            'absent': absent,
            'cancelled': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          summaryOps++;
        }
      }

      if (summaryOps >= 450) {
        await commitSummaryBatch();
      }
    }

      await commitSummaryBatch();

    } on FirebaseException catch (e) {
      debugPrint('PDF PARSER ERROR during Firestore write: $e');
      if (e.code == 'permission-denied') {
        throw Exception("Database access denied. Please re-login or check permissions.");
      }
      rethrow;
    } catch (e) {
      debugPrint('PDF PARSER ERROR: $e');
      rethrow;
    }
  }
}
