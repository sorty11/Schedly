import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedly/services/attendance_service.dart';
import 'package:schedly/models/attendance_record.dart';

import 'widgets/beta_badge.dart';

import 'widgets/timetable_studio_sheet.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'cr_panel_page.dart';
import 'services/app_notification_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'widgets/animations/skeleton_components.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/live_lecture_card.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'services/timetable_resolver_service.dart';
import 'timetable_manager.dart';
import 'manual_timetable_studio.dart';
import 'weekly_timetable_page.dart';
import 'upload_timetable_pdf_page.dart';
import 'services/history_service.dart';
import 'services/timetable_event_service.dart';

class DashboardPage extends StatefulWidget {
  final String division;

  const DashboardPage({super.key, required this.division});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late String currentDay;
  late Stream<QuerySnapshot> _lecturesStream;
  bool _hasDraft = false;

  bool _isLoadingTimetableCheck = true;
  bool _hasTimetable = true;
  late Stream<List<AttendanceRecord>> _recordsStream;

  @override
  void initState() {
    super.initState();
    currentDay = _getCurrentDay();
    _lecturesStream = FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(currentDay)
        .snapshots();
    _recordsStream = AttendanceService.streamAll(widget.division);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCROnboarding());
  }

  Future<void> _checkCROnboarding() async {
    if (AppSettings.currentRole != UserRole.cr) {
      if (mounted) setState(() => _isLoadingTimetableCheck = false);
      return;
    }
    if (!mounted) return;

    try {
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      bool hasAny = false;
      for (final day in days) {
        final snap = await FirebaseFirestore.instance
            .collection('timetables')
            .doc(widget.division)
            .collection(day)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          hasAny = true;
          break;
        }
      }

      if (mounted) {
        if (!hasAny) {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getString('studio_draft_${widget.division}') != null) {
            _hasDraft = true;
          }
          _hasTimetable = false;
        }
        _isLoadingTimetableCheck = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        _isLoadingTimetableCheck = false;
        setState(() {});
      }
    }
  }

  Widget _buildTimetableCommandCenter(
    ThemeData theme,
    AppSemanticColors sem,
    bool hasTimetable,
    bool hasDraft,
    int todayCount,
    TimetableEntry? nextLecture,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2l,
        vertical: AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.x2l),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated2 : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: sem.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: title + status ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timetable',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: hasTimetable
                                ? sem.success
                                : hasDraft
                                ? sem.pending
                                : sem.onSurfaceMuted.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hasTimetable
                              ? 'Published & active'
                              : hasDraft
                              ? 'Draft saved — not published'
                              : 'No timetable yet',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: hasTimetable
                                ? sem.success
                                : hasDraft
                                ? sem.pending
                                : sem.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Stats (only when timetable exists)
              if (hasTimetable) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$todayCount',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1,
                      ),
                    ),
                    Text(
                      'today',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: sem.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
                if (nextLecture != null) ...[
                  Container(
                    width: 1,
                    height: 36,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    color: sem.borderSubtle,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'NEXT UP',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: sem.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          nextLecture.displaySubject,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.x2l),

          // ── Primary CTA — full width, highest visual weight ──────────────
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ManualTimetableStudio(division: widget.division),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
              label: Text(
                hasTimetable ? 'Bulk Edit Week' : 'Create Timetable',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Secondary actions — equal weight, outlined ───────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WeeklyTimetablePage(
                            division: widget.division,
                            isEditMode: true,
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.view_week_outlined,
                      size: 16,
                      color: primary,
                    ),
                    label: Text(
                      'Week View',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!mounted) return;
                      await TimetableStudioSheet.show(
                        context,
                        division: widget.division,
                        initialDay: 'Monday',
                      );
                    },
                    icon: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    label: Text(
                      'Quick Add',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: sem.borderSubtle, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Tertiary action — Import PDF as text-row ──────────────────────
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UploadTimetablePdfPage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 14,
                    color: sem.onSurfaceMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Import from PDF',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: sem.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const BetaBadge(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDay() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDay() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '$currentDay, ${months[now.month - 1]} ${now.day}';
  }

  bool _canEditLecture(TimetableEntry entry) {
    if (entry.category != EventCategory.academic) return false;
    if (AppSettings.currentRole == UserRole.cr) return true;
    if (AppSettings.currentRole == UserRole.sr) {
      return entry.subject == AppSettings.srSubject &&
          entry.batch == AppSettings.srBatch;
    }
    return false;
  }

  Future<void> _editLecture(TimetableEntry entry) async {
    final isCR = AppSettings.currentRole == UserRole.cr;
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x2l,
            AppSpacing.lg,
            AppSpacing.x2l,
            AppSpacing.x2l,
          ),
          decoration: BoxDecoration(
            color: isDark ? sem.surfaceElevated2 : colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.x2l),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sem.borderSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Lecture context card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.08 : 0.05,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          Icons.class_rounded,
                          color: colorScheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displaySubject,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              TimetableManager.formatTime(
                                entry.startTime,
                                entry.endTime,
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: sem.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Edit action
                _ActionTile(
                  icon: Icons.edit_calendar_rounded,
                  label: 'Edit Lecture',
                  subtitle: 'Modify subject, time, or batch',
                  iconColor: colorScheme.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    TimetableStudioSheet.show(
                      context,
                      division: widget.division,
                      initialDay: currentDay,
                      existingEntry: entry,
                    );
                  },
                ),

                // Cancel / Restore action
                if (entry.isActive) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ActionTile(
                    icon: Icons.block_rounded,
                    label: 'Cancel Today',
                    subtitle: 'Mark this lecture as cancelled',
                    iconColor: sem.warning,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await FirebaseFirestore.instance
                          .collection('timetables')
                          .doc(widget.division)
                          .collection(currentDay)
                          .doc(entry.id)
                          .update({'status': 'cancelled', 'isActive': false});

                      final timeStr = TimetableManager.formatTime(
                        entry.startTime,
                        entry.endTime,
                      );
                      await HistoryService.logOperation(
                        division: widget.division,
                        operation: 'Lecture Cancelled',
                        details:
                            '${entry.displaySubject} on $currentDay at $timeStr',
                        role: AppSettings.currentRole.name,
                      );
                      await TimetableEventService.handleModification(
                        division: widget.division,
                        day: currentDay,
                        oldEntry: entry,
                        isCancel: true,
                      );
                    },
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ActionTile(
                    icon: Icons.restore_rounded,
                    label: 'Restore Lecture',
                    subtitle: 'Mark this lecture as active again',
                    iconColor: sem.conducted,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await FirebaseFirestore.instance
                          .collection('timetables')
                          .doc(widget.division)
                          .collection(currentDay)
                          .doc(entry.id)
                          .update({'status': 'active', 'isActive': true});

                      final timeStr = TimetableManager.formatTime(
                        entry.startTime,
                        entry.endTime,
                      );
                      await HistoryService.logOperation(
                        division: widget.division,
                        operation: 'Lecture Restored',
                        details:
                            '${entry.displaySubject} on $currentDay at $timeStr',
                        role: AppSettings.currentRole.name,
                      );
                      await TimetableEventService.handleModification(
                        division: widget.division,
                        day: currentDay,
                        oldEntry: entry,
                        isRestore: true,
                      );
                    },
                  ),
                ],

                // Delete action — CR only, with confirmation
                if (isCR) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ActionTile(
                    icon: Icons.delete_rounded,
                    label: 'Delete Permanently',
                    subtitle: 'Remove from timetable — cannot be undone',
                    iconColor: sem.cancelled,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          icon: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: sem.cancelled.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delete_rounded,
                              color: sem.cancelled,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            'Delete Lecture?',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          content: Text(
                            'This permanently removes the lecture from the timetable. Students and faculty will be notified.',
                            style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                          actionsAlignment: MainAxisAlignment.center,
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: sem.cancelled,
                              ),
                              child: Text(
                                'Delete',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      await FirebaseFirestore.instance
                          .collection('timetables')
                          .doc(widget.division)
                          .collection(currentDay)
                          .doc(entry.id)
                          .delete();

                      final timeStr = TimetableManager.formatTime(
                        entry.startTime,
                        entry.endTime,
                      );
                      await HistoryService.logOperation(
                        division: widget.division,
                        operation: 'Lecture Deleted',
                        details:
                            '${entry.displaySubject} on $currentDay at $timeStr',
                        role: AppSettings.currentRole.name,
                      );
                      await TimetableEventService.handleModification(
                        division: widget.division,
                        day: currentDay,
                        oldEntry: entry,
                        isDelete: true,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final firstName = (AppSettings.studentName ?? 'Student').split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<AttendanceRecord>>(
          stream: _recordsStream,
          builder: (context, recordsSnap) {
            final rawRecords = recordsSnap.data ?? [];
            final Map<String, AttendanceRecord> attendanceRecords = {};

            final List<String> mergedSubjects = [
              'DM',
              'Discrete Mathematics',
              'PnS',
              'SnS',
              'Python',
              'PROGRAMMING WITH PYTHON',
              'Signals and Systems',
              'Principles of Economics and Managemen',
            ];

            for (final r in rawRecords) {
              String subjectName = r.subjectCode;
              String componentName = r.component;

              if (subjectName.toUpperCase().contains('DATA STRUCTURES') ||
                  subjectName.trim().toUpperCase() == 'DSA') {
                subjectName = 'DSA';
                if (componentName.toUpperCase().contains('LAB') ||
                    componentName.toUpperCase().contains('PRACTICAL')) {
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
                if (normComponent.isEmpty || normComponent == 'Lecture')
                  normComponent = 'Theory';
                else if (normComponent == 'Practical')
                  normComponent = 'Lab';

                attendanceRecords['${subjectName}_$normComponent'] = r;
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _lecturesStream,
              builder: (context, snapshot) {
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

                final docs = snapshot.data?.docs ?? [];
                final nowD = DateTime.now();
                final String todayStr =
                    '${nowD.year}-${nowD.month.toString().padLeft(2, '0')}-${nowD.day.toString().padLeft(2, '0')}';

                final userBatch = AppSettings.currentRole == UserRole.student
                    ? AppSettings.studentBatch
                    : null;

                final rawEntries = docs
                    .map((doc) => TimetableEntry.fromFirestore(doc))
                    .toList();

                final resolved = TimetableResolverService.resolve(
                  rawEntries: rawEntries,
                  targetDateStr: todayStr,
                  userBatch: userBatch,
                );

                if (resolved.isHoliday) {
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.x6l),
                          child: FloatingEmptyState(
                            icon: Icons.celebration_rounded,
                            title: 'Holiday',
                            subtitle:
                                resolved.holidayName ?? 'No classes today.',
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final rawLectures = resolved.lectures;

                final Map<int, List<TimetableEntry>> grouped = {};
                for (final e in rawLectures) {
                  if (!grouped.containsKey(e.startTime)) {
                    grouped[e.startTime] = [];
                  }
                  grouped[e.startTime]!.add(e);
                }

                final sortedKeys = grouped.keys.toList()..sort();
                final groupedLectures = sortedKeys
                    .map((k) => grouped[k]!)
                    .toList();

                List<TimetableEntry>? currentGroup;
                List<TimetableEntry>? nextGroup;

                final now = DateTime.now();
                final nowMins = now.hour * 60 + now.minute;

                for (int i = 0; i < groupedLectures.length; i++) {
                  final group = groupedLectures[i];

                  final start = group.first.startTime;
                  final end = group
                      .map((e) => e.endTime)
                      .reduce((a, b) => a > b ? a : b);

                  if (nowMins >= start && nowMins < end) {
                    currentGroup = group;
                  } else if (nowMins < start &&
                      currentGroup == null &&
                      nextGroup == null) {
                    nextGroup = group;
                  } else if (nowMins < start &&
                      currentGroup != null &&
                      nextGroup == null) {
                    nextGroup = group;
                  }
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x2l,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StaggeredListItem(
                                    index: 0,
                                    child: Text(
                                      '${_getGreeting()}, $firstName 👋',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  StaggeredListItem(
                                    index: 1,
                                    child: Text(
                                      _formatDay(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                if (AppSettings.currentRole == UserRole.cr ||
                                    AppSettings.currentRole == UserRole.sr)
                                  AnimatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const CRPanelPage(),
                                        ),
                                      ).then((_) => setState(() {}));
                                    },
                                    backgroundColor: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    borderRadius: AppRadius.sm,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          AppSettings.currentRole == UserRole.cr
                                              ? Icons
                                                    .admin_panel_settings_rounded
                                              : Icons.school_rounded,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          AppSettings.currentRole == UserRole.cr
                                              ? 'CR'
                                              : 'SR',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (isLoading)
                      const SliverToBoxAdapter(child: HeroCardSkeleton()),

                    if (!isLoading &&
                        AppSettings.currentRole == UserRole.cr &&
                        !_isLoadingTimetableCheck)
                      SliverToBoxAdapter(
                        child: _buildTimetableCommandCenter(
                          Theme.of(context),
                          sem,
                          _hasTimetable,
                          _hasDraft,
                          rawLectures.length,
                          nextGroup?.first,
                        ),
                      ),

                    if (!isLoading && _hasDraft)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                            vertical: AppSpacing.sm,
                          ),
                          child: Container(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit_calendar_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Draft Saved',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Continue building your timetable.',
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ManualTimetableStudio(
                                          division: widget.division,
                                        ),
                                      ),
                                    ).then((_) => _checkCROnboarding());
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Resume',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (!isLoading && currentGroup != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                          ),
                          child: StaggeredListItem(
                            index: 2,
                            child: LiveLectureCard(
                              subject: currentGroup.length == 1
                                  ? currentGroup.first.subject
                                  : currentGroup
                                        .map((e) => e.subject)
                                        .toSet()
                                        .join(' / '),
                              time: TimetableManager.formatTime(
                                currentGroup.first.startTime,
                                currentGroup.first.endTime,
                              ),
                              room: currentGroup.length == 1
                                  ? (currentGroup.first.room ?? 'TBA')
                                  : currentGroup
                                        .map((e) => e.room ?? 'TBA')
                                        .toSet()
                                        .join(' / '),
                              onTap:
                                  currentGroup.length == 1 &&
                                      _canEditLecture(currentGroup.first)
                                  ? () => _editLecture(currentGroup!.first)
                                  : null,
                            ),
                          ),
                        ),
                      ),

                    if (!isLoading && currentGroup != null)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.x2l),
                      ),

                    if (isLoading)
                      const SliverToBoxAdapter(child: StatsRowSkeleton()),

                    if (!isLoading && groupedLectures.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                          ),
                          child: StaggeredListItem(
                            index: 3,
                            child: _QuickStatsRow(
                              division: widget.division,
                              lectureCount: rawLectures.length,
                              cancelledCount: rawLectures
                                  .where((l) => !l.isActive)
                                  .length,
                            ),
                          ),
                        ),
                      ),

                    if (isLoading) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                          ),
                          child: LectureCardSkeleton(includeTime: true),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                          ),
                          child: LectureCardSkeleton(includeTime: true),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                          ),
                          child: LectureCardSkeleton(includeTime: true),
                        ),
                      ),
                    ],

                    if (!isLoading && groupedLectures.isEmpty)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.x2l),
                      ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.x2l,
                          right: AppSpacing.x2l,
                          bottom: AppSpacing.md,
                        ),
                        child: StaggeredListItem(
                          index: 4,
                          child: Row(
                            children: [
                              Text(
                                "Today's Schedule",
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              if (!isLoading && groupedLectures.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    // Neutral badge — not brand color
                                    color: sem.borderSubtle,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    '${groupedLectures.length} block${groupedLectures.length == 1 ? '' : 's'}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: sem.onSurfaceMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (!isLoading && groupedLectures.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: FloatingEmptyState(
                          icon: Icons.event_available_rounded,
                          title: 'No classes today',
                          subtitle:
                              'Enjoy your free time or catch up on studies',
                        ),
                      ),

                    if (!isLoading && groupedLectures.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2l,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final entries = groupedLectures[index];
                            final isCurrent =
                                currentGroup != null &&
                                entries.first.startTime ==
                                    currentGroup.first.startTime;
                            final isNext =
                                nextGroup != null &&
                                entries.first.startTime ==
                                    nextGroup.first.startTime;
                            final isLast = index == groupedLectures.length - 1;

                            return StaggeredListItem(
                              index: 5 + index,
                              child: _TimelineLectureItem(
                                entries: entries,
                                isCurrent: isCurrent,
                                isNext: isNext,
                                isLast: isLast,
                                canEdit: _canEditLecture,
                                onEdit: _editLecture,
                                attendanceRecords: attendanceRecords,
                              ),
                            );
                          }, childCount: groupedLectures.length),
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
        ),
      ),
    );
  }
}

