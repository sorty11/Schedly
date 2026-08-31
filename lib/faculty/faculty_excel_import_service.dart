import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../timetable_manager.dart';
import '../app_settings.dart';

class FacultyExcelEntry {
  final String day;
  final int startTime;
  final int endTime;
  final String subject;
  final String division;
  final String? room;
  final String? batch;

  FacultyExcelEntry({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.division,
    this.room,
    this.batch,
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
      'division': division,
      if (room != null) 'room': room,
      if (batch != null) 'batch': batch,
    };
  }

  factory FacultyExcelEntry.fromMap(Map<String, dynamic> map) {
    return FacultyExcelEntry(
      day: map['day'] ?? 'Monday',
      startTime: map['startTime'] is int ? map['startTime'] : 0,
      endTime: map['endTime'] is int ? map['endTime'] : 60,
      subject: map['subject'] ?? '',
      division: map['division'] ?? '',
      room: map['room'],
      batch: map['batch'],
    );
  }
}

class FacultyExcelImportService {
  static const List<String> standardDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String normalizeDay(String raw) {
    final clean = raw.trim().toLowerCase();
    for (final day in standardDays) {
      if (day.toLowerCase() == clean || day.toLowerCase().startsWith(clean)) {
        return day;
      }
    }
    return 'Monday';
  }

