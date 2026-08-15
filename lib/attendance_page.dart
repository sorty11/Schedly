import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'user_roles.dart';

import 'models/attendance_record.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'services/attendance_service.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'services/progress_calculator_service.dart';
import 'services/attendance_parser.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'widgets/animations/skeleton_components.dart';
import 'widgets/animations/counting_text.dart';
import 'package:file_picker/file_picker.dart';
import 'models/attendance_log.dart';
import 'widgets/app_dialogs.dart';

class AttendancePage extends StatefulWidget {
  final String division;
  const AttendancePage({
    super.key,
    required this.division,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late Stream<List<AttendanceRecord>> _recordsStream;
  late Stream<List<AttendanceLog>> _logsStream;
  late Stream<QuerySnapshot> _lecturesStream;
  late Future<ProgressCalculatorService?> _calculatorFuture;
  late String currentDay;

  String _getCurrentDay() {
    final now = DateTime.now();
    switch (now.weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      default: return 'Monday'; // Default to Monday for weekends
    }
  }

  @override
  void initState() {
    super.initState();
    currentDay = _getCurrentDay();
    _recordsStream = AttendanceService.streamAll(widget.division);
    _logsStream = AttendanceService.streamLogs();
    _lecturesStream = FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(currentDay)
        .snapshots();
    _calculatorFuture = ProgressCalculatorService.build(widget.division);
  }

  Future<void> _handlePdfImport() async {
    // Show beta warning first
    if (!mounted) return;
    await AppDialogs.showWarning(
      context: context,
      title: 'Beta Feature Warning',
      message: 'PDF Import is currently in Beta. It may extract incorrect subjects (like "CE C" instead of the actual subject name). We recommend NOT using this feature until it is fully stable.',
      resolution: 'Tap Import to proceed anyway, or Cancel to exit.',
    );
    if (!mounted) return;
    final proceed = await AppDialogs.showConfirm(
      context: context,
      title: 'Proceed with Import?',
      message: 'This will attempt to parse your attendance PDF. Results may be inaccurate in Beta.',
      confirmText: 'Import Anyway',
      isDestructive: false,
    );

    if (!proceed) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (!mounted) return;
        AppDialogs.showError(context: context, title: 'Error', message: 'Could not read file data.');
        return;
      }

      if (!mounted) return;
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      await AttendanceParserService.parsePDFAndUpload(bytes, widget.division);

      if (!mounted) return;
      Navigator.pop(context); // hide loading
      AppDialogs.showSnackBar(context: context, message: 'Attendance imported successfully!');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // hide loading
        AppDialogs.showError(context: context, title: 'Import Failed', message: e.toString());
      }
    }
  }

  Future<void> _undoImport() async {
    final confirm = await AppDialogs.showConfirm(
      context: context,
      title: 'Undo PDF Import',
      message: 'This will delete all attendance records that were imported via PDF. Your manually marked attendance will not be affected.',
      confirmText: 'Undo Import',
      isDestructive: true,
    );

    if (!confirm) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final snap = await FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .collection('attendance_logs')
          .where('source', isEqualTo: 'pdf_import')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        AppDialogs.showSnackBar(context: context, message: 'Successfully undid PDF imports.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppDialogs.showError(context: context, title: 'Error', message: 'Could not undo import: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Attendance')),
        body: const Center(child: Text('Sign in to track attendance')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<ProgressCalculatorService?>(
          future: _calculatorFuture,
          builder: (context, calcSnap) {
            if (calcSnap.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.lg, AppSpacing.x2l, 0),
                children: [
                  SubjectCardSkeleton(),
                  SubjectCardSkeleton(),
                  SubjectCardSkeleton(),
                ],
              );
            }
            final calculator = calcSnap.data;
            if (calculator == null) {
              return const FloatingEmptyState(
                title: 'Setup Required',
                subtitle: 'Please ask your CR to configure the semester start date in settings.',
                icon: Icons.date_range,
              );
            }

            return StreamBuilder<List<AttendanceRecord>>(
              stream: _recordsStream,
              builder: (context, snapshot) {
                return StreamBuilder<List<AttendanceLog>>(
                  stream: _logsStream,
                  builder: (context, logsSnap) {
                    final rawRecords = snapshot.data ?? <AttendanceRecord>[];
                    final logs = logsSnap.data ?? <AttendanceLog>[];

            final Map<String, AttendanceRecord> records = {};
            final List<String> mergedSubjects = ['DSA', 'DATA STRUCTURES', 'DM', 'Discrete Mathematics', 'PnS', 'SnS', 'Python', 'PROGRAMMING WITH PYTHON', 'Signals and Systems', 'Principles of Economics and Managemen'];

            final Map<String, List<AttendanceRecord>> rawGrouped = {};
            
            for (final r in rawRecords) {
              String subjectName = r.subjectCode;
              String componentName = r.component;
              
              if (subjectName.toUpperCase().contains('DATA STRUCTURES') || subjectName.trim().toUpperCase() == 'DSA') {
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
            }).toList();



            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text(
                    'My Attendance',
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.public_rounded),
                      tooltip: 'Open SVKM Portal',
                      onPressed: () async {
                        final uri = Uri.parse('https://sdc-sppap1.svkm.ac.in:50001/irj/portal');
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          debugPrint('Could not launch $uri');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.undo_rounded),
                      tooltip: 'Undo PDF Import',
                      onPressed: _undoImport,
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      tooltip: 'Import PDF',
                      onPressed: _handlePdfImport,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),




                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

                _TodayLecturesSliver(
                  division: widget.division,
                  lecturesStream: _lecturesStream,
                  logsStream: _logsStream,
                  currentDay: currentDay,
                ),

                if (subjects.isEmpty && snapshot.connectionState != ConnectionState.waiting)
                  SliverFillRemaining(
                    child: FloatingEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No subjects yet',
                      subtitle: 'Subjects appear once the timetable is set up',
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final entry = subjects[i];
                          if (entry.record == null || (entry.record!.present + entry.record!.absent == 0)) {
                            return const SizedBox.shrink();
                          }

                          return StaggeredListItem(
                            index: 2 + i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: _SubjectAttendanceCard(
                                entry: entry,
                                division: widget.division,
                                calculator: calculator,
                              ),
                            ),
                          );
                        },
                        childCount: subjects.length,
                      ),
                    ),
                  ),

                // Recent Timeline
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.x3l, AppSpacing.x2l, AppSpacing.md),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      if (logsSnap.connectionState == ConnectionState.waiting && logs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                          child: SkeletonShimmer(
                            child: Column(
                              children: List.generate(3, (i) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: SkeletonBlock(
                                  width: double.infinity,
                                  height: 60,
                                  borderRadius: AppRadius.lg,
                                ),
                              )),
                            ),
                          ),
                        );
                      }
                      if (logs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                          child: Text('No recent imported history.'),
                        );
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                        child: Column(
                          children: logs.take(5).map((log) => _TimelineLogCard(log: log)).toList(),
                        ),
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x6l)),
              ],
            );
          },
        );
      },
    );
        },
      ),
  ),
);
  }
}

