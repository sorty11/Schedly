import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../app_settings.dart';
import '../theme/theme.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import '../timetable_manager.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/skeleton_loader.dart';
import '../models/faculty_lecture_context.dart';
import 'package:file_picker/file_picker.dart';
import 'faculty_excel_import_service.dart';

class _FacultyConflictPair {
  final _FacultyTimetableEntry entryA;
  final _FacultyTimetableEntry entryB;

  _FacultyConflictPair({required this.entryA, required this.entryB});

  bool involvesDivision(String div) =>
      entryA.division == div || entryB.division == div;

  _FacultyTimetableEntry otherFor(String div) =>
      entryA.division == div ? entryB : entryA;

  _FacultyTimetableEntry currentFor(String div) =>
      entryA.division == div ? entryA : entryB;
}

class FacultyTimetablePage extends StatefulWidget {
  const FacultyTimetablePage({super.key});

  @override
  State<FacultyTimetablePage> createState() => _FacultyTimetablePageState();
}

class _FacultyTimetablePageState extends State<FacultyTimetablePage> {
  late String _selectedDay;
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  bool _hasConflict = false;
  List<_FacultyConflictPair> _currentConflicts = [];
  late Stream<List<_FacultyTimetableEntry>> _timetableStream;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('EEEE').format(DateTime.now());
    if (_days.contains(today)) {
      _selectedDay = today;
    } else {
      _selectedDay = 'Monday';
    }
    _timetableStream = _streamTimetable();
  }

  Stream<List<_FacultyTimetableEntry>> _streamTimetable() async* {
    try {
      final uid = AppSettings.facultyId;
      if (uid == null) {
        yield [];
        return;
      }

      final divisions = AppSettings.facultyAssignedDivisions ?? [];
      final profileSnap = await FirebaseFirestore.instance
          .collection('faculty_profiles')
          .doc(uid)
          .get();
      final subjectsMap =
          (profileSnap.data()?['subjects'] as Map<String, dynamic>?) ?? {};

      if (divisions.isEmpty) {
        yield [];
        return;
      }

      final streams = divisions.map((div) {
        final mySubjects = List<String>.from(subjectsMap[div] ?? []);
        if (mySubjects.isEmpty) return Stream.value(<_FacultyTimetableEntry>[]);

        return TimetableManager.streamEntriesForDay(
          division: div,
          day: _selectedDay,
        ).map((entries) {
          return entries
              .where((e) => mySubjects.contains(e.subjectCode))
              .map((e) => _FacultyTimetableEntry(division: div, entry: e))
              .toList();
        });
      }).toList();

      final excelList =
          (profileSnap.data()?['excelSchedule'] as List<dynamic>? ?? [])
              .map(
                (m) => FacultyExcelEntry.fromMap(Map<String, dynamic>.from(m)),
              )
              .where((e) => e.day.toLowerCase() == _selectedDay.toLowerCase())
              .map(
                (e) => _FacultyTimetableEntry(
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

        // Merge streamed division lectures and personal excel entries
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

        allLectures.sort(
          (a, b) => a.entry.startTime.compareTo(b.entry.startTime),
        );

        // Accurate Overlap & Partial Overlap Conflict Detection
        final detectedConflicts = <_FacultyConflictPair>[];
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
              detectedConflicts.add(_FacultyConflictPair(entryA: a, entryB: b));
            }
          }
        }

        Future.microtask(() {
          if (mounted) {
            setState(() {
              _hasConflict = detectedConflicts.isNotEmpty;
              _currentConflicts = detectedConflicts;
            });
          }
        });

        return allLectures;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading timetable: $e')));
      yield [];
    }
  }

  void _notifyCRsOfConflict() async {
    final uid = AppSettings.facultyId;
    final name = AppSettings.facultyName ?? 'Faculty';

    // Identify ALL affected sections in the detected conflict(s)
    final affectedDivisions = <String>{};
    for (final c in _currentConflicts) {
      affectedDivisions.add(c.entryA.division);
      affectedDivisions.add(c.entryB.division);
    }

    if (affectedDivisions.isEmpty) return;

    for (final div in affectedDivisions) {
      final divConflicts = _currentConflicts
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

      final Map<String, dynamic> crPayload = {
        'notificationId':
            'conflict_${DateTime.now().millisecondsSinceEpoch}_$div',
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

      try {
        await FirebaseFirestore.instance
            .collection('notification_outbox')
            .add(crPayload);
      } catch (outboxErr) {
        debugPrint('OUTBOX WARNING (non-fatal, conflict notify): $outboxErr');
      }
    }

    if (mounted) {
      final divNames = affectedDivisions
          .map((d) => d.replaceAll('_', ' '))
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CRs of affected section(s) ($divNames) notified.'),
        ),
      );
    }
  }

  Future<void> _importExcelTimetable() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );

    if (result == null ||
        result.files.isEmpty ||
        result.files.first.bytes == null) {
      return;
    }

    final file = result.files.first;
    try {
      final entries = FacultyExcelImportService.parseBytes(
        bytes: file.bytes!,
        fileName: file.name,
      );

      if (entries.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No timetable entries could be parsed from the file.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Faculty Timetable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${entries.length} scheduled lectures across sections.',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'This updates your personal faculty timetable without modifying student section timetables.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: entries
                        .take(8)
                        .map(
                          (e) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Text(
                              e.day.length >= 3 ? e.day.substring(0, 3) : e.day,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            title: Text(e.subject),
                            subtitle: Text(
                              '${e.division.replaceAll('_', ' ')} • ${_formatTime(e.startTime)}–${_formatTime(e.endTime)}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Import'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final uid = AppSettings.facultyId;
      if (uid != null) {
        await FacultyExcelImportService.saveToFacultyProfile(
          facultyId: uid,
          entries: entries,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${entries.length} lectures to faculty schedule.',
            ),
          ),
        );
        setState(() {
          _timetableStream = _streamTimetable();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to import timetable: $e')));
    }
  }

  String _formatTime(int minutesFromMidnight) {
    int hour = minutesFromMidnight ~/ 60;
    int minute = minutesFromMidnight % 60;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  int get _currentMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  bool _isToday() {
    return _selectedDay == DateFormat('EEEE').format(DateTime.now());
  }

  String _getNextClass(List<_FacultyTimetableEntry> lectures) {
    if (!_isToday() || lectures.isEmpty) return 'None';
    final current = _currentMinutes;
    for (final item in lectures) {
      if (item.entry.startTime > current) {
        return '${item.entry.displaySubject} at ${_formatTime(item.entry.startTime)}';
      }
    }
    return 'None';
  }

  Widget _buildSummaryCard(
    ColorScheme colorScheme,
    AppSemanticColors sem,
    List<_FacultyTimetableEntry> lectures,
  ) {
    return AnimatedCard(
      borderRadius: AppRadius.xl,
      backgroundColor: sem.surfaceElevated,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: sem.borderSubtle, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    title: 'Today\'s Classes',
                    value: lectures.length.toString(),
                    icon: Icons.class_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                Container(width: 1, height: 40, color: sem.borderSubtle),
                Expanded(
                  child: _buildSummaryMetric(
                    title: 'Assigned Divisions',
                    value: (AppSettings.facultyAssignedDivisions?.length ?? 0)
                        .toString(),
                    icon: Icons.groups_rounded,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            if (_isToday() && lectures.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(color: sem.borderSubtle, height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.next_plan_rounded,
                    size: 16,
                    color: sem.onSurfaceMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Next Class: ',
                    style: TextStyle(
                      color: sem.onSurfaceMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _getNextClass(lectures),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).extension<AppSemanticColors>()!.onSurfaceMuted,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x2l),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consolidated Timetable',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Viewing all your classes across assigned divisions',
                          style: TextStyle(color: sem.onSurfaceMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.tonalIcon(
                    onPressed: _importExcelTimetable,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Import Excel'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<_FacultyTimetableEntry>>(
                stream: _timetableStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: 4,
                      itemBuilder: (ctx, i) => SkeletonLoader(
                        width: double.infinity,
                        height: 120,
                        borderRadius: AppRadius.lg,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      ),
                    );
                  }

                  final _lectures = snapshot.data ?? [];

                  return Column(
                    children: [
                      // Summary Card
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2l,
                        ),
                        child: _buildSummaryCard(colorScheme, sem, _lectures),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Segmented Day Selector
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                          ),
                          itemCount: _days.length,
                          itemBuilder: (context, index) {
                            final day = _days[index];
                            final isSelected = day == _selectedDay;

                            return Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.md,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  if (!isSelected) {
                                    setState(() {
                                      _selectedDay = day;
                                      _timetableStream = _streamTimetable();
                                    });
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : sem.surfaceElevated,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : sem.borderSubtle,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    day.substring(0, 3),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : colorScheme.onSurface,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      if (_hasConflict)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.x2l,
                            AppSpacing.lg,
                            AppSpacing.x2l,
                            0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: sem.cancelled.withValues(alpha: 0.1),
                              border: Border.all(
                                color: sem.cancelled.withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: sem.cancelled,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    'Schedule Conflict Detected!',
                                    style: TextStyle(
                                      color: sem.cancelled,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _notifyCRsOfConflict,
                                  child: Text(
                                    'Notify CRs',
                                    style: TextStyle(color: sem.cancelled),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: AppSpacing.md),

                      // Lectures List
                      Expanded(
                        child: _lectures.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 64,
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Text(
                                      'No Classes Scheduled',
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'You have a free day on \$_selectedDay.',
                                      style: TextStyle(
                                        color: sem.onSurfaceMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.x2l,
                                  AppSpacing.sm,
                                  AppSpacing.x2l,
                                  AppSpacing.x4l,
                                ),
                                itemCount: _lectures.length,
                                itemBuilder: (context, index) {
                                  final item = _lectures[index];
                                  final divLabel = item.division
                                      .split('_')
                                      .last;

                                  final isLive =
                                      _isToday() &&
                                      item.entry.startTime <= _currentMinutes &&
                                      item.entry.endTime > _currentMinutes;

                                  return StaggeredListItem(
                                    index: index,
                                    child: AnimatedCard(
                                      borderRadius: AppRadius.lg,
                                      backgroundColor: isLive
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.05,
                                            )
                                          : sem.surfaceElevated,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: AppSpacing.md,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isLive
                                                ? colorScheme.primary
                                                : sem.borderSubtle,
                                            width: isLive ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.lg,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                            AppSpacing.lg,
                                          ),
                                          child: Row(
                                            children: [
                                              // Time Indicator
                                              Container(
                                                width: 80,
                                                padding: const EdgeInsets.all(
                                                  AppSpacing.md,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.md,
                                                      ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      _formatTime(
                                                        item.entry.startTime,
                                                      ),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            colorScheme.primary,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'to',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _formatTime(
                                                        item.entry.endTime,
                                                      ),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            colorScheme.primary,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.lg,
                                              ),
                                              // Lecture Details
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item
                                                                .entry
                                                                .displaySubject,
                                                            style:
                                                                GoogleFonts.outfit(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 18,
                                                                ),
                                                          ),
                                                        ),
                                                        if (isLive)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: colorScheme
                                                                  .primary,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    AppRadius
                                                                        .full,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              'LIVE',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                letterSpacing:
                                                                    0.5,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(
                                                      height: AppSpacing.sm,
                                                    ),
                                                    Wrap(
                                                      spacing: AppSpacing.md,
                                                      runSpacing: AppSpacing.xs,
                                                      children: [
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .class_rounded,
                                                              size: 14,
                                                              color: sem
                                                                  .onSurfaceMuted,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              'Div $divLabel',
                                                              style: TextStyle(
                                                                color: sem
                                                                    .onSurfaceMuted,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (item.entry.room !=
                                                                null &&
                                                            item
                                                                .entry
                                                                .room!
                                                                .isNotEmpty)
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .room_rounded,
                                                                size: 14,
                                                                color: sem
                                                                    .onSurfaceMuted,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                item
                                                                    .entry
                                                                    .room!,
                                                                style: TextStyle(
                                                                  color: sem
                                                                      .onSurfaceMuted,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                    if (isLive) ...[
                                                      const SizedBox(
                                                        height: AppSpacing.md,
                                                      ),
                                                      Text(
                                                        'Ends in ${item.entry.endTime - _currentMinutes} minutes',
                                                        style: TextStyle(
                                                          color: colorScheme
                                                              .primary,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
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
      ),
    );
  }
}

class _FacultyTimetableEntry {
  final String division;
  final TimetableEntry entry;

  _FacultyTimetableEntry({required this.division, required this.entry});
}