  static List<FacultyExcelEntry> parseBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    if (fileName.toLowerCase().endsWith('.csv')) {
      return _parseCsv(bytes);
    } else {
      return _parseExcel(bytes);
    }
  }

  static List<FacultyExcelEntry> _parseCsv(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    final headerRow = _splitCsvLine(lines.first);
    final colIndices = _identifyColumns(headerRow);

    final entries = <FacultyExcelEntry>[];
    for (int i = 1; i < lines.length; i++) {
      final row = _splitCsvLine(lines[i]);
      final entry = _extractEntryFromRow(row, colIndices);
      if (entry != null) entries.add(entry);
    }

    return entries;
  }

  static List<FacultyExcelEntry> _parseExcel(Uint8List bytes) {
    final excelDoc = Excel.decodeBytes(bytes);
    final entries = <FacultyExcelEntry>[];

    for (final table in excelDoc.tables.keys) {
      final sheet = excelDoc.tables[table];
      if (sheet == null || sheet.rows.isEmpty) continue;

      int headerRowIndex = 0;
      Map<String, int>? colIndices;

      for (int r = 0; r < sheet.rows.length && r < 5; r++) {
        final rowValues = sheet.rows[r]
            .map((c) => c?.value?.toString().trim() ?? '')
            .toList();
        final identified = _identifyColumns(rowValues);
        if (identified.containsKey('subject') ||
            identified.containsKey('division') ||
            identified.containsKey('day')) {
          headerRowIndex = r;
          colIndices = identified;
          break;
        }
      }

      colIndices ??= _identifyColumns(
        sheet.rows.first.map((c) => c?.value?.toString().trim() ?? '').toList(),
      );

      for (int r = headerRowIndex + 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r]
            .map((c) => c?.value?.toString().trim() ?? '')
            .toList();
        final entry = _extractEntryFromRow(row, colIndices);
        if (entry != null) entries.add(entry);
      }
    }

    return entries;
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    bool insideQuote = false;
    final current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        insideQuote = !insideQuote;
      } else if (char == ',' && !insideQuote) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  static Map<String, int> _identifyColumns(List<String> headers) {
    final map = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().trim();
      if (h.contains('day') || h.contains('weekday')) {
        map['day'] = i;
      } else if (h.contains('start') && h.contains('time')) {
        map['startTime'] = i;
      } else if (h.contains('end') && h.contains('time')) {
        map['endTime'] = i;
      } else if (h == 'time' || h.contains('slot') || h.contains('period')) {
        map['time'] = i;
      } else if (h.contains('subject') || h.contains('course')) {
        map['subject'] = i;
      } else if (h.contains('div') ||
          h.contains('section') ||
          h.contains('class')) {
        map['division'] = i;
      } else if (h.contains('room') ||
          h.contains('hall') ||
          h.contains('lab')) {
        map['room'] = i;
      } else if (h.contains('batch') || h.contains('group')) {
        map['batch'] = i;
      }
    }
    return map;
  }

  static FacultyExcelEntry? _extractEntryFromRow(
    List<String> row,
    Map<String, int> cols,
  ) {
    try {
      String rawDay = '';
      if (cols.containsKey('day') && cols['day']! < row.length) {
        rawDay = row[cols['day']!];
      }

      String subject = '';
      if (cols.containsKey('subject') && cols['subject']! < row.length) {
        subject = row[cols['subject']!];
      }

      String division = '';
      if (cols.containsKey('division') && cols['division']! < row.length) {
        division = row[cols['division']!];
      }

      if (subject.isEmpty && division.isEmpty) return null;

      division = division.replaceAll(' ', '_');

      int startTime = 9 * 60;
      int endTime = 10 * 60;

      if (cols.containsKey('startTime') &&
          cols.containsKey('endTime') &&
          cols['startTime']! < row.length &&
          cols['endTime']! < row.length) {
        final sStr = row[cols['startTime']!];
        final eStr = row[cols['endTime']!];
        startTime = TimetableManager.parseTime(sStr);
        endTime = TimetableManager.parseTime(eStr);
      } else if (cols.containsKey('time') && cols['time']! < row.length) {
        final timeStr = row[cols['time']!];
        final parts = timeStr.split(RegExp(r'[-–—to]'));
        if (parts.length >= 2) {
          startTime = TimetableManager.parseTime(parts[0].trim());
          endTime = TimetableManager.parseTime(parts[1].trim());
        } else {
          startTime = TimetableManager.parseTime(timeStr.trim());
          endTime = startTime + 60;
        }
      }

      if (endTime <= startTime) {
        endTime = startTime + 60;
      }

      String? room;
      if (cols.containsKey('room') && cols['room']! < row.length) {
        final r = row[cols['room']!].trim();
        if (r.isNotEmpty) room = r;
      }

      String? batch;
      if (cols.containsKey('batch') && cols['batch']! < row.length) {
        final b = row[cols['batch']!].trim();
        if (b.isNotEmpty) batch = b;
      }

      return FacultyExcelEntry(
        day: normalizeDay(rawDay.isNotEmpty ? rawDay : 'Monday'),
        startTime: startTime,
        endTime: endTime,
        subject: subject.isNotEmpty ? subject : 'Lecture',
        division: division.isNotEmpty ? division : 'General',
        room: room,
        batch: batch,
      );
    } catch (e) {
      debugPrint('Error parsing row: $e');
      return null;
    }
  }

  static Future<void> saveToFacultyProfile({
    required String facultyId,
    required List<FacultyExcelEntry> entries,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('faculty_profiles')
        .doc(facultyId);

    final snap = await docRef.get();
    final data = snap.data() ?? {};

    final currentAssigned = List<String>.from(data['assignedDivisions'] ?? []);
    final currentSubjects = Map<String, dynamic>.from(data['subjects'] ?? {});

    for (final e in entries) {
      if (!currentAssigned.contains(e.division)) {
        currentAssigned.add(e.division);
      }
      final divSubjects = List<String>.from(currentSubjects[e.division] ?? []);
      if (!divSubjects.contains(e.subject)) {
        divSubjects.add(e.subject);
      }
      currentSubjects[e.division] = divSubjects;
    }

    final excelList = entries.map((e) => e.toMap()).toList();

    await docRef.set({
      'assignedDivisions': currentAssigned,
      'subjects': currentSubjects,
      'excelSchedule': excelList,
      'lastExcelImport': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AppSettings.saveFacultyDetails(
      name: AppSettings.facultyName ?? '',
      email: AppSettings.facultyEmail ?? '',
      department: AppSettings.facultyDepartment ?? '',
      designation: AppSettings.facultyDesignation ?? '',
      cabin: AppSettings.facultyCabin ?? '',
      assignedDivisions: currentAssigned,
      id: facultyId,
    );
  }
}
