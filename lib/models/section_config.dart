import 'package:cloud_firestore/cloud_firestore.dart';
import 'period_config.dart';

class SectionConfig {
  final String id;
  final String school;
  final String? program;
  final String academicYear;
  final String branch;
  final String division;
  final String? semester;
  final bool active;
  final List<String> workingDays;
  final List<String> batches;
  final Map<String, String> batchNames;
  final List<PeriodConfig> periods;
  final DateTime? semesterStartDate;

  SectionConfig({
    required this.id,
    this.school = 'STME',
    this.program,
    required this.academicYear,
    required this.branch,
    required this.division,
    this.semester,
    this.active = true,
    required this.workingDays,
    required this.batches,
    this.batchNames = const {},
    required this.periods,
    this.semesterStartDate,
  });

  factory SectionConfig.fromJson(Map<String, dynamic> json, String id) {
    DateTime? parsedStartDate;
    final startData = json['semesterStartDate'];
    if (startData != null) {
      if (startData is Timestamp) {
        parsedStartDate = startData.toDate();
      } else if (startData is String) {
        parsedStartDate = DateTime.tryParse(startData);
      } else if (startData is int) {
        parsedStartDate = DateTime.fromMillisecondsSinceEpoch(startData);
      }
    }

    final branch = json['branch'] as String? ?? '';
    final program = json['program'] as String? ?? (branch.isNotEmpty ? branch : null);
    final school = json['school'] as String? ?? 'STME';

    return SectionConfig(
      id: id,
      school: school,
      program: program,
      academicYear: json['academicYear'] as String? ?? '',
      branch: branch,
      division: json['division'] as String? ?? '',
      semester: json['semester'] as String?,
      active: json['active'] as bool? ?? true,
      workingDays:
          (json['workingDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      batches:
          (json['batches'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      batchNames:
          (json['batchNames'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          {},
      periods:
          (json['periods'] as List<dynamic>?)
              ?.map((e) => PeriodConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      semesterStartDate: parsedStartDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school': school,
      if (program != null) 'program': program,
      'academicYear': academicYear,
      'branch': branch,
      'division': division,
      if (semester != null) 'semester': semester,
      'active': active,
      'workingDays': workingDays,
      'batches': batches,
      'batchNames': batchNames,
      'periods': periods.map((p) => p.toJson()).toList(),
      if (semesterStartDate != null)
        'semesterStartDate': semesterStartDate!.toIso8601String(),
    };
  }

  String getBatchName(String batchId) {
    return batchNames[batchId] ?? batchId;
  }
}
