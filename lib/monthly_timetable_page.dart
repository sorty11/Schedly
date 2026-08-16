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

import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';

class MonthlyTimetablePage extends StatefulWidget {
  final String division;
  const MonthlyTimetablePage({super.key, required this.division});

  @override
  State<MonthlyTimetablePage> createState() => _MonthlyTimetablePageState();
}

class _MonthlyTimetablePageState extends State<MonthlyTimetablePage> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  Map<String, List<TimetableEntry>> _rawTimetables = {};

  @override
  void initState() {
    super.initState();
    _loadAllTimetables();
  }

  Future<void> _loadAllTimetables() async {
    setState(() => _isLoading = true);
    try {
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final Map<String, List<TimetableEntry>> loaded = {};
      
      await Future.wait(days.map((day) async {
        final snap = await FirebaseFirestore.instance
            .collection('timetables')
            .doc(widget.division)
            .collection(day)
            .get();
        loaded[day] = snap.docs.map((d) => TimetableEntry.fromFirestore(d)).toList();
      }));

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
    
    final userBatch = AppSettings.currentRole == UserRole.student ? AppSettings.studentBatch : null;
    
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
  
  Future<void> _removeHoliday(DateTime date, TimetableEntry holidayEntry) async {
    final dayName = DateFormat('EEEE').format(date);
    await FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(dayName)
        .doc(holidayEntry.id)
        .delete();
    _loadAllTimetables();
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
  
  IconData _subjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return Icons.calculate_rounded;
      case 'programming':
      case 'oop':
      case 'java':
        return Icons.computer_rounded;
      case 'beee':
        return Icons.electrical_services_rounded;
      case 'physics':
        return Icons.science_rounded;
      case 'chemistry':
        return Icons.biotech_rounded;
      case 'dbms':
        return Icons.storage_rounded;
      case 'lade':
        return Icons.menu_book_rounded;
      case 'ctps':
        return Icons.lightbulb_rounded;
      case 'lunch break':
      case 'lunch':
        return Icons.restaurant_rounded;
      default:
        return Icons.book_rounded;
    }
  }

  Widget _buildCalendarGrid(AppSemanticColors sem, ColorScheme colorScheme) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;

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
      final isSelected = d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day;
      final isToday = d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day;
      
      final resolved = _resolveForDate(d);
      
      bool hasExtra = false;
      bool hasReplacement = false;
      bool hasCancel = false;
      
      if (!resolved.isHoliday) {
        final rawDay = _rawTimetables[DateFormat('EEEE').format(d)] ?? [];
        for (var e in rawDay) {
          if (e.validForDate == _formatDateStr(d)) {
            if (e.isCancelled) hasCancel = true;
            else if (e.hiddenOnDates.isNotEmpty) hasReplacement = true;
            else hasExtra = true;
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
                  : (isToday ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: resolved.isHoliday ? Border.all(color: colorScheme.secondary.withValues(alpha: 0.5), width: 1.5) : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    i.toString(),
                    style: GoogleFonts.inter(
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colorScheme.onPrimary : (isToday ? colorScheme.primary : Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  if (hasExtra || hasCancel || hasReplacement)
                    Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasExtra) _indicatorDot(colorScheme.primary),
                          if (hasReplacement) _indicatorDot(colorScheme.tertiary),
                          if (hasCancel) _indicatorDot(sem.cancelled),
                        ],
                      ),
                    )
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
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
      appBar: AppBar(
        title: Text(
          'Monthly Overview',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Calendar Area
                Container(
                  color: isDark ? sem.surfaceElevated : colorScheme.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2l,
                    vertical: AppSpacing.lg,
                  ),
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
                
                // Date Header & Inline Actions
                Container(
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
                              final holiday = rawDay.firstWhere((e) => e.isHoliday && e.validForDate == dateStr);
                              _removeHoliday(_selectedDate, holiday);
                            },
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                            label: const Text('Remove Holiday'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: sem.error,
                              side: BorderSide(color: sem.error.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                  ),
                                ),
                                if (isCR) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  OutlinedButton.icon(
                                    onPressed: () => _declareHoliday(_selectedDate),
                                    icon: const Icon(Icons.celebration_rounded, size: 18),
                                    label: const Text('Declare Holiday'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colorScheme.secondary,
                                      side: BorderSide(color: colorScheme.secondary.withValues(alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                
                // Lectures Area
                Expanded(
                  child: isSelectedHoliday
                    ? FloatingEmptyState(
                        icon: Icons.celebration_rounded,
                        title: 'Holiday',
                        subtitle: resolvedToday!.holidayName ?? 'No classes scheduled.',
                      )
                    : groupedLectures.isEmpty
                      ? FloatingEmptyState(
                          icon: Icons.event_available_rounded,
                          title: 'No lectures scheduled',
                          subtitle: 'Enjoy your free day!',
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
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
                                : _subjectColor(activeEntry.subject, context);

                            return StaggeredListItem(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: AnimatedCard(
                                  borderRadius: AppRadius.xl,
                                  backgroundColor: allCancelled
                                      ? sem.cancelled.withValues(alpha: 0.05)
                                      : isDark
                                      ? sem.surfaceElevated
                                      : colorScheme.surface,
                                  onTap: (canEdit && entries.length == 1)
                                      ? () => _openStudio(_selectedDate, existingEntry: entries.first)
                                      : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.xl),
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
                                          final entry = mapEntry.value;
                                          final isCancelled = !entry.isActive;
                                          final entryColor = isCancelled
                                              ? sem.cancelled
                                              : _subjectColor(entry.subject, context);

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
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          TimetableManager.formatTime(entry.startTime, entry.endTime),
                                                          style: GoogleFonts.inter(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: isCancelled
                                                                ? sem.cancelled.withValues(alpha: 0.7)
                                                                : colorScheme.primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      isCancelled
                                                          ? 'CANCELLED'
                                                          : [
                                                              entry.room,
                                                              if (entry.component.isNotEmpty) entry.component,
                                                              if (entry.batch != 'Whole Class') entry.batch,
                                                            ].where((e) => e != null && e.isNotEmpty).join(' • '),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: isCancelled
                                                            ? sem.cancelled.withValues(alpha: 0.7)
                                                            : sem.onSurfaceMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );

                                          if (mapEntry.key > 0) {
                                            content = Padding(
                                              padding: const EdgeInsets.only(top: AppSpacing.lg),
                                              child: content,
                                            );
                                          }
                                          return content;
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
