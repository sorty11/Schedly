import 'period_config.dart';

class SectionConfig {
  final String id;
  final String academicYear;
  final String branch;
  final String division;
  final bool active;
  final List<String> workingDays;
  final List<String> batches;
  final List<PeriodConfig> periods;

  SectionConfig({
    required this.id,
    required this.academicYear,
    required this.branch,
    required this.division,
    this.active = true,
    required this.workingDays,
    required this.batches,
    required this.periods,
  });

  factory SectionConfig.fromJson(Map<String, dynamic> json, String id) {
    return SectionConfig(
      id: id,
      academicYear: json['academicYear'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      division: json['division'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      workingDays: (json['workingDays'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      batches: (json['batches'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      periods: (json['periods'] as List<dynamic>?)
              ?.map((e) => PeriodConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'academicYear': academicYear,
      'branch': branch,
      'division': division,
      'active': active,
      'workingDays': workingDays,
      'batches': batches,
      'periods': periods.map((p) => p.toJson()).toList(),
    };
  }
}
