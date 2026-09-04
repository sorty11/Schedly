import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'widgets/timetable_studio_sheet.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'theme/theme.dart';

import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'services/permission_service.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'widgets/animations/skeleton_components.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'upload_timetable_pdf_page.dart';
import 'services/local_notification_service.dart';
import 'timetable_manager.dart';
import 'services/history_service.dart';
import 'services/timetable_event_service.dart';
import 'services/timetable_resolver_service.dart';
import 'monthly_timetable_page.dart';

class WeeklyTimetablePage extends StatefulWidget {
  final String division;
  final bool isEditMode;

  const WeeklyTimetablePage({
    super.key,
    required this.division,
    this.isEditMode = false,
  });

  @override
  State<WeeklyTimetablePage> createState() => _WeeklyTimetablePageState();
}

class _WeeklyTimetablePageState extends State<WeeklyTimetablePage> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
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

  String _getTargetDateStr(String dayName) {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final targetWeekday = days.indexOf(dayName) + 1;
    int daysToAdd = targetWeekday - now.weekday;
    if (daysToAdd < 0) daysToAdd += 7;
    final targetDate = now.add(Duration(days: daysToAdd));
    return '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
  }

  Color _subjectColor(
    String subject,
    BuildContext context, {
    String? component,
  }) {
    return AppTheme.lectureTypeColor(
      context,
      subject: subject,
      component: component,
    );
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
    final isCR = AppSettings.currentRole == UserRole.cr;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        final sem = Theme.of(ctx).extension<AppSemanticColors>()!;
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sem.borderSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x2l,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  entry.displaySubject,
                  style: Theme.of(ctx).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.edit_rounded, size: 18, color: cs.primary),
                ),
                title: const Text('Edit Lecture'),
                onTap: () {
                  Navigator.pop(ctx);
                  TimetableStudioSheet.show(
                    context,
                    division: widget.division,
                    initialDay: selectedDay,
                    existingEntry: entry,
                  );
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.find_replace_rounded,
                    size: 18,
                    color: cs.secondary,
                  ),
                ),
                title: const Text('Replace Lecture'),
                onTap: () {
                  Navigator.pop(ctx);
                  // "Replace" does the same as "Edit" since it allows changing all fields without deleting
                  TimetableStudioSheet.show(
                    context,
                    division: widget.division,
                    initialDay: selectedDay,
                    existingEntry: entry,
                  );
                },
              ),
              if (entry.isActive)
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sem.cancelled.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.cancel_outlined,
                      size: 18,
                      color: sem.cancelled,
                    ),
                  ),
                  title: Text(
                    'Cancel Lecture',
                    style: TextStyle(color: sem.cancelled),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await FirebaseFirestore.instance
                        .collection('timetables')
                        .doc(widget.division)
                        .collection(selectedDay)
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
                          '${entry.displaySubject} on $selectedDay at $timeStr',
                      role: AppSettings.currentRole.name,
                    );

                    await TimetableEventService.handleModification(
                      division: widget.division,
                      day: selectedDay,
                      oldEntry: entry,
                      isCancel: true,
                    );
                  },
                )
              else
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sem.conducted.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: sem.conducted,
                    ),
                  ),
                  title: Text(
                    'Restore Lecture',
                    style: TextStyle(color: sem.conducted),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await FirebaseFirestore.instance
                        .collection('timetables')
                        .doc(widget.division)
                        .collection(selectedDay)
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
                          '${entry.displaySubject} on $selectedDay at $timeStr',
                      role: AppSettings.currentRole.name,
                    );

                    await TimetableEventService.handleModification(
                      division: widget.division,
                      day: selectedDay,
                      oldEntry: entry,
                      isRestore: true,
                    );
                  },
                ),
              if (isCR)
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sem.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.delete_rounded,
                      size: 18,
                      color: sem.error,
                    ),
                  ),
                  title: Text(
                    'Delete Lecture',
                    style: TextStyle(color: sem.error),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await FirebaseFirestore.instance
                        .collection('timetables')
                        .doc(widget.division)
                        .collection(selectedDay)
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
                          '${entry.displaySubject} on $selectedDay at $timeStr',
                      role: AppSettings.currentRole.name,
                    );

                    await TimetableEventService.handleModification(
                      division: widget.division,
                      day: selectedDay,
                      oldEntry: entry,
                      isDelete: true,
                    );
                  },
                ),
              SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
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
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x2l,
                AppSpacing.lg,
                AppSpacing.x2l,
                AppSpacing.sm,
              ),
              child: widget.isEditMode
                  ? Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        Text(
                          'Select Lecture',
                          style: Theme.of(context).appBarTheme.titleTextStyle,
                        ),
                      ],
                    )
                  : ThemedTimetableHeader(
                      title: 'Timetable',
                      subtitle: 'Your schedule for the week',
                      onCalendarTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MonthlyTimetablePage(division: widget.division),
                          ),
                        );
                      },
                      onEditModeToggle:
                          (AppSettings.currentRole == UserRole.cr ||
                              AppSettings.currentRole == UserRole.sr)
                          ? () {}
                          : null,
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
                decoration: BoxDecoration(
                  color: isDark ? sem.surfaceElevated : colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? sem.borderSubtle
                          : sem.borderSubtle.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: ThemedDaySelector(
                        days: _dayShort,
                        selectedIndex: selectedIndex,
                        todayIndex: todayIndex,
                        onDaySelected: (index) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            selectedIndex = index;
                            selectedDay = _days[index];
                          });
                        },
                      ),
                    ),
                  ),
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
                    return const TimetableSkeleton();
                  }

                  final targetDateStr = _getTargetDateStr(selectedDay);

                  final userBatch = AppSettings.currentRole == UserRole.student
                      ? AppSettings.studentBatch
                      : null;
                  final rawEntries = snapshot.data!.docs
                      .map((doc) => TimetableEntry.fromFirestore(doc))
                      .toList();

                  final resolved = TimetableResolverService.resolve(
                    rawEntries: rawEntries,
                    targetDateStr: targetDateStr,
                    userBatch: userBatch,
                    isEditMode: widget.isEditMode,
                  );

                  if (resolved.isHoliday) {
                    return AnimatedSwitcher(
                      duration: AppDuration.enter,
                      child: FloatingEmptyState(
                        key: ValueKey(selectedDay),
                        icon: Icons.celebration_rounded,
                        title: 'Holiday',
                        subtitle: resolved.holidayName ?? 'No classes today.',
                      ),
                    );
                  }

                  final rawLectures = resolved.lectures;

                  if (rawLectures.isEmpty) {
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.x6l,
                      ),
                      itemCount: groupedLectures.length,
                      itemBuilder: (context, index) {
                        final entries = groupedLectures[index];
                        final allCancelled = entries.every((e) => !e.isActive);
                        final activeEntry = entries.firstWhere(
                          (e) => e.isActive,
                          orElse: () => entries.first,
                        );
                        final subjectColor = allCancelled
                            ? sem.cancelled
                            : _subjectColor(
                                activeEntry.subject,
                                context,
                                component: activeEntry.component,
                              );

                        return StaggeredListItem(
                          index: index,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.md),
                            child: ThemedLectureCard(
                              entries: entries,
                              isEditMode: widget.isEditMode,
                              canEditEntry: _canEdit,
                              onTap:
                                  (widget.isEditMode &&
                                      entries.length == 1 &&
                                      _canEdit(entries.first))
                                  ? () => _editLecture(entries.first)
                                  : null,
                              onLongPress:
                                  (!widget.isEditMode &&
                                      entries.length == 1 &&
                                      _canEdit(entries.first))
                                  ? () => _editLecture(entries.first)
                                  : null,
                              onEntryTap: (entry) {
                                if (widget.isEditMode && _canEdit(entry)) {
                                  _editLecture(entry);
                                }
                              },
                              onEntryLongPress: (entry) {
                                if (!widget.isEditMode && _canEdit(entry)) {
                                  _editLecture(entry);
                                }
                              },
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
