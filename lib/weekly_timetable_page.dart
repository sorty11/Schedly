import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'widgets/timetable_studio_sheet.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'services/app_notification_service.dart';
import 'theme/theme.dart';

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
    await TimetableStudioSheet.show(
      context,
      division: widget.division,
      initialDay: selectedDay,
      existingEntry: entry,
    );
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
