import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_settings.dart';
import 'models/batch_analytics.dart';
import 'models/attendance_record.dart';
import 'models/timetable_entry.dart';
import 'services/attendance_service.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'widgets/animations/counting_text.dart';
import 'package:file_picker/file_picker.dart';
import 'services/pdf_attendance_import_service.dart';
import 'pdf_attendance_preview_page.dart';
import 'models/attendance_log.dart';
import 'widgets/app_dialogs.dart';

class AttendancePage extends StatefulWidget {
  final String division;
  final List<SubjectAnalytics> allAnalytics;

  const AttendancePage({
    super.key,
    required this.division,
    required this.allAnalytics,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late Future<List<TimetableEntry>> _todayLecturesFuture;

  @override
  void initState() {
    super.initState();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final today = days[DateTime.now().weekday - 1];
    _todayLecturesFuture = TimetableManager.getEntriesForDay(division: widget.division, day: today);
  }

  Future<void> _handlePdfImport() async {
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

      final logs = await PdfAttendanceImportService.parseAttendancePdf(
        pdfBytes: bytes,
        division: widget.division,
        analytics: widget.allAnalytics,
      );

      if (!mounted) return;
      Navigator.pop(context); // hide loading

      if (logs.isEmpty) {
        AppDialogs.showError(context: context, title: 'No Data', message: 'Could not find any readable attendance logs in this PDF.');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfAttendancePreviewPage(logs: logs, division: widget.division),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // hide loading
        AppDialogs.showError(context: context, title: 'Import Failed', message: e.toString());
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
        child: StreamBuilder<List<AttendanceRecord>>(
          stream: AttendanceService.streamAll(widget.division),
          builder: (context, snapshot) {
            final Map<String, AttendanceRecord> records = {
              for (final r in snapshot.data ?? <AttendanceRecord>[])
                '${r.subjectCode}_${r.component}': r,
            };

            // Build one entry per unique subject+component from analytics
            final subjects = <_SubjectEntry>[];
            for (final sa in widget.allAnalytics) {
              final byComponent = <String, List<BatchAnalytics>>{};
              for (final b in sa.batches) {
                byComponent.putIfAbsent(b.component, () => []).add(b);
              }
              if (byComponent.isEmpty) {
                subjects.add(_SubjectEntry(
                  subjectCode: sa.subject,
                  component: 'Theory',
                  record: records['${sa.subject}_Theory'],
                ));
              } else {
                for (final comp in byComponent.keys) {
                  subjects.add(_SubjectEntry(
                    subjectCode: sa.subject,
                    component: comp,
                    record: records['${sa.subject}_$comp'],
                  ));
                }
              }
            }

            // Overall %
            int totalPresent = 0, totalTotal = 0;
            for (final e in subjects) {
              totalPresent += e.record?.present ?? 0;
              totalTotal += e.record?.total ?? 0;
            }
            final overallPct = totalTotal == 0 ? 0.0 : totalPresent / totalTotal;

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
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      tooltip: 'Import PDF',
                      onPressed: _handlePdfImport,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),

                // Overall summary card
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.sm, AppSpacing.x2l, 0),
                  sliver: SliverToBoxAdapter(
                    child: StaggeredListItem(
                      index: 0,
                      child: _OverallCard(
                        percentage: overallPct,
                        present: totalPresent,
                        total: totalTotal,
                      ),
                    ),
                  ),
                ),

                // Today's Lectures for Marking
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.x3l, AppSpacing.x2l, AppSpacing.md),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Today\'s Lectures',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: FutureBuilder<List<TimetableEntry>>(
                    future: _todayLecturesFuture,
                    builder: (context, todaySnap) {
                      if (todaySnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }
                      
                      final entries = todaySnap.data ?? [];
                      // Filter by active
                      final activeEntries = entries.where((e) => e.isActive).toList();
                      
                      if (activeEntries.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                          child: Text('No active lectures today.', style: TextStyle(color: Theme.of(context).extension<AppSemanticColors>()!.onSurfaceMuted)),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                        child: Column(
                          children: activeEntries.map((e) => _TodayLectureMarkCard(
                            entry: e,
                            division: widget.division,
                            records: records,
                          )).toList(),
                        ),
                      );
                    }
                  ),
                ),

                // Section label
                if (subjects.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.x3l, AppSpacing.x2l, AppSpacing.md),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Subject-wise Analytics',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
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
                          return StaggeredListItem(
                            index: 2 + i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: _SubjectAttendanceCard(
                                entry: entry,
                                division: widget.division,
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
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: StreamBuilder<List<AttendanceLog>>(
                    stream: AttendanceService.streamLogs(),
                    builder: (context, logsSnap) {
                      if (logsSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }
                      final logs = logsSnap.data ?? [];
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _TodayLectureMarkCard extends StatefulWidget {
  final TimetableEntry entry;
  final String division;
  final Map<String, AttendanceRecord> records;

  const _TodayLectureMarkCard({
    required this.entry,
    required this.division,
    required this.records,
  });

  @override
  State<_TodayLectureMarkCard> createState() => _TodayLectureMarkCardState();
}

class _TodayLectureMarkCardState extends State<_TodayLectureMarkCard> {
  bool _loading = false;

  Future<void> _mark(String? type, String instanceId) async {
    if (_loading) return;
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      await AttendanceService.mark(
        division: widget.division,
        subjectCode: widget.entry.subject,
        component: widget.entry.component,
        instanceId: instanceId,
        markType: type,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final instanceId = '${dateStr}_${widget.entry.id}';
    
    final record = widget.records['${widget.entry.subject}_${widget.entry.component}'];
    final currentMark = record?.markedInstances[instanceId];
    final isMarked = currentMark != null;
    
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final hasEnded = nowMins >= widget.entry.endTime;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.entry.subject} ${widget.entry.component}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Text(
                TimetableManager.formatTime(widget.entry.startTime, widget.entry.endTime),
                style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isMarked)
            Row(
              children: [
                Icon(
                  currentMark == 'present' ? Icons.check_circle :
                  currentMark == 'absent' ? Icons.cancel : Icons.block,
                  color: currentMark == 'present' ? sem.conducted :
                         currentMark == 'absent' ? sem.cancelled : sem.onSurfaceMuted,
                  size: 16
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Marked as ${currentMark[0].toUpperCase()}${currentMark.substring(1)}', 
                    style: GoogleFonts.inter(fontSize: 12, color: 
                      currentMark == 'present' ? sem.conducted :
                      currentMark == 'absent' ? sem.cancelled : sem.onSurfaceMuted,
                      fontWeight: FontWeight.w600)),
                ),
                _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: Icon(Icons.undo, size: 18, color: sem.onSurfaceMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _mark(null, instanceId),
                        tooltip: 'Undo',
                      ),
              ],
            )
          else if (!hasEnded)
            Row(
              children: [
                Icon(Icons.schedule, color: sem.warning, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Text('Markable after lecture ends', style: GoogleFonts.inter(fontSize: 12, color: sem.warning)),
              ],
            )
          else
            _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _MarkButton(
                        label: 'Present',
                        color: sem.conducted,
                        icon: Icons.check_rounded,
                        onTap: () => _mark('present', instanceId),
                      ),
                      _MarkButton(
                        label: 'Absent',
                        color: sem.cancelled,
                        icon: Icons.close_rounded,
                        onTap: () => _mark('absent', instanceId),
                      ),
                      _MarkButton(
                        label: 'Cancelled',
                        color: sem.onSurfaceMuted,
                        icon: Icons.block_rounded,
                        onTap: () => _mark('cancelled', instanceId),
                      ),
                    ],
                  ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SubjectEntry {
  final String subjectCode;
  final String component;
  final AttendanceRecord? record;

  const _SubjectEntry({
    required this.subjectCode,
    required this.component,
    this.record,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class _OverallCard extends StatelessWidget {
  final double percentage;
  final int present;
  final int total;

  const _OverallCard({
    required this.percentage,
    required this.present,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (percentage * 100).round();
    final color = pct >= 75 ? AppColors.green : pct >= 65 ? AppColors.amber : AppColors.red;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2340), const Color(0xFF0F1A30)]
              : [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.level4(colorScheme.primary, isDark: isDark),
      ),
      padding: const EdgeInsets.all(AppSpacing.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Attendance',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountingText(
                value: percentage * 100,
                suffix: '%',
                isPercentage: true,
                style: GoogleFonts.outfit(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  total == 0 ? 'No lectures marked' : '$present / $total',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percentage.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1200),
              curve: AppCurves.standard,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                    total == 0 ? Colors.white.withValues(alpha: 0.4) : color),
              ),
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              pct >= 75
                  ? 'You\'re on track ✓'
                  : pct >= 65
                      ? 'Borderline — attend consistently'
                      : 'Below threshold — needs recovery',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SubjectAttendanceCard extends StatelessWidget {
  final _SubjectEntry entry;
  final String division;

  const _SubjectAttendanceCard(
      {required this.entry, required this.division});

  Color _color(BuildContext context, double pct) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    if (pct >= 0.75) return sem.conducted;
    if (pct >= 0.65) return sem.warning;
    return sem.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final record = entry.record;
    final present = record?.present ?? 0;
    final absent = record?.absent ?? 0;
    final total = record?.total ?? 0;
    final pct = total == 0 ? 0.0 : present / total;
    final color = _color(context, pct);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: total == 0 ? sem.borderSubtle : color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  entry.component == 'Theory'
                      ? entry.subjectCode
                      : '${entry.subjectCode} ${entry.component}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
                decoration: BoxDecoration(
                  color: (total == 0 ? sem.borderSubtle : color).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  total == 0 ? '—' : '${(pct * 100).round()}%',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: total == 0 ? sem.onSurfaceMuted : color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: AppCurves.standard,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation<Color>(total == 0 ? sem.borderSubtle : color),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Chip(icon: Icons.check_rounded, label: '$present Present', color: sem.conducted),
              const SizedBox(width: AppSpacing.sm),
              _Chip(icon: Icons.close_rounded, label: '$absent Absent', color: sem.cancelled),
              const Spacer(),
              if (total > 0 && pct < 0.75) _AlertBadge(record: record!),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AlertBadge extends StatelessWidget {
  final AttendanceRecord record;

  const _AlertBadge({required this.record});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final pct = record.percentage;
    String msg;
    Color col;
    if (pct >= 0.65) {
      msg = 'Miss ${record.canMiss} more max';
      col = sem.warning;
    } else {
      msg = 'Attend ${record.needToAttend} to recover';
      col = sem.cancelled;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Text(msg, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: col)),
    );
  }
}

class _MarkButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _MarkButton({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
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
                  log.component == 'Theory' ? log.subjectCode : '\${log.subjectCode} \${log.component}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '\${log.date.day}/\${log.date.month}/\${log.date.year} • \${TimetableManager.formatTime(log.startTime, log.endTime)}',
                  style: GoogleFonts.inter(fontSize: 11, color: sem.onSurfaceMuted),
                ),
              ],
            ),
          ),
          if (log.confidence != MatchConfidence.perfect && log.confidence != MatchConfidence.normalized)
            Icon(Icons.warning_amber_rounded, color: sem.warning, size: 16),
        ],
      ),
    );
  }
}