// -----------------------------------------------------------------------------
class _SubjectEntry {
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
}

// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
class _SubjectAttendanceCard extends StatelessWidget {
  final _SubjectEntry entry;
  final String division;
  final ProgressCalculatorService calculator;

  const _SubjectAttendanceCard({
    required this.entry,
    required this.division,
    required this.calculator,
  });

  Color _color(BuildContext context, double pct) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    if (pct >= 0.85) return sem.conducted; // Safe zone (Green)
    if (pct >= 0.80) return sem.warning;   // Close to the edge (Yellow)
    return sem.cancelled;                  // Defaulter zone (Red)
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final record = entry.record;
    final present = record?.present ?? 0;
    final absent = record?.absent ?? 0;
    final total = present + absent;
    final pct = total == 0 ? 0.0 : present / total;
    final color = _color(context, pct);

    // Skip Bank Math
    final int semesterTotal = calculator.getTotalProjectedHours(entry.subjectCode, entry.component);
    final int minRequiredPresent = (semesterTotal * 0.8).ceil();
    final int maxAllowedAbsencesForSemester = semesterTotal - minRequiredPresent;
    final int skipsLeft = maxAllowedAbsencesForSemester - absent;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0)),
        boxShadow: AppShadow.level1(colorScheme.primary, isDark: isDark),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          entry.subjectCode,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : colorScheme.onSurface,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.component,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : sem.onSurfaceMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
  }
}

class _SkipBadge extends StatelessWidget {
  final int skipsLeft;
  final String prefix;

  const _SkipBadge({required this.skipsLeft, this.prefix = ''});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    
    String msg;
    Color col;
    
