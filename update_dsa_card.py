import re

def main():
    with open('lib/attendance_page.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update _SubjectEntry class
    subject_entry_old = """class _SubjectEntry {
  final String subjectCode;
  final String component;
  final AttendanceRecord? record;

  const _SubjectEntry({
    required this.subjectCode,
    required this.component,
    this.record,
  });
}"""

    subject_entry_new = """class _SubjectEntry {
  final String subjectCode;
  final String component;
  final AttendanceRecord? record;
  final List<AttendanceRecord> rawRecords;

  const _SubjectEntry({
    required this.subjectCode,
    required this.component,
    this.record,
    this.rawRecords = const [],
  });
}"""
    content = content.replace(subject_entry_old, subject_entry_new)

    # 2. Update grouping logic to keep rawRecords
    grouping_old = """            for (final r in rawRecords) {
              String subjectName = r.subjectCode;
              String componentName = r.component;
              
              // Force-normalize DSA variants
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
                if (records.containsKey(key)) {
                  final existing = records[key]!;
                  records[key] = AttendanceRecord(
                    id: existing.id,
                    division: existing.division,
                    subjectCode: subjectName,
                    component: 'Merged',
                    present: existing.present + r.present,
                    absent: existing.absent + r.absent,
                    cancelled: existing.cancelled + r.cancelled,
                  );
                } else {
                  records[key] = AttendanceRecord(
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
                if (normComponent.isEmpty || normComponent == 'Lecture') {
                  normComponent = 'Theory';
                } else if (normComponent == 'Practical') {
                  normComponent = 'Lab';
                }
                
                final key = '${subjectName}_$normComponent';
                if (records.containsKey(key)) {
                  final existing = records[key]!;
                  records[key] = AttendanceRecord(
                    id: existing.id,
                    division: existing.division,
                    subjectCode: existing.subjectCode,
                    component: normComponent,
                    present: existing.present + r.present,
                    absent: existing.absent + r.absent,
                    cancelled: existing.cancelled + r.cancelled,
                  );
                } else {
                  records[key] = AttendanceRecord(
                    id: r.id,
                    division: r.division,
                    subjectCode: r.subjectCode,
                    component: normComponent,
                    present: r.present,
                    absent: r.absent,
                    cancelled: r.cancelled,
                  );
                }
              }
            }

            final subjects = records.values.map((r) => _SubjectEntry(
              subjectCode: r.subjectCode,
              component: r.component,
              record: r,
            )).toList();"""

    grouping_new = """            final Map<String, List<AttendanceRecord>> rawGrouped = {};
            
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
                if (records.containsKey(key)) {
                  final existing = records[key]!;
                  records[key] = AttendanceRecord(
                    id: existing.id,
                    division: existing.division,
                    subjectCode: subjectName,
                    component: 'Merged',
                    present: existing.present + r.present,
                    absent: existing.absent + r.absent,
                    cancelled: existing.cancelled + r.cancelled,
                  );
                } else {
                  records[key] = AttendanceRecord(
                    id: r.id,
                    division: r.division,
                    subjectCode: subjectName,
                    component: 'Merged',
                    present: r.present,
                    absent: r.absent,
                    cancelled: r.cancelled,
                  );
                }
                rawGrouped.putIfAbsent(key, () => []).add(AttendanceRecord(
                  id: r.id, division: r.division, subjectCode: subjectName,
                  component: componentName, present: r.present, absent: r.absent, cancelled: r.cancelled
                ));
              } else {
                String normComponent = componentName;
                if (normComponent.isEmpty || normComponent == 'Lecture') normComponent = 'Theory';
                else if (normComponent == 'Practical') normComponent = 'Lab';
                
                final key = '${subjectName}_$normComponent';
                if (records.containsKey(key)) {
                  final existing = records[key]!;
                  records[key] = AttendanceRecord(
                    id: existing.id,
                    division: existing.division,
                    subjectCode: existing.subjectCode,
                    component: normComponent,
                    present: existing.present + r.present,
                    absent: existing.absent + r.absent,
                    cancelled: existing.cancelled + r.cancelled,
                  );
                } else {
                  records[key] = AttendanceRecord(
                    id: r.id,
                    division: r.division,
                    subjectCode: r.subjectCode,
                    component: normComponent,
                    present: r.present,
                    absent: r.absent,
                    cancelled: r.cancelled,
                  );
                }
                rawGrouped.putIfAbsent(key, () => []).add(AttendanceRecord(
                  id: r.id, division: r.division, subjectCode: r.subjectCode,
                  component: normComponent, present: r.present, absent: r.absent, cancelled: r.cancelled
                ));
              }
            }

            final subjects = records.entries.map((e) {
              final key = e.key;
              final r = e.value;
              return _SubjectEntry(
                subjectCode: r.subjectCode,
                component: r.component,
                record: r,
                rawRecords: rawGrouped[key] ?? [],
              );
            }).toList();"""
    content = content.replace(grouping_old, grouping_new)

    # 3. Add DSA to mergedSubjects
    merged_list_old = """final List<String> mergedSubjects = ['DM', 'Discrete Mathematics', 'PnS', 'SnS', 'Python', 'PROGRAMMING WITH PYTHON', 'Signals and Systems', 'Principles of Economics and Managemen'];"""
    merged_list_new = """final List<String> mergedSubjects = ['DSA', 'DATA STRUCTURES', 'DM', 'Discrete Mathematics', 'PnS', 'SnS', 'Python', 'PROGRAMMING WITH PYTHON', 'Signals and Systems', 'Principles of Economics and Managemen'];"""
    content = content.replace(merged_list_old, merged_list_new)

    # 4. Update _SubjectAttendanceCard UI to show splits
    card_ui_old = """              ),
              _SkipBadge(skipsLeft: skipsLeft),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Total: $total  •  Present: $present  •  Absent: $absent",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : sem.onSurfaceMuted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1000),
              curve: AppCurves.standard,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: isDark ? const Color(0xFF2A2A35) : const Color(0xFFF0F0F5),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }"""
    card_ui_new = """              ),
              if (entry.subjectCode != 'DSA') _SkipBadge(skipsLeft: skipsLeft),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          if (entry.subjectCode == 'DSA')
            Builder(
              builder: (context) {
                // Calculate independent theory and lab skips
                int theoryAbsent = 0;
                int labAbsent = 0;
                for (final r in entry.rawRecords) {
                  if (r.component.toLowerCase().contains('lab') || r.component.toLowerCase().contains('practical')) {
                    labAbsent += r.absent;
                  } else {
                    theoryAbsent += r.absent;
                  }
                }
                
                final int theoryTotal = calculator.getTotalProjectedHours('DSA', 'Theory');
                final int labTotal = calculator.getTotalProjectedHours('DSA', 'Lab');
                
                final int theoryMin = (theoryTotal * 0.8).ceil();
                final int labMin = (labTotal * 0.8).ceil();
                
                final int theorySkips = (theoryTotal - theoryMin) - theoryAbsent;
                final int labSkips = (labTotal - labMin) - labAbsent;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SkipBadge(
                          skipsLeft: theorySkips,
                          prefix: 'Theory: ',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SkipBadge(
                          skipsLeft: labSkips,
                          prefix: 'Lab: ',
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
            
          Text(
            "Total: $total  •  Present: $present  •  Absent: $absent",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : sem.onSurfaceMuted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1000),
              curve: AppCurves.standard,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: isDark ? const Color(0xFF2A2A35) : const Color(0xFFF0F0F5),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }"""
    content = content.replace(card_ui_old, card_ui_new)

    # 5. Update _SkipBadge class to accept optional prefix
    skip_badge_old = """class _SkipBadge extends StatelessWidget {
  final int skipsLeft;

  const _SkipBadge({required this.skipsLeft});"""
    skip_badge_new = """class _SkipBadge extends StatelessWidget {
  final int skipsLeft;
  final String prefix;

  const _SkipBadge({required this.skipsLeft, this.prefix = ''});"""
    content = content.replace(skip_badge_old, skip_badge_new)

    skip_badge_msg_old = """    if (skipsLeft > 0) {
      msg = 'Can miss $skipsLeft more';
      col = sem.conducted;
    } else if (skipsLeft == 0) {
      msg = '0 skips left';
      col = sem.warning;
    } else {
      msg = 'Defaulter (Attend ${skipsLeft.abs()} more)';
      col = sem.cancelled;
    }"""
    skip_badge_msg_new = """    if (skipsLeft > 0) {
      msg = '${prefix}Can miss $skipsLeft more';
      col = sem.conducted;
    } else if (skipsLeft == 0) {
      msg = '${prefix}0 skips left';
      col = sem.warning;
    } else {
      msg = '${prefix}Defaulter (Attend ${skipsLeft.abs()} more)';
      col = sem.cancelled;
    }"""
    content = content.replace(skip_badge_msg_old, skip_badge_msg_new)
    
    with open('lib/attendance_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
        
    print("attendance_page.dart modified successfully")

if __name__ == '__main__':
    main()
