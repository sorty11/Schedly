import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'theme/theme.dart';
import 'models/timetable_entry.dart';
import 'services/timetable_resolver_service.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'widgets/timetable_studio_sheet.dart';
import 'timetable_manager.dart';
import 'models/event_category.dart';
import 'services/timetable_event_service.dart';

import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'onboarding/widgets/tutorial_target.dart';
import 'onboarding/services/feature_discovery_service.dart';

class MonthlyTimetablePage extends StatefulWidget {
  final String division;
  const MonthlyTimetablePage({super.key, required this.division});

  @override
  State<MonthlyTimetablePage> createState() => _MonthlyTimetablePageState();
}

class _MonthlyTimetablePageState extends State<MonthlyTimetablePage> {
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  Map<String, List<TimetableEntry>> _rawTimetables = {};

  @override
  void initState() {
    super.initState();
    _loadAllTimetables();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FeatureDiscoveryService.checkMonthlyTimetableDiscovery(context);
    });
  }

  Future<void> _loadAllTimetables() async {
    setState(() => _isLoading = true);
    try {
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final Map<String, List<TimetableEntry>> loaded = {};

      await Future.wait(
        days.map((day) async {
          final snap = await FirebaseFirestore.instance
              .collection('timetables')
              .doc(widget.division)
              .collection(day)
              .get();
          loaded[day] = snap.docs
              .map((d) => TimetableEntry.fromFirestore(d))
              .toList();
        }),
      );

      if (mounted) {
        setState(() {
          _rawTimetables = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  ResolvedTimetable _resolveForDate(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    final rawEntries = _rawTimetables[dayName] ?? [];

    final userBatch = AppSettings.currentRole == UserRole.student
        ? AppSettings.studentBatch
        : null;

    return TimetableResolverService.resolve(
      rawEntries: rawEntries,
      targetDateStr: _formatDateStr(date),
      userBatch: userBatch,
    );
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _openStudio(DateTime date, {TimetableEntry? existingEntry}) async {
    final dayName = DateFormat('EEEE').format(date);
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimetableStudioSheet(
        division: widget.division,
        initialDay: dayName,
        existingEntry: existingEntry,
        targetDateForOverride: date,
      ),
    );
    if (result == true) {
      _loadAllTimetables();
    }
  }

  Future<void> _declareHoliday(DateTime date) async {
    final dayName = DateFormat('EEEE').format(date);
    final dateStr = _formatDateStr(date);

    final holidayEntry = TimetableEntry(
      id: FirebaseFirestore.instance.collection('timetables').doc().id,
      subject: 'Holiday',
      category: EventCategory.holiday,
      batch: 'Whole Class',
      startTime: 0,
      endTime: 1440,
      durationMinutes: 1440,
      status: 'holiday',
      validForDate: dateStr,
      hiddenOnDates: const [],
    );

    await TimetableManager.addLecture(
      division: widget.division,
      day: dayName,
      entry: holidayEntry,
    );
    _loadAllTimetables();
  }

  Future<void> _removeHoliday(
    DateTime date,
    TimetableEntry holidayEntry,
  ) async {
    final dayName = DateFormat('EEEE').format(date);
    await FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(dayName)
        .doc(holidayEntry.id)
        .delete()
        .timeout(const Duration(seconds: 3), onTimeout: () => null);

    TimetableEventService.handleModification(
      division: widget.division,
      day: dayName,
      oldEntry: holidayEntry,
      newEntry: null,
      isDelete: true,
    ).catchError((_) {});

    _loadAllTimetables();
  }

  Widget _buildCalendarGrid(AppSemanticColors sem, ColorScheme colorScheme) {
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstDayWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday;

    List<Widget> dayWidgets = [];
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    for (var w in weekDays) {
      dayWidgets.add(
        Center(
          child: Text(
            w,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: sem.onSurfaceMuted,
            ),
          ),
        ),
      );
    }

    for (int i = 1; i < firstDayWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    for (int i = 1; i <= daysInMonth; i++) {
      final d = DateTime(_currentMonth.year, _currentMonth.month, i);
      final isSelected =
          d.year == _selectedDate.year &&
          d.month == _selectedDate.month &&
          d.day == _selectedDate.day;
      final isToday =
          d.year == DateTime.now().year &&
          d.month == DateTime.now().month &&
          d.day == DateTime.now().day;

      final resolved = _resolveForDate(d);

      bool hasExtra = false;
      bool hasReplacement = false;
      bool hasCancel = false;

      if (!resolved.isHoliday) {
        final rawDay = _rawTimetables[DateFormat('EEEE').format(d)] ?? [];
        for (var e in rawDay) {
          if (e.validForDate == _formatDateStr(d)) {
            if (e.isCancelled)
              hasCancel = true;
            else if (e.hiddenOnDates.isNotEmpty)
              hasReplacement = true;
            else
              hasExtra = true;
          }
        }
      }

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDate = d;
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : (isToday
                          ? colorScheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: resolved.isHoliday
                    ? Border.all(
                        color: colorScheme.secondary.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    i.toString(),
                    style: GoogleFonts.inter(
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : (isToday
                                ? colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  if (hasExtra || hasCancel || hasReplacement)
                    Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasExtra) _indicatorDot(colorScheme.primary),
                          if (hasReplacement)
                            _indicatorDot(colorScheme.tertiary),
                          if (hasCancel) _indicatorDot(sem.cancelled),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.0,
      children: dayWidgets,
    );
  }

  Widget _indicatorDot(Color color) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    final resolvedToday = _isLoading ? null : _resolveForDate(_selectedDate);
    final isCR = AppSettings.currentRole == UserRole.cr;
    final isSR = AppSettings.currentRole == UserRole.sr;
    final canEdit = isCR || isSR;

    final isSelectedHoliday = resolvedToday?.isHoliday ?? false;

    // Build grouped lectures just like WeeklyTimetablePage
    List<List<TimetableEntry>> groupedLectures = [];
    if (resolvedToday != null && !isSelectedHoliday) {
      final Map<int, List<TimetableEntry>> grouped = {};
      for (final e in resolvedToday.lectures) {
        if (!grouped.containsKey(e.startTime)) {
          grouped[e.startTime] = [];
        }
        grouped[e.startTime]!.add(e);
      }
      final sortedKeys = grouped.keys.toList()..sort();
      groupedLectures = sortedKeys.map((k) => grouped[k]!).toList();
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final gridPadding = AppSpacing.x2l * 2;
                final cellWidth = (availableWidth - gridPadding) / 7.0;

                final firstDayWeekday = DateTime(
                  _currentMonth.year,
                  _currentMonth.month,
                  1,
                ).weekday;
                final daysInMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                  0,
                ).day;
                final totalCells = (firstDayWeekday - 1) + daysInMonth;
                final dateRows = (totalCells / 7).ceil();

                final calendarAreaHeight = 92.0 + ((1 + dateRows) * cellWidth);
                final safeAreaTop = MediaQuery.of(context).padding.top;
                final dhHeight = canEdit ? 120.0 : 68.0;

                final expandedHeight =
                    safeAreaTop +
                    kToolbarHeight +
                    calendarAreaHeight +
                    dhHeight;
                final collapsedHeight = safeAreaTop + kToolbarHeight + dhHeight;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _MonthlyHeaderDelegate(
                        expandedHeight: expandedHeight,
                        collapsedHeight: collapsedHeight,
                        safeAreaTop: safeAreaTop,
                        dateHeaderHeight: dhHeight,
                        currentMonth: _currentMonth,
                        selectedDate: _selectedDate,
                        onPrevMonth: _prevMonth,
                        onNextMonth: _nextMonth,
                        onToday: () {
                          setState(() => _selectedDate = DateTime.now());
                        },
                        isDark: isDark,
                        sem: sem,
                        colorScheme: colorScheme,
                        calendarArea: _buildCalendarArea(sem, colorScheme),
                        dateHeader: _buildDateHeader(
                          canEdit,
                          isSelectedHoliday,
                          sem,
                          colorScheme,
                          dhHeight,
                        ),
                      ),
                    ),
                    if (isSelectedHoliday)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: FloatingEmptyState(
                          icon: Icons.celebration_rounded,
                          title: 'Holiday',
                          subtitle:
                              resolvedToday!.holidayName ??
                              'No classes scheduled.',
                        ),
                      )
                    else if (groupedLectures.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: FloatingEmptyState(
                          icon: Icons.event_available_rounded,
                          title: 'No lectures scheduled',
                          subtitle: 'Enjoy your free day!',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.x6l,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final entries = groupedLectures[index];

                            return StaggeredListItem(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: ThemedLectureCard(
                                  entries: entries,
                                  isEditMode: canEdit,
                                  canEditEntry: (e) => canEdit,
                                  onTap: (canEdit && entries.length == 1)
                                      ? () => _openStudio(
                                          _selectedDate,
                                          existingEntry: entries.first,
                                        )
                                      : null,
                                  onEntryTap: (e) {
                                    if (canEdit) {
                                      _openStudio(
                                        _selectedDate,
                                        existingEntry: e,
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          }, childCount: groupedLectures.length),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCalendarArea(AppSemanticColors sem, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2l,
        vertical: AppSpacing.lg,
      ),
      child: TutorialTarget(
        id: 'monthly_calendar_view',
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _prevMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildCalendarGrid(sem, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(
    bool canEdit,
    bool isSelectedHoliday,
    AppSemanticColors sem,
    ColorScheme colorScheme,
    double height,
  ) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x2l,
        AppSpacing.xl,
        AppSpacing.x2l,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: sem.borderSubtle.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM').format(_selectedDate),
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.md),
            if (isSelectedHoliday)
              OutlinedButton.icon(
                onPressed: () {
                  final dayName = DateFormat('EEEE').format(_selectedDate);
                  final dateStr = _formatDateStr(_selectedDate);
                  final rawDay = _rawTimetables[dayName] ?? [];
                  final holiday = rawDay.firstWhere(
                    (e) => e.isHoliday && e.validForDate == dateStr,
                  );
                  _removeHoliday(_selectedDate, holiday);
                },
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: const Text('Remove Holiday'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: sem.error,
                  side: BorderSide(color: sem.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openStudio(_selectedDate),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add / Modify'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                      ),
                    ),
                    if (AppSettings.currentRole == UserRole.cr) ...[
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => _declareHoliday(_selectedDate),
                        icon: const Icon(Icons.celebration_rounded, size: 18),
                        label: const Text('Declare Holiday'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.secondary,
                          side: BorderSide(
                            color: colorScheme.secondary.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double expandedHeight;
  final double collapsedHeight;
  final double safeAreaTop;
  final double dateHeaderHeight;
  final Widget calendarArea;
  final Widget dateHeader;
  final DateTime currentMonth;
  final DateTime selectedDate;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final bool isDark;
  final AppSemanticColors sem;
  final ColorScheme colorScheme;

  _MonthlyHeaderDelegate({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.safeAreaTop,
    required this.dateHeaderHeight,
    required this.calendarArea,
    required this.dateHeader,
    required this.currentMonth,
    required this.selectedDate,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.isDark,
    required this.sem,
    required this.colorScheme,
  });

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant _MonthlyHeaderDelegate old) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double progress = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );

    return Container(
      color: isDark ? sem.surfaceElevated : colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Calendar Area (Fades and scrolls up)
          Positioned(
            top:
                safeAreaTop +
                kToolbarHeight -
                (shrinkOffset * 0.8), // Parallax effect
            left: 0,
            right: 0,
            child: Opacity(
              opacity: (1.0 - (progress * 2)).clamp(0.0, 1.0),
              child: calendarArea,
            ),
          ),

          // Top Bar (Cross-fades between Title and Compact Header)
          Positioned(
            top: safeAreaTop,
            left: 0,
            right: 0,
            height: kToolbarHeight,
            child: Stack(
              children: [
                // Expanded Title
                Opacity(
                  opacity: (1.0 - (progress * 2)).clamp(0.0, 1.0),
                  child: Center(
                    child: Text(
                      'Monthly Overview',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                // Collapsed Compact Header
                Opacity(
                  opacity: ((progress - 0.5) * 2).clamp(0.0, 1.0),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: onPrevMonth,
                        ),
                        GestureDetector(
                          onTap: onToday,
                          child: Text(
                            '${DateFormat('MMM yyyy').format(currentMonth)}  •  ${DateFormat('d EEE').format(selectedDate)}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: onNextMonth,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date Header & Actions (Pinned at bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: dateHeaderHeight,
            child: dateHeader,
          ),
        ],
      ),
    );
  }
}
