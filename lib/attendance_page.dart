import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/attendance_record.dart';
import 'services/attendance_service.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'services/progress_calculator_service.dart';
import 'attendance_import_review_page.dart';
import 'models/attendance_import_models.dart';
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
  const AttendancePage({super.key, required this.division});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late Stream<List<AttendanceRecord>> _recordsStream;
  late Stream<List<AttendanceLog>> _logsStream;
  late Future<ProgressCalculatorService?> _calculatorFuture;

  @override
  void initState() {
    super.initState();
    _recordsStream = AttendanceService.streamAll(widget.division);
    _logsStream = AttendanceService.streamLogs();
    _calculatorFuture = ProgressCalculatorService.build(widget.division);
  }

  Future<void> _handlePdfImport() async {
    if (!mounted) return;
    await AppDialogs.showWarning(
      context: context,
      title: 'Import Official Attendance Report',
      message:
          'Attendance import is a Beta feature. Data comes from your uploaded institutional PDF — not verified by Schedly. Smart Attendance is separate and not affected.',
      resolution: 'Tap Continue to select your PDF, or Cancel to exit.',
    );
    if (!mounted) return;

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
        AppDialogs.showError(
          context: context,
          title: 'Error',
          message: 'Could not read file data.',
        );
        return;
      }

      if (!mounted) return;

      var parsePage = 0;
      var parseTotal = 0;
      var detectedRows = 0;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Parsing PDF…'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    parseTotal > 0
                        ? 'Page $parsePage / $parseTotal'
                        : 'Reading document…',
                  ),
                  if (detectedRows > 0) Text('$detectedRows records detected'),
                ],
              ),
            );
          },
        ),
      );

      final preview = await AttendanceParserService.parseForPreview(
        bytes: bytes,
        division: widget.division,
        onProgress:
            ({
              required currentPage,
              required totalPages,
              required rowsDetected,
              required message,
            }) {
              parsePage = currentPage;
              parseTotal = totalPages;
              detectedRows = rowsDetected;
            },
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (preview.isImageOnly ||
          (preview.errors.isNotEmpty && preview.logs.isEmpty)) {
        AppDialogs.showError(
          context: context,
          title: 'Import Failed',
          message: preview.errors.isNotEmpty
              ? preview.errors.join('\n')
              : 'Could not extract text from this PDF.',
        );
        return;
      }

      final importResult = await Navigator.push<AttendanceImportResult>(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceImportReviewPage(
            preview: preview,
            division: widget.division,
          ),
        ),
      );

      if (!mounted || importResult == null) return;

      final total = importResult.imported + importResult.updated;
      AppDialogs.showSnackBar(
        context: context,
        message:
            'Successfully imported $total records (${importResult.imported} new, ${importResult.updated} updated).',
      );
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        AppDialogs.showError(
          context: context,
          title: 'Import Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _undoImport() async {
    final confirm = await AppDialogs.showConfirm(
      context: context,
      title: 'Undo PDF Import',
      message:
          'This will delete all attendance records imported from official PDF reports. Manually marked attendance will not be affected.',
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
      final count = await AttendanceParserService.undoPdfImport(
        widget.division,
      );

      if (mounted) {
        Navigator.pop(context);
        AppDialogs.showSnackBar(
          context: context,
          message: 'Removed $count imported records.',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppDialogs.showError(
          context: context,
          title: 'Error',
          message: 'Could not undo import: $e',
        );
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x2l,
                  AppSpacing.lg,
                  AppSpacing.x2l,
                  0,
                ),
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
                subtitle:
                    'Please ask your CR to configure the semester start date in settings.',
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
                    final Map<String, List<AttendanceRecord>> rawGrouped = {};

                    // Clean and normalize component names to human-readable form
                    String normalizeComponent(String comp) {
                      final lower = comp.trim().toLowerCase();
                      if (lower.isEmpty ||
                          lower == 'lecture' ||
                          lower == 'theory') {
                        return 'Theory';
                      }
                      if (lower.contains('lab') ||
                          lower.contains('practical')) {
                        return 'Lab';
                      }
                      if (lower.contains('tutorial')) return 'Tutorial';
                      if (lower.contains('project')) return 'Project';
                      return comp.trim();
                    }

                    // 1. If logs exist, they are the ground truth for imported lectures
                    if (logs.isNotEmpty) {
                      // Deduplicate logs by stable lecture identity:
                      // For DSA: course + component + date + start/end
                      // For merged courses: course + date + start/end
                      final uniqueLogs = <String, AttendanceLog>{};
                      for (final log in logs) {
                        if (log.subjectCode.isEmpty) continue;
                        final key = log.deduplicationKey;
                        final existing = uniqueLogs[key];
                        if (existing == null ||
                            log.importedAt.isAfter(existing.importedAt)) {
                          uniqueLogs[key] = log;
                        }
                      }
                      final deduplicatedLogs = uniqueLogs.values.toList();

                      final compsBySubject = <String, Set<String>>{};
                      for (final log in deduplicatedLogs) {
                        final canonSubj = AttendanceLog.canonicalSubjectCode(
                          log.subjectCode,
                        );
                        compsBySubject
                            .putIfAbsent(canonSubj, () => {})
                            .add(normalizeComponent(log.component));
                      }

                      // Aggregate logs: ONLY DSA splits Theory and Lab.
                      // All other multi-component subjects merge into ONE card.
                      final aggregatedLogs =
                          <
                            String,
                            ({
                              String subjectCode,
                              String component,
                              int present,
                              int absent,
                              int cancelled,
                            })
                          >{};

                      for (final log in deduplicatedLogs) {
                        final canonSubj = AttendanceLog.canonicalSubjectCode(
                          log.subjectCode,
                        );
                        final isDsa = AttendanceLog.isDsa(canonSubj);
                        final normComp = normalizeComponent(log.component);
                        final hasMultiple =
                            (compsBySubject[canonSubj]?.length ?? 0) > 1;

                        final String groupKey;
                        final String displayComponent;

                        if (isDsa) {
                          groupKey = '${canonSubj}_$normComp';
                          displayComponent = normComp;
                        } else if (hasMultiple) {
                          groupKey = '${canonSubj}_Merged';
                          displayComponent = 'Merged';
                        } else {
                          groupKey = '${canonSubj}_$normComp';
                          displayComponent = normComp;
                        }

                        final cur =
                            aggregatedLogs[groupKey] ??
                            (
                              subjectCode: canonSubj,
                              component: displayComponent,
                              present: 0,
                              absent: 0,
                              cancelled: 0,
                            );

                        int p = cur.present;
                        int a = cur.absent;
                        if (log.status == 'present') {
                          p++;
                        } else if (log.status == 'absent') {
                          a++;
                        }

                        aggregatedLogs[groupKey] = (
                          subjectCode: canonSubj,
                          component: displayComponent,
                          present: p,
                          absent: a,
                          cancelled: cur.cancelled,
                        );
                      }

                      for (final entry in aggregatedLogs.entries) {
                        final val = entry.value;
                        final division = rawRecords.isNotEmpty
                            ? rawRecords.first.division
                            : widget.division;
                        final rec = AttendanceRecord(
                          id: '${division}_${val.subjectCode}_${val.component}',
                          division: division,
                          subjectCode: val.subjectCode,
                          component: val.component,
                          present: val.present,
                          absent: val.absent,
                          cancelled: val.cancelled,
                        );
                        records[entry.key] = rec;
                        rawGrouped[entry.key] = [rec];
                      }

                      // Include any subject that exists in rawRecords but not in logs
                      for (final r in rawRecords) {
                        final canonSubj = AttendanceLog.canonicalSubjectCode(
                          r.subjectCode,
                        );
                        final isDsa = AttendanceLog.isDsa(canonSubj);
                        final normComp = normalizeComponent(r.component);
                        final hasMultiple =
                            (compsBySubject[canonSubj]?.length ?? 0) > 1;
                        final groupKey = isDsa
                            ? '${canonSubj}_$normComp'
                            : (hasMultiple
                                  ? '${canonSubj}_Merged'
                                  : '${canonSubj}_$normComp');
                        if (!records.containsKey(groupKey)) {
                          records[groupKey] = r;
                          rawGrouped[groupKey] = [r];
                        }
                      }
                    } else {
                      // Fallback when no logs exist: aggregate directly from rawRecords
                      final compsBySubject = <String, Set<String>>{};
                      for (final r in rawRecords) {
                        compsBySubject
                            .putIfAbsent(r.subjectCode, () => {})
                            .add(normalizeComponent(r.component));
                      }

                      for (final r in rawRecords) {
                        final isDsa = AttendanceLog.isDsa(r.subjectCode);
                        final normComp = normalizeComponent(r.component);
                        final hasMultiple =
                            (compsBySubject[r.subjectCode]?.length ?? 0) > 1;

                        final String groupKey;
                        final String displayComponent;

                        if (isDsa) {
                          groupKey = '${r.subjectCode}_$normComp';
                          displayComponent = normComp;
                        } else if (hasMultiple || r.component == 'Merged') {
                          groupKey = '${r.subjectCode}_Merged';
                          displayComponent = 'Merged';
                        } else {
                          groupKey = '${r.subjectCode}_$normComp';
                          displayComponent = normComp;
                        }

                        if (records.containsKey(groupKey)) {
                          final existing = records[groupKey]!;
                          records[groupKey] = AttendanceRecord(
                            id: existing.id,
                            division: existing.division,
                            subjectCode: r.subjectCode,
                            component: displayComponent,
                            present: existing.present + r.present,
                            absent: existing.absent + r.absent,
                            cancelled: existing.cancelled + r.cancelled,
                          );
                        } else {
                          records[groupKey] = AttendanceRecord(
                            id: r.id,
                            division: r.division,
                            subjectCode: r.subjectCode,
                            component: displayComponent,
                            present: r.present,
                            absent: r.absent,
                            cancelled: r.cancelled,
                          );
                        }
                        rawGrouped.putIfAbsent(groupKey, () => []).add(r);
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
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
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
                                final uri = Uri.parse(
                                  'https://sdc-sppap1.svkm.ac.in:50001/irj/portal',
                                );
                                try {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
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
                              tooltip: 'Import Attendance PDF',
                              onPressed: _handlePdfImport,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.md),
                        ),

                        if (subjects.isEmpty &&
                            snapshot.connectionState != ConnectionState.waiting)
                          SliverFillRemaining(
                            child: FloatingEmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No subjects yet',
                              subtitle:
                                  'Subjects appear once the timetable is set up',
                            ),
                          ),

                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((context, i) {
                              final entry = subjects[i];
                              if (entry.record == null ||
                                  (entry.record!.present +
                                          entry.record!.absent ==
                                      0)) {
                                return const SizedBox.shrink();
                              }

                              return StaggeredListItem(
                                index: 2 + i,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: _SubjectAttendanceCard(
                                    entry: entry,
                                    division: widget.division,
                                    calculator: calculator,
                                  ),
                                ),
                              );
                            }, childCount: subjects.length),
                          ),
                        ),

                        // Recent Timeline
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.x2l,
                            AppSpacing.x3l,
                            AppSpacing.x2l,
                            AppSpacing.md,
                          ),
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
                              if (logsSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  logs.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.x2l,
                                  ),
                                  child: SkeletonShimmer(
                                    child: Column(
                                      children: List.generate(
                                        3,
                                        (i) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppSpacing.sm,
                                          ),
                                          child: SkeletonBlock(
                                            width: double.infinity,
                                            height: 60,
                                            borderRadius: AppRadius.lg,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (logs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.x2l,
                                  ),
                                  child: Text('No recent imported history.'),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.x2l,
                                ),
                                child: Column(
                                  children: logs
                                      .take(5)
                                      .map((log) => _TimelineLogCard(log: log))
                                      .toList(),
                                ),
                              );
                            },
                          ),
                        ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.x6l),
                        ),
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
    if (pct >= 0.80) return sem.warning; // Close to the edge (Yellow)
    return sem.cancelled; // Defaulter zone (Red)
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

    // Skip Bank Math based on fixed semester course hours from Course Details
    final int skipsLeft = calculator.getRemainingSkips(
      entry.subjectCode,
      entry.component,
      absent,
      requiredAttendance: 0.80,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? sem.surfaceElevated
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0),
        ),
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
                        Flexible(
                          child: Text(
                            entry.subjectCode,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : colorScheme.onSurface,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
              const SizedBox(width: AppSpacing.sm),
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
                backgroundColor: isDark
                    ? const Color(0xFF2A2A35)
                    : const Color(0xFFF0F0F5),
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

  const _SkipBadge({required this.skipsLeft});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    String msg;
    Color col;

    if (skipsLeft > 0) {
      msg = 'Can miss $skipsLeft more';
      col = sem.conducted;
    } else if (skipsLeft == 0) {
      msg = '0 skips left';
      col = sem.warning;
    } else {
      msg = 'Defaulter (Attend ${skipsLeft.abs()} more)';
      col = sem.cancelled;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
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
    final color = isPresent
        ? sem.conducted
        : (log.status == 'absent' ? sem.cancelled : sem.onSurfaceMuted);
    final icon = isPresent
        ? Icons.check_circle_rounded
        : (log.status == 'absent' ? Icons.cancel_rounded : Icons.help_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? sem.surfaceElevated
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0),
        ),
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
                  log.component == 'Theory'
                      ? log.subjectCode
                      : '${log.subjectCode} ${log.component}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${log.date.day}/${log.date.month}/${log.date.year}  ${TimetableManager.formatTime(log.startTime, log.endTime)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: sem.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          if (log.confidence != MatchConfidence.exact &&
              log.confidence != MatchConfidence.normalized)
            Icon(Icons.warning_amber_rounded, color: sem.warning, size: 16),
        ],
      ),
    );
  }
}