class _TimelineLectureItem extends StatelessWidget {
  final List<TimetableEntry> entries;
  final bool isCurrent;
  final bool isNext;
  final bool isLast;
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
  });

  Color _subjectColor(String subject, BuildContext context) {
    if (subject.toLowerCase().contains('lunch')) return Colors.amber;
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).extension<AppSemanticColors>()!.accent,
      Theme.of(context).extension<AppSemanticColors>()!.conducted,
      Theme.of(context).extension<AppSemanticColors>()!.rescheduled,
    ];
    return colors[subject.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final timeStr = TimetableManager.formatTime(
      entries.first.startTime,
      entries.first.endTime,
    );
    final startTime = timeStr.split('-')[0].trim();

    final allCancelled = entries.every((e) => !e.isActive);
    final activeEntry = entries.firstWhere(
      (e) => e.isActive,
      orElse: () => entries.first,
    );
    final blockColor = allCancelled
        ? sem.cancelled
        : _subjectColor(activeEntry.subject, context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(
                  startTime,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? colorScheme.primary : sem.onSurfaceMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm - 2),
                Container(
                  width: isCurrent ? 14 : 10,
                  height: isCurrent ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: allCancelled
                        ? sem.cancelled.withValues(alpha: 0.3)
                        : isCurrent
                        ? colorScheme.primary
                        : isDark
                        ? sem.borderSubtle
                        : sem.borderSubtle,
                    border: isCurrent
                        ? Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            width: 3,
                          )
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: isDark ? sem.borderSubtle : sem.borderSubtle,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: AnimatedCard(
                onTap: (entries.length == 1 && canEdit(entries.first))
                    ? () => onEdit(entries.first)
                    : null,
                backgroundColor: isCurrent
                    ? colorScheme.primary.withValues(
                        alpha: isDark ? 0.12 : 0.06,
                      )
                    : allCancelled
                    ? sem.cancelled.withValues(alpha: isDark ? 0.08 : 0.04)
                    : (isDark ? sem.surfaceElevated2 : colorScheme.surface),
                borderRadius: AppRadius.lg,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border(
                      left: BorderSide(
                        color: allCancelled
                            ? sem.cancelled
                            : isCurrent
                            ? colorScheme.primary
                            : blockColor.withValues(alpha: 0.6),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: entries.asMap().entries.map((mapEntry) {
                        final idx = mapEntry.key;
                        final entry = mapEntry.value;
                        final isCancelled = !entry.isActive;

                        Widget content = Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.displaySubject,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isCancelled
                                          ? sem.cancelled
                                          : isCurrent
                                          ? colorScheme.primary
                                          : colorScheme.onSurface,
                                      decoration: isCancelled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (entry.batch != 'Whole Class' ||
                                      (entry.room != null &&
                                          entry.room!.isNotEmpty))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppSpacing.xs - 2,
                                      ),
                                      child: Text(
                                        [
                                          if (entry.batch != 'Whole Class')
                                            entry.batch,
                                          if (entry.room != null &&
                                              entry.room!.isNotEmpty)
                                            'Room ${entry.room}',
                                        ].join(' · '),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: sem.onSurfaceMuted,
                                        ),
                                      ),
                                    ),
                                  Builder(
                                    builder: (context) {
                                      if (attendanceRecords == null)
                                        return const SizedBox.shrink();

                                      String subj = entry.subject;
                                      String comp = entry.component;
                                      if (subj.toUpperCase().contains(
                                            'DATA STRUCTURES',
                                          ) ||
                                          subj.trim().toUpperCase() == 'DSA') {
                                        subj = 'DSA';
                                        if (comp.toUpperCase().contains(
                                              'LAB',
                                            ) ||
                                            comp.toUpperCase().contains(
                                              'PRACTICAL',
                                            ))
                                          comp = 'Lab';
                                        else
                                          comp = 'Theory';
                                      }

                                      final merged = [
                                        'DM',
                                        'Discrete Mathematics',
                                        'PnS',
                                        'SnS',
                                        'Python',
                                        'PROGRAMMING WITH PYTHON',
                                        'Signals and Systems',
                                        'Principles of Economics and Managemen',
                                      ];
                                      String key = merged.contains(subj)
                                          ? '${subj}_Merged'
                                          : '${subj}_$comp';

                                      final record = attendanceRecords![key];
                                      if (record == null)
                                        return const SizedBox.shrink();

                                      int p = record.present;
                                      int a = record.absent;
                                      double attendPct =
                                          (p + 1) / (p + a + 1) * 100;
                                      double skipPct = p / (p + a + 1) * 100;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? sem.surfaceElevated2
                                                : sem.borderSubtle.withValues(
                                                    alpha: 0.5,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '🟢 If attend: ${attendPct.toStringAsFixed(1)}%  |  🔴 If skip: ${skipPct.toStringAsFixed(1)}%',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white70
                                                  : sem.onSurfaceMuted,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (isCancelled && idx == 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: sem.cancelled.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Text(
                                  'CANCELLED',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: sem.cancelled,
                                  ),
                                ),
                              ),
                            ] else if (isCurrent && idx == 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Text(
                                  'NOW',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ] else if (isNext && !isCurrent && idx == 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: sem.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Text(
                                  'NEXT',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: sem.accent,
                                  ),
                                ),
                              ),
                            ],
                            if (canEdit(entry) && entries.length > 1) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: sem.onSurfaceMuted,
                              ),
                            ],
                          ],
                        );

                        if (entries.length > 1) {
                          return GestureDetector(
                            onTap: canEdit(entry) ? () => onEdit(entry) : null,
                            child: Container(
                              margin: EdgeInsets.only(
                                top: idx == 0 ? 0 : AppSpacing.md,
                              ),
                              padding: EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: content,
                            ),
                          );
                        } else {
                          return content;
                        }
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final String division;
  final int lectureCount;
  final int cancelledCount;

  const _QuickStatsRow({
    required this.division,
    required this.lectureCount,
    required this.cancelledCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeLectures = lectureCount - cancelledCount;

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated2 : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _StatCell(
            value: '$lectureCount',
            label: 'Total',
            // Neutral — total count is factual, not brand-colored
            color: colorScheme.onSurface,
          ),
          _Divider(),
          _StatCell(
            value: '$activeLectures',
            label: 'Active',
            color: sem.conducted,
          ),
          _Divider(),
          _StatCell(
            value: '$cancelledCount',
            label: 'Cancelled',
            color: cancelledCount > 0 ? sem.cancelled : sem.onSurfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: sem.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Container(
      width: 1,
      height: 32,
      color: sem.borderSubtle,
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    );
  }
}

// ── Action Tile ─────────────────────────────────────────────────────────────────
// Reusable themed action tile for bottom sheet action menus
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: sem.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: sem.onSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
