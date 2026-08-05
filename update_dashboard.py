import re

def main():
    with open('lib/dashboard_page.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add imports
    imports = """import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedly/services/sync_service.dart';
import 'package:schedly/services/attendance_service.dart';
import 'package:schedly/models/attendance_record.dart';"""
    content = content.replace("import 'package:shared_preferences/shared_preferences.dart';", imports)

    # 2. Add properties
    props = """  Map<String, String> _batchNames = {};
  late Future<ProgressCalculatorService?> _calculatorFuture;
  late Stream<List<AttendanceRecord>> _recordsStream;"""
    content = content.replace("  Map<String, String> _batchNames = {};\n  late Future<ProgressCalculatorService?> _calculatorFuture;", props)

    # 3. Init state stream
    initState = """    _lecturesStream = FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(currentDay)
        .snapshots();
    _recordsStream = AttendanceService.streamAll(widget.division);"""
    content = content.replace("""    _lecturesStream = FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(currentDay)
        .snapshots();""", initState)

    # 4. Wrap build body with StreamBuilder
    build_start = """    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _lecturesStream,
          builder: (context, snapshot) {"""
    
    build_start_replacement = """    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<AttendanceRecord>>(
          stream: _recordsStream,
          builder: (context, recordsSnap) {
            final rawRecords = recordsSnap.data ?? [];
            final Map<String, AttendanceRecord> attendanceRecords = {};
            
            final List<String> mergedSubjects = ['DM', 'Discrete Mathematics', 'PnS', 'SnS', 'Python', 'PROGRAMMING WITH PYTHON', 'Signals and Systems', 'Principles of Economics and Managemen'];
            
            for (final r in rawRecords) {
              String subjectName = r.subjectCode;
              String componentName = r.component;
              
              if (subjectName.toUpperCase().contains('DATA STRUCTURES') || subjectName == 'DSA') {
                subjectName = 'DSA';
                if (componentName.toUpperCase().contains('LAB') || componentName.toUpperCase().contains('PRACTICAL')) {
                  componentName = 'Lab';
                } else {
                  componentName = 'Theory';
                }
              }

              if (mergedSubjects.contains(subjectName)) {
                final key = '${subjectName}_Merged';
                if (attendanceRecords.containsKey(key)) {
                  final existing = attendanceRecords[key]!;
                  attendanceRecords[key] = AttendanceRecord(
                    id: existing.id,
                    division: existing.division,
                    subjectCode: subjectName,
                    component: 'Merged',
                    present: existing.present + r.present,
                    absent: existing.absent + r.absent,
                    cancelled: existing.cancelled + r.cancelled,
                  );
                } else {
                  attendanceRecords[key] = AttendanceRecord(
                    id: r.id,
                    division: r.division,
                    subjectCode: subjectName,
                    component: 'Merged',
                    present: r.present,
                    absent: r.absent,
                    cancelled: r.cancelled,
                  );
                }
              } else {
                String normComponent = componentName;
                if (normComponent.isEmpty || normComponent == 'Lecture') normComponent = 'Theory';
                else if (normComponent == 'Practical') normComponent = 'Lab';
                
                attendanceRecords['${subjectName}_$normComponent'] = r;
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _lecturesStream,
              builder: (context, snapshot) {"""
    content = content.replace(build_start, build_start_replacement)

    # 5. Add two closing braces at the end of build body
    build_end = """                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.x6l),
                ),
              ],
            );
          },
        ),
      ),
    );
  }"""
    build_end_replacement = """                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.x6l),
                ),
              ],
            );
          },
        );
          },
        ),
      ),
    );
  }"""
    content = content.replace(build_end, build_end_replacement)

    # 6. Update TimelineLectureItem params
    item_params = """  final bool isLast;
  final bool Function(TimetableEntry) canEdit;
  final void Function(TimetableEntry) onEdit;
  final Map<String, String>? batchNames;
  final Map<String, AttendanceRecord>? attendanceRecords;

  const _TimelineLectureItem({
    required this.entries,
    required this.isCurrent,
    required this.isNext,
    required this.isLast,
    required this.canEdit,
    required this.onEdit,
    this.batchNames,
    this.attendanceRecords,
  });"""
    content = content.replace("""  final bool isLast;
  final bool Function(TimetableEntry) canEdit;
  final void Function(TimetableEntry) onEdit;

  const _TimelineLectureItem({
    required this.entries,
    required this.isCurrent,
    required this.isNext,
    required this.isLast,
    required this.canEdit,
    required this.onEdit,
  });""", item_params)

    # 7. Pass attendanceRecords from sliver list
    item_call = """                            child: _TimelineLectureItem(
                              entries: entries,
                              isCurrent: isCurrent,
                              isNext: isNext,
                              isLast: isLast,
                              canEdit: _canEditLecture,
                              onEdit: _editLecture,
                              attendanceRecords: attendanceRecords,
                            ),"""
    content = content.replace("""                            child: _TimelineLectureItem(
                              entries: entries,
                              isCurrent: isCurrent,
                              isNext: isNext,
                              isLast: isLast,
                              canEdit: _canEditLecture,
                              onEdit: _editLecture,
                            ),""", item_call)

    with open('lib/dashboard_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
