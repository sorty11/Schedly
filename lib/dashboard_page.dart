import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/live_lecture_card.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'timetable_manager.dart';
import 'manual_timetable_studio.dart';
import 'upload_timetable_pdf_page.dart';
import 'system_update_manager.dart';
import 'services/announcement_service.dart';
import 'services/local_notification_service.dart';
import 'services/history_service.dart';
import 'services/timetable_event_service.dart';

class DashboardPage extends StatefulWidget {
  final String division;

  const DashboardPage({
    super.key,
    required this.division,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late String currentDay;
  bool _hasDraft = false;

  bool _isLoadingTimetableCheck = true;
  bool _hasTimetable = true;

  @override
  void initState() {
    super.initState();
    currentDay = _getCurrentDay();
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
        if (snap.docs.isNotEmpty) { hasAny = true; break; }
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

  Widget _buildNoTimetableCard(ThemeData theme, AppSemanticColors sem) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? sem.surfaceElevated : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sem.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No Timetable Found',
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your class timetable manually or import a PDF.',
            style: GoogleFonts.inter(fontSize: 14, color: sem.onSurfaceMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ManualTimetableStudio(division: widget.division),
              ));
            },
            icon: const Icon(Icons.edit_calendar_rounded, size: 18),
            label: Text('Create Timetable', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const UploadTimetablePdfPage(),
              ));
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: sem.borderSubtle, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf_rounded, size: 18, color: sem.onSurfaceMuted),
                const SizedBox(width: 8),
                Text('Import PDF', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                const SizedBox(width: 8),
                const BetaBadge(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _hasTimetable = true), // Dismiss the card by faking timetable presence
              child: Text('Skip for now',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: sem.onSurfaceMuted, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDay() {
    const days = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday',
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$currentDay, ${months[now.month - 1]} ${now.day}';
  }

  bool _canEditLecture(TimetableEntry entry) {
    if (entry.category != EventCategory.academic) return false;
    if (AppSettings.currentRole == UserRole.cr) return true;
    if (AppSettings.currentRole == UserRole.sr) {
      return entry.subject == AppSettings.srSubject && entry.batch == AppSettings.srBatch;
    }
    return false;
  }

  Future<void> _editLecture(TimetableEntry entry) async {
    final isCR = AppSettings.currentRole == UserRole.cr;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Lecture'),
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
            ListTile(
              leading: const Icon(Icons.find_replace_rounded),
              title: const Text('Replace Lecture'),
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
            if (entry.isActive)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.orange),
                title: const Text('Cancel Lecture', style: TextStyle(color: Colors.orange)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('timetables')
                      .doc(widget.division)
                      .collection(currentDay)
                      .doc(entry.id)
                      .update({'status': 'cancelled', 'isActive': false});
                  
                  final timeStr = TimetableManager.formatTime(entry.startTime, entry.endTime);
                  
                  await HistoryService.logOperation(
                    division: widget.division,
                    operation: 'Lecture Cancelled',
                    details: '${entry.displaySubject} on $currentDay at $timeStr',
                    role: AppSettings.currentRole.name,
                  );

                  await TimetableEventService.handleModification(
                    division: widget.division,
                    day: currentDay,
                    oldEntry: entry,
                    isCancel: true,
                  );
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: const Text('Restore Lecture', style: TextStyle(color: Colors.green)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('timetables')
                      .doc(widget.division)
                      .collection(currentDay)
                      .doc(entry.id)
                      .update({'status': 'active', 'isActive': true});
                  
                  final timeStr = TimetableManager.formatTime(entry.startTime, entry.endTime);
                  await HistoryService.logOperation(
                    division: widget.division,
                    operation: 'Lecture Restored',
                    details: '${entry.displaySubject} on $currentDay at $timeStr',
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
            if (isCR)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Delete Lecture', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('timetables')
                      .doc(widget.division)
                      .collection(currentDay)
                      .doc(entry.id)
                      .delete();
                  
                  final timeStr = TimetableManager.formatTime(entry.startTime, entry.endTime);
                  await HistoryService.logOperation(
                    division: widget.division,
                    operation: 'Lecture Deleted',
                    details: '${entry.displaySubject} on $currentDay at $timeStr',
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final firstName = (AppSettings.studentName ?? 'Student').split(' ').first;

    final Stream<QuerySnapshot> lecturesStream = FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(currentDay)
        .snapshots();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: lecturesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            final rawLectures = docs
                .map((doc) => TimetableEntry.fromFirestore(doc))
                .toList();

            final Map<int, List<TimetableEntry>> grouped = {};
            for (final e in rawLectures) {
              if (!grouped.containsKey(e.startTime)) {
                grouped[e.startTime] = [];
              }
              grouped[e.startTime]!.add(e);
            }
            
            final sortedKeys = grouped.keys.toList()..sort();
            final groupedLectures = sortedKeys.map((k) => grouped[k]!).toList();

            List<TimetableEntry>? currentGroup;
            List<TimetableEntry>? nextGroup;
            
            final now = DateTime.now();
            final nowMins = now.hour * 60 + now.minute;

            for (int i = 0; i < groupedLectures.length; i++) {
              final group = groupedLectures[i];
              
              final start = group.first.startTime;
              final end = group.map((e) => e.endTime).reduce((a, b) => a > b ? a : b);

              if (nowMins >= start && nowMins < end) {
                currentGroup = group;
              } else if (nowMins < start && currentGroup == null && nextGroup == null) {
                nextGroup = group;
              } else if (nowMins < start && currentGroup != null && nextGroup == null) {
                nextGroup = group;
              }
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
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
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              StaggeredListItem(
                                index: 1,
                                child: Text(
                                  _formatDay(),
                                  style: Theme.of(context).textTheme.bodyMedium,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                borderRadius: AppRadius.sm,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppSettings.currentRole == UserRole.cr
                                          ? Icons.admin_panel_settings_rounded
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

                if (!_hasTimetable && !_hasDraft && AppSettings.currentRole == UserRole.cr && !_isLoadingTimetableCheck)
                  SliverToBoxAdapter(
                    child: _buildNoTimetableCard(Theme.of(context), sem),
                  ),

                if (_hasDraft)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.edit_calendar_rounded, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Draft Saved', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                                  Text('Continue building your timetable.', style: GoogleFonts.inter(fontSize: 13)),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ManualTimetableStudio(division: widget.division),
                                )).then((_) => _checkCROnboarding());
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Resume', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (currentGroup != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2l,
                      ),
                      child: StaggeredListItem(
                        index: 2,
                        child: LiveLectureCard(
                          subject: currentGroup.length == 1 
                               ? currentGroup.first.subject 
                               : currentGroup.map((e) => e.subject).toSet().join(' / '),
                          time: TimetableManager.formatTime(currentGroup.first.startTime, currentGroup.first.endTime),
                          room: currentGroup.length == 1 
                               ? (currentGroup.first.room ?? 'TBA') 
                               : currentGroup.map((e) => e.room ?? 'TBA').toSet().join(' / '),
                          onTap: currentGroup.length == 1 && _canEditLecture(currentGroup.first)
                              ? () => _editLecture(currentGroup!.first)
                              : null,
                        ),
                      ),
                    ),
                  ),

                if (currentGroup != null)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.x2l),
                  ),

                if (groupedLectures.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2l,
                      ),
                      child: StaggeredListItem(
                        index: 3,
                        child: _QuickStatsRow(
                          division: widget.division,
                          lectureCount: rawLectures.length,
                          cancelledCount:
                              rawLectures.where((l) => !l.isActive).length,
                        ),
                      ),
                    ),
                  ),

                if (groupedLectures.isNotEmpty)
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
                          if (groupedLectures.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                '${groupedLectures.length} block${groupedLectures.length == 1 ? '' : 's'}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (groupedLectures.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: FloatingEmptyState(
                      icon: Icons.event_available_rounded,
                      title: 'No classes today',
                      subtitle: 'Enjoy your free time or catch up on studies',
                    ),
                  ),

                if (groupedLectures.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x2l,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entries = groupedLectures[index];
                          final isCurrent = currentGroup != null && entries.first.startTime == currentGroup.first.startTime;
                          final isNext = nextGroup != null && entries.first.startTime == nextGroup.first.startTime;
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
                            ),
                          );
                        },
                        childCount: groupedLectures.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.x6l),
                ),
              ],
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

  const _TimelineLectureItem({
    required this.entries,
    required this.isCurrent,
    required this.isNext,
    required this.isLast,
    required this.canEdit,
    required this.onEdit,
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

    final timeStr = TimetableManager.formatTime(entries.first.startTime, entries.first.endTime);
    final startTime = timeStr.split('-')[0].trim();
    
    final allCancelled = entries.every((e) => !e.isActive);
    final activeEntry = entries.firstWhere((e) => e.isActive, orElse: () => entries.first);
    final blockColor = allCancelled ? sem.cancelled : _subjectColor(activeEntry.subject, context);

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
                      margin: const EdgeInsets.symmetric(vertical: 4),
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
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.md,
              ),
              child: AnimatedCard(
                onTap: (entries.length == 1 && canEdit(entries.first)) ? () => onEdit(entries.first) : null,
                backgroundColor: isCurrent
                    ? colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.06)
                    : isDark
                        ? sem.surfaceElevated
                        : colorScheme.surface,
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
                    padding: const EdgeInsets.symmetric(
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
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (entry.batch != 'Whole Class' || entry.room != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                                      child: Row(
                                        children: [
                                          if (entry.batch != 'Whole Class')
                                            Text(
                                              entry.batch,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: sem.onSurfaceMuted,
                                              ),
                                            ),
                                          if (entry.batch != 'Whole Class' && entry.room != null && entry.room!.isNotEmpty)
                                            Text(
                                              ' • ',
                                              style: TextStyle(color: sem.onSurfaceMuted),
                                            ),
                                          if (entry.room != null && entry.room!.isNotEmpty)
                                            Text(
                                              'Room ${entry.room}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: sem.onSurfaceMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isCancelled && idx == 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sem.cancelled.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
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
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
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
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sem.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
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
                              Icon(Icons.edit_rounded, size: 14, color: sem.onSurfaceMuted),
                            ],
                          ],
                        );

                        if (entries.length > 1) {
                          return GestureDetector(
                            onTap: canEdit(entry) ? () => onEdit(entry) : null,
                            child: Container(
                              margin: EdgeInsets.only(top: idx == 0 ? 0 : AppSpacing.md),
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(AppRadius.md),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated : colorScheme.surface,
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
            color: colorScheme.primary,
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
            color: sem.cancelled,
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
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    );
  }
}
