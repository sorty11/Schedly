import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'edit_lecture_page.dart';
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

  @override
  void initState() {
    super.initState();
    currentDay = _getCurrentDay();
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditLecturePage(
          division: widget.division,
          lecture: {
            'id': entry.id,
            'subject': entry.subject,
            'time': TimetableManager.formatTime(entry.startTime, entry.endTime),
            'room': entry.room ?? '',
            'cancelled': (!entry.isActive).toString(),
          },
        ),
      ),
    );

    if (result == null) return;

    final action = result['action'];
    if (action == 'split') {
      final lec1 = result['lecture1'] as Map<String, dynamic>;
      final lec2 = result['lecture2'] as Map<String, dynamic>;

      final parts1 = lec1['time'].toString().split('-');
      final start1 = TimetableManager.parseTime(parts1[0]);
      final end1 = parts1.length > 1 ? TimetableManager.parseTime(parts1[1]) : start1 + 60;

      final parts2 = lec2['time'].toString().split('-');
      final start2 = TimetableManager.parseTime(parts2[0]);
      final end2 = parts2.length > 1 ? TimetableManager.parseTime(parts2[1]) : start2 + 60;

      await FirebaseFirestore.instance
          .collection('timetables')
          .doc(widget.division)
          .collection(currentDay)
          .doc(entry.id)
          .update({
        'subject': lec1['subject'],
        'startTime': start1,
        'endTime': end1,
        'room': lec1['room'],
        'isActive': lec1['cancelled'] != 'true',
        'durationMinutes': end1 - start1,
      });

      await FirebaseFirestore.instance
          .collection('timetables')
          .doc(widget.division)
          .collection(currentDay)
          .add({
        'subject': lec2['subject'],
        'startTime': start2,
        'endTime': end2,
        'room': lec2['room'],
        'isActive': lec2['cancelled'] != 'true',
        'batch': entry.batch,
        'category': entry.category.name.toLowerCase(),
        'durationMinutes': end2 - start2,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lecture split successfully!')),
      );
      return;
    }

    final updated = result as Map<String, dynamic>;
    final parts = updated['time'].toString().split('-');
    final start = TimetableManager.parseTime(parts[0]);
    final end = parts.length > 1 ? TimetableManager.parseTime(parts[1]) : start + 60;
    
    final oldSubject = entry.subject;
    final oldTimeStr = TimetableManager.formatTime(entry.startTime, entry.endTime);
    final oldRoom = entry.room ?? '';
    final oldCancelled = !entry.isActive;
    final newCancelled = updated['cancelled'] == 'true';

    await FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(currentDay)
        .doc(entry.id)
        .update({
      'subject': updated['subject'],
      'startTime': start,
      'endTime': end,
      'room': updated['room'],
      'isActive': !newCancelled,
      'durationMinutes': end - start,
    });

    String type = 'update';
    String message = '';

    if (newCancelled && !oldCancelled) {
      type = 'cancel';
      message = '$oldSubject on $currentDay has been cancelled.';
    } else if (updated['room'] != oldRoom) {
      type = 'room_change';
      message = '$oldSubject room changed to ${updated['room']} on $currentDay.';
    } else if (updated['time'] != oldTimeStr) {
      type = 'time_change';
      message = '$oldSubject time changed to ${updated['time']} on $currentDay.';
    } else {
      return;
    }

    await AppNotificationService.createNotification(
      title: 'Timetable Update',
      message: message,
      division: widget.division,
      type: type,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            final rawLectures = docs.map((doc) => TimetableEntry.fromFirestore(doc)).toList();

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
              if (!group.any((e) => e.isActive)) continue;
              
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
                            if (isCurrent && idx == 0) ...[
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
                            ],
                            if (isNext && !isCurrent && idx == 0) ...[
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
