import 'package:cloud_firestore/cloud_firestore.dart';
import 'period_config.dart';

class SectionConfig {
  final String id;
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

    return SectionConfig(
      id: id,
      academicYear: json['academicYear'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      division: json['division'] as String? ?? '',
      semester: json['semester'] as String?,
      active: json['active'] as bool? ?? true,
      workingDays: (json['workingDays'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      batches: (json['batches'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      batchNames: (json['batchNames'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)) ?? {},
      periods: (json['periods'] as List<dynamic>?)
              ?.map((e) => PeriodConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      semesterStartDate: parsedStartDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'academicYear': academicYear,
      'branch': branch,
      'division': division,
      if (semester != null) 'semester': semester,
      'active': active,
      'workingDays': workingDays,
      'batches': batches,
      'batchNames': batchNames,
      'periods': periods.map((p) => p.toJson()).toList(),
      if (semesterStartDate != null) 'semesterStartDate': semesterStartDate!.toIso8601String(),
    };
  }
  
  String getBatchName(String batchId) {
    return batchNames[batchId] ?? batchId;
  }
}
