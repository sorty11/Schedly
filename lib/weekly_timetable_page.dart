import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'edit_lecture_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'services/app_notification_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'services/permission_service.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'timetable_manager.dart';

class WeeklyTimetablePage extends StatefulWidget {
  final String division;

  const WeeklyTimetablePage({
    super.key,
    required this.division,
  });

  @override
  State<WeeklyTimetablePage> createState() => _WeeklyTimetablePageState();
}

class _WeeklyTimetablePageState extends State<WeeklyTimetablePage> {
  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];
  static const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  late String selectedDay;
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 5);
    selectedIndex = todayIndex;
    selectedDay = _days[todayIndex];
  }

  Color _subjectColor(String subject, BuildContext context) {
    if (subject.toLowerCase().contains('lunch')) {
      return Colors.amber;
    }
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      sem.accent,
      sem.conducted,
      sem.rescheduled,
    ];
    return colors[subject.hashCode.abs() % colors.length];
  }

  bool _canEdit(TimetableEntry entry) {
    if (entry.category != EventCategory.academic) return false;
    return PermissionService.canManageLecture(
      lectureSubject: entry.subject,
      lectureComponent: entry.component,
      lectureBatch: entry.batch,
    );
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
            'batch': entry.batch,
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
          .collection(selectedDay)
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
          .collection(selectedDay)
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
        .collection(selectedDay)
        .doc(entry.id)
        .update({
      'subject': updated['subject'],
      'startTime': start,
      'endTime': end,
      'room': updated['room'],
      'isActive': !newCancelled,
      'durationMinutes': end - start,
    });

    if (newCancelled && !oldCancelled) {
      await AppNotificationService.createNotification(
        title: 'Lecture Cancelled',
        message: '${updated['subject']} at ${updated['time']} has been cancelled',
        division: widget.division,
        type: 'cancel',
      );
    }
    if (updated['room'] != oldRoom) {
      await AppNotificationService.createNotification(
        title: 'Room Changed',
        message: '${updated['subject']} moved from $oldRoom to ${updated['room']}',
        division: widget.division,
        type: 'room_change',
      );
    }
    if (updated['time'] != oldTimeStr) {
      await AppNotificationService.createNotification(
        title: 'Lecture Rescheduled',
        message: '${updated['subject']} moved from $oldTimeStr to ${updated['time']}',
        division: widget.division,
        type: 'time_change',
      );
    }
    if (updated['subject'] != oldSubject) {
      await AppNotificationService.createNotification(
        title: 'Lecture Updated',
        message: '$oldSubject changed to ${updated['subject']}',
        division: widget.division,
        type: 'edit',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Lecture updated')));
  }

  IconData _subjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics': return Icons.calculate_rounded;
      case 'programming':
      case 'oop':
      case 'java': return Icons.computer_rounded;
      case 'beee': return Icons.electrical_services_rounded;
      case 'physics': return Icons.science_rounded;
      case 'chemistry': return Icons.biotech_rounded;
      case 'dbms': return Icons.storage_rounded;
      case 'lade': return Icons.menu_book_rounded;
      case 'ctps': return Icons.lightbulb_rounded;
      case 'lunch break':
      case 'lunch': return Icons.restaurant_rounded;
      default: return Icons.book_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 5);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x2l,
                AppSpacing.lg,
                AppSpacing.x2l,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Timetable',
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                  ),
                  const Spacer(),
                  if (AppSettings.currentRole == UserRole.cr ||
                      AppSettings.currentRole == UserRole.sr)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs + 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Long-press to edit',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < -200 &&
                    selectedIndex < _days.length - 1) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    selectedIndex++;
                    selectedDay = _days[selectedIndex];
                  });
                } else if (details.primaryVelocity! > 200 &&
                    selectedIndex > 0) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    selectedIndex--;
                    selectedDay = _days[selectedIndex];
                  });
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? sem.surfaceElevated : colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? sem.borderSubtle
                          : const Color(0xFFEEEEF8),
                      width: 1,
                    ),
                  ),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2l,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: _days.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final isSelected = selectedIndex == index;
                    final isToday = todayIndex == index;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          selectedIndex = index;
                          selectedDay = _days[index];
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: AppDuration.standard,
                          curve: AppCurves.standard,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : isToday
                                    ? colorScheme.primary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayShort[index],
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : isToday
                                          ? colorScheme.primary
                                          : sem.onSurfaceMuted,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('timetables')
                    .doc(widget.division)
                    .collection(selectedDay)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return AnimatedSwitcher(
                      duration: AppDuration.enter,
                      child: FloatingEmptyState(
                        key: ValueKey(selectedDay),
                        icon: Icons.event_available_rounded,
                        title: 'No lectures scheduled',
                        subtitle: 'Enjoy your free $selectedDay!',
                      ),
                    );
                  }

                  final rawLectures = snapshot.data!.docs
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

                  return AnimatedSwitcher(
                    duration: AppDuration.enter,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: ListView.builder(
                      key: ValueKey(selectedDay),
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x2l,
                        AppSpacing.lg,
                        AppSpacing.x2l,
                        AppSpacing.x6l,
                      ),
                      itemCount: groupedLectures.length,
                      itemBuilder: (context, index) {
                        final entries = groupedLectures[index];
                        final allCancelled = entries.every((e) => !e.isActive);
                        final activeEntry = entries.firstWhere((e) => e.isActive, orElse: () => entries.first);
                        final subjectColor = allCancelled
                            ? sem.cancelled
                            : _subjectColor(activeEntry.subject, context);

                        return StaggeredListItem(
                          index: index,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: AnimatedCard(
                              borderRadius: AppRadius.xl,
                              backgroundColor: allCancelled
                                  ? sem.cancelled.withValues(alpha: 0.05)
                                  : isDark
                                      ? sem.surfaceElevated
                                      : colorScheme.surface,
                              onLongPress: (entries.length == 1 && _canEdit(entries.first))
                                  ? () => _editLecture(entries.first)
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xl),
                                  border: Border(
                                    left: BorderSide(
                                      color: subjectColor,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.xl),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: entries.asMap().entries.map((mapEntry) {
                                      final idx = mapEntry.key;
                                      final entry = mapEntry.value;
                                      final isCancelled = !entry.isActive;
                                      final entryColor = isCancelled ? sem.cancelled : _subjectColor(entry.subject, context);

                                      Widget content = Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: entryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(AppRadius.md),
                                            ),
                                            child: Icon(
                                              isCancelled
                                                  ? Icons.cancel_rounded
                                                  : _subjectIcon(entry.subject),
                                              color: entryColor,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.lg),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        entry.displaySubject,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 17,
                                                          fontWeight: FontWeight.w700,
                                                          color: isCancelled
                                                              ? sem.cancelled
                                                              : colorScheme.onSurface,
                                                          decoration: isCancelled
                                                              ? TextDecoration.lineThrough
                                                              : null,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isCancelled)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: AppSpacing.sm,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: sem.cancelled.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(AppRadius.full),
                                                        ),
                                                        child: Text(
                                                          'CANCELLED',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w800,
                                                            letterSpacing: 0.8,
                                                            color: sem.cancelled,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: AppSpacing.sm),
                                                Wrap(
                                                  spacing: AppSpacing.md,
                                                  runSpacing: AppSpacing.sm,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.access_time_rounded,
                                                          size: 13,
                                                          color: sem.onSurfaceMuted,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          TimetableManager.formatTime(entry.startTime, entry.endTime),
                                                          style: GoogleFonts.inter(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: sem.onSurfaceMuted,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (entry.room != null && entry.room!.isNotEmpty)
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.room_rounded,
                                                            size: 13,
                                                            color: sem.onSurfaceMuted,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Room ${entry.room}',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w600,
                                                              color: sem.onSurfaceMuted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    if (entry.batch != 'Whole Class')
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.group_rounded,
                                                            size: 13,
                                                            color: sem.onSurfaceMuted,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            entry.batch,
                                                            style: GoogleFonts.inter(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w600,
                                                              color: sem.onSurfaceMuted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_canEdit(entry) && entries.length > 1)
                                            Padding(
                                              padding: const EdgeInsets.only(left: AppSpacing.sm),
                                              child: Icon(
                                                Icons.more_vert_rounded,
                                                size: 18,
                                                color: sem.onSurfaceMuted.withValues(alpha: 0.4),
                                              ),
                                            ),
                                        ],
                                      );

                                      if (entries.length > 1) {
                                        return GestureDetector(
                                          onLongPress: _canEdit(entry) ? () => _editLecture(entry) : null,
                                          child: Container(
                                            margin: EdgeInsets.only(top: idx == 0 ? 0 : AppSpacing.md),
                                            padding: const EdgeInsets.all(AppSpacing.sm),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
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
                        );
                      },
                    ),
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
