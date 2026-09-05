import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/attendance_record.dart';
import 'models/attendance_subject_view_model.dart';
import 'services/attendance_service.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'services/progress_calculator_service.dart';
import 'attendance_import_review_page.dart';
import 'models/attendance_import_models.dart';
import 'services/attendance_parser.dart';
import 'services/attendance_status_mapper.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'widgets/animations/skeleton_components.dart';
import 'widgets/animations/counting_text.dart';
import 'package:file_picker/file_picker.dart';
import 'models/attendance_log.dart';
import 'widgets/app_dialogs.dart';
import 'onboarding/widgets/tutorial_target.dart';
import 'onboarding/services/feature_discovery_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FeatureDiscoveryService.checkAttendanceDiscovery(context);
    });
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
                    final Map<String, int> completedCounts = {};

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

                      // Aggregate logs: ONLY DSA splits Theory and Lab.
                      // All other subjects merge into ONE card with component 'Merged'.
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
                        final displayComponent =
                            AttendanceLog.canonicalComponent(
                              canonSubj,
                              log.component,
                            );
                        final groupKey = AttendanceLog.canonicalGroupKey(
                          canonSubj,
                          log.component,
                        );

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

                        if (AttendanceStatusMapper.countsAsCompletedOccurrence(log.status)) {
                          completedCounts[groupKey] = (completedCounts[groupKey] ?? 0) + 1;
                        }
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

                      // Include any subject that exists in rawRecords but NOT in logs
                      final subjectsInLogs = deduplicatedLogs
                          .map(
                            (l) => AttendanceLog.canonicalSubjectCode(
                              l.subjectCode,
                            ),
                          )
                          .toSet();

                      for (final r in rawRecords) {
                        final canonSubj = AttendanceLog.canonicalSubjectCode(
                          r.subjectCode,
                        );
                        // If subject is already covered by ground-truth logs, NEVER add duplicate from rawRecords!
                        if (subjectsInLogs.contains(canonSubj)) {
                          continue;
                        }

                        final displayComponent =
                            AttendanceLog.canonicalComponent(
                              canonSubj,
                              r.component,
                            );
                        final groupKey = AttendanceLog.canonicalGroupKey(
                          canonSubj,
                          r.component,
                        );

                        if (records.containsKey(groupKey)) {
                          final existing = records[groupKey]!;
                          if (r.total > existing.total) {
                            records[groupKey] = AttendanceRecord(
                              id: r.id,
                              division: r.division,
                              subjectCode: canonSubj,
                              component: displayComponent,
                              present: r.present,
                              absent: r.absent,
                              cancelled: r.cancelled,
                            );
                          }
                        } else {
                          records[groupKey] = AttendanceRecord(
                            id: r.id,
                            division: r.division,
                            subjectCode: canonSubj,
                            component: displayComponent,
                            present: r.present,
                            absent: r.absent,
                            cancelled: r.cancelled,
                          );
                          rawGrouped.putIfAbsent(groupKey, () => []).add(r);
                        }
                      }
                    } else {
                      // Fallback when no logs exist: aggregate directly from rawRecords
                      final recordsByGroup = <String, List<AttendanceRecord>>{};
                      for (final r in rawRecords) {
                        final canonSubj = AttendanceLog.canonicalSubjectCode(
                          r.subjectCode,
                        );
                        final groupKey = AttendanceLog.canonicalGroupKey(
                          canonSubj,
                          r.component,
                        );
                        recordsByGroup.putIfAbsent(groupKey, () => []).add(r);
                      }

                      for (final entry in recordsByGroup.entries) {
                        final groupKey = entry.key;
                        final recList = entry.value;
                        final first = recList.first;
                        final canonSubj = AttendanceLog.canonicalSubjectCode(
                          first.subjectCode,
                        );
                        final displayComponent =
                            AttendanceLog.canonicalComponent(
                              canonSubj,
                              first.component,
                            );

                        final distinctComponents = recList
                            .map(
                              (r) =>
                                  AttendanceLog.normalizeComponent(r.component),
                            )
                            .toSet();
                        final hasMerged =
                            distinctComponents.contains('Merged') ||
                            recList.any((r) => r.component == 'Merged');

                        int totalPresent = 0;
                        int totalAbsent = 0;
                        int totalCancelled = 0;

                        if (hasMerged || distinctComponents.length == 1) {
                          // Overlapping representations / snapshots of the same subject:
                          // Deduplicate by picking the most complete/latest snapshot
                          recList.sort((a, b) {
                            final cmp = b.total.compareTo(a.total);
                            if (cmp != 0) return cmp;
                            return b.updatedAt.compareTo(a.updatedAt);
                          });
                          final best = recList.first;
                          totalPresent = best.present;
                          totalAbsent = best.absent;
                          totalCancelled = best.cancelled;
                        } else {
                          // Genuinely distinct non-overlapping components (e.g. Theory + Lab for merged course):
                          for (final r in recList) {
                            totalPresent += r.present;
                            totalAbsent += r.absent;
                            totalCancelled += r.cancelled;
                          }
                        }

                        records[groupKey] = AttendanceRecord(
                          id: '${first.division}_${canonSubj}_$displayComponent',
                          division: first.division,
                          subjectCode: canonSubj,
                          component: displayComponent,
                          present: totalPresent,
                          absent: totalAbsent,
                          cancelled: totalCancelled,
                        );
                        rawGrouped[groupKey] = recList;
                      }
                    }

                    final subjects = records.entries.map((e) {
                      final key = e.key;
                      final r = e.value;
                      return AttendanceSubjectViewModel.fromRecord(
                        record: r,
                        calculator: calculator,
                        rawRecords: rawGrouped[key] ?? [],
                        completedOccurrences: completedCounts[key],
                      );
                    }).toList();

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          floating: true,
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          title: TutorialTarget(
                            id: 'attendance_page_header',
                            child: Text(
                              'My Attendance',
                              style: Theme.of(
                                context,
                              ).appBarTheme.titleTextStyle,
                            ),
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
                              final vm = subjects[i];
                              if (vm.total == 0) {
                                return const SizedBox.shrink();
                              }

                              return StaggeredListItem(
                                index: 2 + i,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: SubjectAttendanceCard(
                                    viewModel: vm,
                                    division: widget.division,
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
class SubjectAttendanceCard extends StatelessWidget {
  final AttendanceSubjectViewModel viewModel;
  final String division;

  const SubjectAttendanceCard({
    super.key,
    required this.viewModel,
    this.division = '',
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

    final present = viewModel.present;
    final absent = viewModel.absent;
    final total = viewModel.total;
    final pct = viewModel.percentage;
    final color = _color(context, pct);

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
          // Primary Row: Subject Title + Attendance %
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  viewModel.subjectCode,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : colorScheme.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Secondary Row: Component + Skip Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  viewModel.component,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : sem.onSurfaceMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SkipBadge(skipsLeft: viewModel.skipsLeft),
            ],
          ),
          if (viewModel.needsReview) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: sem.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: sem.warning.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: sem.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    viewModel.reviewMessage ?? 'Subject matching needs review',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sem.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

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
          const SizedBox(height: AppSpacing.md),
          _SemesterContextRow(
            assignedHoursLabel: viewModel.assignedHoursLabel,
            remainingLecturesLabel: viewModel.remainingLecturesLabel,
            isDark: isDark,
            borderSubtle: sem.borderSubtle,
            onSurfaceMuted: sem.onSurfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _SemesterContextRow extends StatelessWidget {
  final String assignedHoursLabel;
  final String remainingLecturesLabel;
  final bool isDark;
  final Color borderSubtle;
  final Color onSurfaceMuted;

  const _SemesterContextRow({
    required this.assignedHoursLabel,
    required this.remainingLecturesLabel,
    required this.isDark,
    required this.borderSubtle,
    required this.onSurfaceMuted,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.inter(
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white70 : onSurfaceMuted,
    );
    final iconColor = isDark ? Colors.white60 : onSurfaceMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 1,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF6F6FA),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark
              ? borderSubtle.withValues(alpha: 0.35)
              : const Color(0xFFECECF2),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 320;
          if (isWide) {
            return Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13.5, color: iconColor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          assignedHoursLabel,
                          style: textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  color: isDark
                      ? borderSubtle.withValues(alpha: 0.5)
                      : const Color(0xFFDFDFE8),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.event_note_rounded, size: 13.5, color: iconColor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          remainingLecturesLabel,
                          style: textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13.5, color: iconColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      assignedHoursLabel,
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.event_note_rounded, size: 13.5, color: iconColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      remainingLecturesLabel,
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
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
                  log.startTime != null && log.endTime != null
                      ? '${log.date.day}/${log.date.month}/${log.date.year}  ${TimetableManager.formatTime(log.startTime!, log.endTime!)}'
                      : '${log.date.day}/${log.date.month}/${log.date.year}',
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