    if (skipsLeft > 0) {
      msg = '${prefix}Can miss $skipsLeft more';
      col = sem.conducted;
    } else if (skipsLeft == 0) {
      msg = '${prefix}0 skips left';
      col = sem.warning;
    } else {
      msg = '${prefix}Defaulter (Attend ${skipsLeft.abs()} more)';
      col = sem.cancelled;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Text(
        msg, 
        style: GoogleFonts.inter(
          fontSize: 11, 
          fontWeight: FontWeight.w700, 
          color: col,
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
class _TimelineLogCard extends StatelessWidget {
  final AttendanceLog log;

  const _TimelineLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isPresent = log.status == 'present';
    final color = isPresent ? sem.conducted : (log.status == 'absent' ? sem.cancelled : sem.onSurfaceMuted);
    final icon = isPresent ? Icons.check_circle_rounded : (log.status == 'absent' ? Icons.cancel_rounded : Icons.help_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.component == 'Theory' ? log.subjectCode : '${log.subjectCode} ${log.component}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${log.date.day}/${log.date.month}/${log.date.year}  ${TimetableManager.formatTime(log.startTime, log.endTime)}',
                  style: GoogleFonts.inter(fontSize: 11, color: sem.onSurfaceMuted),
                ),
              ],
            ),
          ),
          if (log.confidence != MatchConfidence.exact && log.confidence != MatchConfidence.normalized)
            Icon(Icons.warning_amber_rounded, color: sem.warning, size: 16),
        ],
      ),
    );
  }
}

class _TodayLecturesSliver extends StatelessWidget {
  final String division;
  final Stream<QuerySnapshot> lecturesStream;
  final Stream<List<AttendanceLog>> logsStream;
  final String currentDay;

  const _TodayLecturesSliver({
    required this.division,
    required this.lecturesStream,
    required this.logsStream,
    required this.currentDay,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: lecturesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverToBoxAdapter(child: SizedBox.shrink());
        
        final rawLectures = snapshot.data!.docs
            .map((doc) => TimetableEntry.fromFirestore(doc))
            .where((e) {
              if (AppSettings.currentRole == UserRole.student) {
                return e.shouldIncludeForUserBatch(AppSettings.studentBatch);
              }
              return true;
            })
            .toList();

        if (rawLectures.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        // Sort by start time
        rawLectures.sort((a, b) => a.startTime.compareTo(b.startTime));

        return StreamBuilder<List<AttendanceLog>>(
          stream: logsStream,
          builder: (context, logsSnap) {
            final logs = logsSnap.data ?? [];
            final now = DateTime.now();
            final todayLogs = logs.where((l) => 
                l.date.year == now.year && 
                l.date.month == now.month && 
                l.date.day == now.day &&
                l.source == 'manual'
            ).toList();

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          'Today\'s Lectures',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                    
                    final entry = rawLectures[index - 1];
                    final logForEntry = todayLogs.firstWhere(
                      (l) => l.timetableEntryId == entry.id || (l.startTime == entry.startTime && l.subjectCode == entry.subjectCode),
                      orElse: () => AttendanceLog(
                        id: '', subjectCode: '', component: '', rawSubjectText: '', 
                        date: now, startTime: 0, endTime: 0, status: '', source: '', confidence: MatchConfidence.unknown, importedAt: now,
                      ),
                    );

                    final isMarked = logForEntry.id.isNotEmpty;
                    final status = logForEntry.status;

                    return AnimatedCard(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      borderRadius: AppRadius.xl,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.subjectCode,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  TimetableManager.formatTime(entry.startTime, entry.endTime),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    _StatusButton(
                                      label: 'Present',
                                      icon: Icons.check_circle_outline,
                                      color: Colors.green,
                                      isSelected: isMarked && (status == 'present' || status == 'P'),
                                      onTap: () => _markLog(entry, 'present'),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusButton(
                                      label: 'Absent',
                                      icon: Icons.cancel_outlined,
                                      color: Colors.red,
                                      isSelected: isMarked && (status == 'absent' || status == 'A'),
                                      onTap: () => _markLog(entry, 'absent'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _StatusButton(
                                      label: 'Cancelled',
                                      icon: Icons.block,
                                      color: Colors.orange,
                                      isSelected: isMarked && status == 'cancelled',
                                      onTap: () => _markLog(entry, 'cancelled'),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusButton(
                                      label: 'Not Mine',
                                      icon: Icons.not_interested,
                                      color: Colors.grey,
                                      isSelected: isMarked && status == 'not_mine',
                                      onTap: () => _markLog(entry, 'not_mine'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: rawLectures.length + 1,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markLog(TimetableEntry entry, String status) async {
    final now = DateTime.now();
    final dateStr = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
    final instanceId = '${entry.subjectCode}_${entry.component}_${dateStr}_${entry.startTime}_${entry.endTime}'.replaceAll(RegExp(r'\s+'), '_');

    await AttendanceService.markLog(
      subjectCode: entry.subjectCode,
      component: entry.component,
      date: now,
      startTime: entry.startTime,
      endTime: entry.endTime,
      status: status,
      entryId: entry.id,
    );

    // Update the aggregate record
    await AttendanceService.mark(
      division: division,
      subjectCode: entry.subjectCode,
      component: entry.component,
      instanceId: instanceId,
      markType: (status == 'present' || status == 'absent') ? status : null,
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? color : Theme.of(context).dividerColor,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isSelected ? color : Theme.of(context).iconTheme.color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? color : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

