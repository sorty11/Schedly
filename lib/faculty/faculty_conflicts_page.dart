import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:intl/intl.dart';

import '../theme/theme.dart';
import '../app_settings.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import '../timetable_manager.dart';
import '../services/timetable_resolver_service.dart';
import 'faculty_excel_import_service.dart';
import 'faculty_sr_connection_service.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/floating_empty_state.dart';
import '../widgets/app_dialogs.dart';

class FacultyConflictsPage extends StatefulWidget {
  const FacultyConflictsPage({super.key});

  @override
  State<FacultyConflictsPage> createState() => _FacultyConflictsPageState();
}

class _FacultyConflictsPageState extends State<FacultyConflictsPage> {
  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  String _selectedDay = 'Monday';
  bool _isNotifying = false;
  static DateTime? _lastConflictNotifiedTime;

  @override
  void initState() {
    super.initState();
    final todayName = DateFormat('EEEE').format(DateTime.now());
    if (_days.contains(todayName)) {
      _selectedDay = todayName;
    }
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  DateTime _getTargetDateForDay(String dayName) {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final targetWeekday = _days.indexOf(dayName) + 1;
    if (targetWeekday < 1 || targetWeekday > 7) return now;
    final diff = targetWeekday - currentWeekday;
    return now.add(Duration(days: diff));
  }

  Stream<List<_ConflictPair>> _streamConflicts() async* {
    final uid = AppSettings.facultyId;
    final divisions = AppSettings.facultyAssignedDivisions ?? [];
    if (uid == null || divisions.isEmpty) {
      yield [];
      return;
    }

    final profileSnap = await FirebaseFirestore.instance
        .collection('faculty_profiles')
        .doc(uid)
        .get();
    final subjectsMap = FacultySrConnectionService.parseSubjectsMap(
      profileSnap.data()?['subjects'],
    );

    final targetDate = _getTargetDateForDay(_selectedDay);
    final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    final streams = divisions.map((div) {
      final mySubjects = FacultySrConnectionService.getSubjectsForDivision(
        subjectsMap,
        div,
      );
      if (mySubjects.isEmpty) return Stream.value(<_FacultyLecture>[]);

      return TimetableManager.streamEntriesForDay(
        division: div,
        day: _selectedDay,
      ).map((entries) {
        final resolved = TimetableResolverService.resolve(
          rawEntries: entries,
          targetDateStr: targetDateStr,
        );

        if (resolved.isHoliday) {
          return <_FacultyLecture>[];
        }

        return resolved.lectures
            .where((e) => mySubjects.contains(e.subjectCode) && e.isActive)
            .map((e) => _FacultyLecture(division: div, entry: e))
            .toList();
      });
    }).toList();

    final excelList =
        (profileSnap.data()?['excelSchedule'] as List<dynamic>? ?? [])
            .map((m) => FacultyExcelEntry.fromMap(Map<String, dynamic>.from(m)))
            .where((e) => e.day.toLowerCase() == _selectedDay.toLowerCase())
            .map(
              (e) => _FacultyLecture(
                division: e.division,
                entry: TimetableEntry(
                  id: 'excel_${e.division}_${e.startTime}',
                  subject: e.subject,
                  category: EventCategory.academic,
                  batch: e.batch ?? 'Whole Class',
                  startTime: e.startTime,
                  endTime: e.endTime,
                  durationMinutes: e.endTime - e.startTime,
                  room: e.room,
                  facultyId: uid,
                ),
              ),
            )
            .toList();

    yield* CombineLatestStream.list(streams).map((listOfLists) {
      final streamedLectures = listOfLists.expand((l) => l).toList();
      final allLectures = [...streamedLectures];

      for (final xl in excelList) {
        final exists = allLectures.any(
          (l) =>
              l.division == xl.division &&
              l.entry.subjectCode == xl.entry.subjectCode &&
              l.entry.startTime == xl.entry.startTime,
        );
        if (!exists) {
          allLectures.add(xl);
        }
      }

      final conflicts = <_ConflictPair>[];
      for (int i = 0; i < allLectures.length; i++) {
        for (int j = i + 1; j < allLectures.length; j++) {
          final a = allLectures[i];
          final b = allLectures[j];

          if (a.entry.isCancelled ||
              b.entry.isCancelled ||
              a.entry.isHoliday ||
              b.entry.isHoliday) {
            continue;
          }

          final isDifferentAssignment =
              a.division != b.division ||
              (a.entry.id != b.entry.id && a.entry.batch != b.entry.batch);

          if (!isDifferentAssignment) continue;

          // Two intervals [startA, endA) and [startB, endB) overlap if startA < endB and startB < endA
          final hasOverlap =
              a.entry.startTime < b.entry.endTime &&
              b.entry.startTime < a.entry.endTime;

          if (hasOverlap) {
            conflicts.add(_ConflictPair(lectureA: a, lectureB: b));
          }
        }
      }

      return conflicts;
    });
  }

  Future<void> _notifyCRs(List<_ConflictPair> conflicts) async {
    if (conflicts.isEmpty) return;

    // Deduplication check: prevent spamming notifications within 60s
    if (_lastConflictNotifiedTime != null &&
        DateTime.now().difference(_lastConflictNotifiedTime!) <
            const Duration(seconds: 60)) {
      AppDialogs.showSnackBar(
        context: context,
        message: 'CRs were already notified recently. Please wait a moment.',
      );
      return;
    }

    setState(() => _isNotifying = true);

    try {
      final uid = AppSettings.facultyId;
      final name = AppSettings.facultyName ?? 'Faculty';

      // Identify ALL affected sections in the detected conflict(s)
      final affectedDivisions = <String>{};
      for (final c in conflicts) {
        affectedDivisions.add(c.lectureA.division);
        affectedDivisions.add(c.lectureB.division);
      }

      for (final div in affectedDivisions) {
        final divConflicts = conflicts
            .where((c) => c.involvesDivision(div))
            .toList();

        final conflictDetails = divConflicts
            .map((c) {
              final myLec = c.currentFor(div);
              final otherLec = c.otherFor(div);
              return '${myLec.entry.subjectCode} (${_formatTime(myLec.entry.startTime)}–${_formatTime(myLec.entry.endTime)}) with Section ${otherLec.division.replaceAll('_', ' ')} (${otherLec.entry.subjectCode} at ${_formatTime(otherLec.entry.startTime)}–${_formatTime(otherLec.entry.endTime)})';
            })
            .join('; ');

        final message =
            'Timetable conflict detected on $_selectedDay: You are scheduled with Prof. $name at overlapping time ($conflictDetails).';

        final deterministicNotifId =
            'conflict_${DateFormat('yyyyMMdd').format(DateTime.now())}_${div}_${uid ?? 'fac'}';

        final Map<String, dynamic> crPayload = {
          'notificationId': deterministicNotifId,
          'type': 'faculty_conflict',
          'title': 'Schedule Conflict: Prof. $name',
          'body': message,
          'division': div,
          'role': 'cr',
          'uid': uid ?? '',
          'priority': 'high',
          'deepLink': '/cr_dashboard',
          'processed': false,
          'attempts': 0,
          'nextRetryAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('notification_outbox')
            .doc(deterministicNotifId)
            .set(crPayload);
      }

      _lastConflictNotifiedTime = DateTime.now();

      if (mounted) {
        final divNames = affectedDivisions
            .map((d) => d.replaceAll('_', ' '))
            .join(', ');
        AppDialogs.showSnackBar(
          context: context,
          message: 'CRs of affected section(s) ($divNames) notified.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(
          context: context,
          title: 'Notification Failed',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isNotifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Timetable Conflicts',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          // Day selector chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _days.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final day = _days[index];
                final isSelected = day == _selectedDay;

                return ChoiceChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDay = day);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: StreamBuilder<List<_ConflictPair>>(
              stream: _streamConflicts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final conflicts = snapshot.data ?? [];
                if (conflicts.isEmpty) {
                  return FloatingEmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'No Conflicts on $_selectedDay',
                    subtitle:
                        'All scheduled classes on $_selectedDay are conflict-free.',
                  );
                }

                return Column(
                  children: [
                    // Warning banner
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: sem.cancelled.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: sem.cancelled.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: sem.cancelled,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${conflicts.length} Overlapping Schedule Conflict${conflicts.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: sem.cancelled,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'You are scheduled in multiple sections at overlapping times.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: sem.onSurfaceMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _isNotifying
                                ? null
                                : () => _notifyCRs(conflicts),
                            style: FilledButton.styleFrom(
                              backgroundColor: sem.cancelled,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                            ),
                            icon: _isNotifying
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Notify CRs'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: conflicts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final c = conflicts[index];

                          return StaggeredListItem(
                            index: index,
                            child: AnimatedCard(
                              borderRadius: AppRadius.xl,
                              backgroundColor: sem.surfaceElevated,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xl,
                                  ),
                                  border: Border.all(
                                    color: sem.cancelled.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: AppSpacing.xs,
                                          ),
                                          decoration: BoxDecoration(
                                            color: sem.cancelled.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.sm,
                                            ),
                                          ),
                                          child: Text(
                                            'CONFLICT #${index + 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: sem.cancelled,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _selectedDay,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: sem.onSurfaceMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    // Lecture A
                                    _buildLectureRow(
                                      label: 'Class 1',
                                      lecture: c.lectureA,
                                      colorScheme: colorScheme,
                                      sem: sem,
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.sm,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(child: Divider()),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: AppSpacing.sm,
                                            ),
                                            child: Text(
                                              'OVERLAPS WITH',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                          Expanded(child: Divider()),
                                        ],
                                      ),
                                    ),
                                    // Lecture B
                                    _buildLectureRow(
                                      label: 'Class 2',
                                      lecture: c.lectureB,
                                      colorScheme: colorScheme,
                                      sem: sem,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLectureRow({
    required String label,
    required _FacultyLecture lecture,
    required ColorScheme colorScheme,
    required AppSemanticColors sem,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.domain_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${lecture.entry.subjectCode} • Section ${lecture.division.replaceAll('_', ' ')}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatTime(lecture.entry.startTime)} - ${_formatTime(lecture.entry.endTime)}${lecture.entry.room != null && lecture.entry.room!.isNotEmpty ? ' • Room ${lecture.entry.room}' : ''}',
                style: TextStyle(fontSize: 12, color: sem.onSurfaceMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FacultyLecture {
  final String division;
  final TimetableEntry entry;

  _FacultyLecture({required this.division, required this.entry});
}

class _ConflictPair {
  final _FacultyLecture lectureA;
  final _FacultyLecture lectureB;

  _ConflictPair({required this.lectureA, required this.lectureB});

  bool involvesDivision(String div) =>
      lectureA.division == div || lectureB.division == div;

  _FacultyLecture currentFor(String div) =>
      lectureA.division == div ? lectureA : lectureB;

  _FacultyLecture otherFor(String div) =>
      lectureA.division == div ? lectureB : lectureA;
}
