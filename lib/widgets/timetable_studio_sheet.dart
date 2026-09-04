import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../theme/theme.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import '../timetable_manager.dart';
import '../app_settings.dart';
import '../user_roles.dart';
import '../services/history_service.dart';
import '../services/timetable_event_service.dart';
import '../services/permission_service.dart';
import 'app_dialogs.dart';
import 'schedly_text_field.dart';
import 'schedly_bottom_sheet.dart';

class TimetableStudioSheet extends StatefulWidget {
  final String division;
  final String initialDay;
  final TimetableEntry? existingEntry;
  final TimetableEntry? duplicateFrom;
  final DateTime? targetDateForOverride;

  const TimetableStudioSheet({
    super.key,
    required this.division,
    required this.initialDay,
    this.existingEntry,
    this.duplicateFrom,
    this.targetDateForOverride,
  });

  static Future<void> show(
    BuildContext context, {
    required String division,
    required String initialDay,
    TimetableEntry? existingEntry,
    TimetableEntry? duplicateFrom,
    DateTime? targetDateForOverride,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimetableStudioSheet(
        division: division,
        initialDay: initialDay,
        existingEntry: existingEntry,
        duplicateFrom: duplicateFrom,
        targetDateForOverride: targetDateForOverride,
      ),
    );
  }

  @override
  State<TimetableStudioSheet> createState() => _TimetableStudioSheetState();
}

class _TimetableStudioSheetState extends State<TimetableStudioSheet> {
  late String _selectedDay;
  late String _subject;
  late String _batch;
  late String _component;
  late EventCategory _category;
  late String _room;
  late int _startTime;
  late int _endTime;
  bool _repeatWeekly = true;

  bool _isLoading = false;

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  FocusNode? _subjectFocusNode;

  static String? _lastSubject;
  static String? _lastBatch;
  static String? _lastComponent;
  static EventCategory? _lastCategory;
  static String? _lastRoom;

  List<String> _availableSubjects = [];
  List<String> _availableRooms = [];

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  List<String> get _batchOptions {
    final l = _divLetter;
    final baseOptions = l.isEmpty
        ? ['Whole Class', 'Batch 1', 'Batch 2']
        : ['Whole Class', '${l}1', '${l}2'];

    // Inject current _batch if it's a legacy name not in the generated list
    // This prevents DropdownButton assertions during migration edge cases.
    if (_batch.isNotEmpty && !baseOptions.contains(_batch)) {
      baseOptions.add(_batch);
    }
    return baseOptions.toSet().toList(); // Ensure unique values
  }

  String get _divLetter {
    if (widget.division.isEmpty) return '';
    final last = widget.division.trim().characters.last.toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(last) ? last : '';
  }

  @override
  void initState() {
    super.initState();
    _initFields();
    _fetchMetadata();
  }

  void _initFields() {
    _selectedDay = widget.initialDay;

    if (widget.existingEntry != null) {
      final entry = widget.existingEntry!;
      _subject = entry.subject;
      _batch = entry.batch;
      _component = entry.component;
      _category = entry.category;
      _room = entry.room ?? '';
      _startTime = entry.startTime;
      _endTime = entry.endTime;
      _repeatWeekly = widget.targetDateForOverride == null
          ? (entry.validForDate == null)
          : false;
    } else if (widget.duplicateFrom != null) {
      final entry = widget.duplicateFrom!;
      _subject = entry.subject;
      _batch = entry.batch;
      _component = entry.component;
      _category = entry.category;
      _room = entry.room ?? '';
      _startTime = entry.startTime;
      _endTime = entry.endTime;
      _repeatWeekly = widget.targetDateForOverride == null
          ? (entry.validForDate == null)
          : false;
    } else {
      final isSR = AppSettings.currentRole == UserRole.sr;
      _subject = _lastSubject ?? (isSR ? (AppSettings.srSubject ?? '') : '');
      _batch =
          _lastBatch ??
          (isSR ? (AppSettings.srBatch ?? 'Whole Class') : 'Whole Class');
      _component =
          _lastComponent ??
          (isSR ? (AppSettings.srComponent ?? 'Theory') : 'Theory');
      _category = _lastCategory ?? EventCategory.academic;
      _room = _lastRoom ?? '';
      _startTime = 9 * 60;
      _endTime = _startTime + 60;
      _repeatWeekly = widget.targetDateForOverride == null;
    }

    _subjectController.text = _subject;
    _roomController.text = _room;
  }

  Future<void> _fetchMetadata() async {
    final subjects = await TimetableManager.getUniqueSubjects(
      division: widget.division,
    );
    if (AppSettings.currentRole == UserRole.sr &&
        AppSettings.srSubject != null &&
        AppSettings.srSubject!.trim().isNotEmpty) {
      final srSubj = AppSettings.srSubject!.trim();
      if (!subjects.contains(srSubj)) {
        subjects.add(srSubj);
      }
    }

    final Set<String> rooms = {};
    for (final day in _days) {
      final entries = await TimetableManager.getEntriesForDay(
        division: widget.division,
        day: day,
      );
      for (final e in entries) {
        if (e.room != null && e.room!.trim().isNotEmpty) {
          rooms.add(e.room!.trim());
        }
      }
    }

    if (mounted) {
      setState(() {
        _availableSubjects = subjects;
        _availableRooms = rooms.toList()..sort();
      });
    }
  }

  void _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startTime ~/ 60, minute: _startTime % 60),
      initialEntryMode: TimePickerEntryMode.dial,
    );

    if (time != null) {
      setState(() {
        _startTime = time.hour * 60 + time.minute;
        _endTime = _startTime + 60;
      });
    }
  }

  void _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _endTime ~/ 60, minute: _endTime % 60),
      initialEntryMode: TimePickerEntryMode.dial,
    );

    if (time != null) {
      setState(() {
        _endTime = time.hour * 60 + time.minute;
      });
    }
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
    if (daysToAdd < 0) daysToAdd += 7; // Next occurrence
    final targetDate = now.add(Duration(days: daysToAdd));
    return '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save({required bool keepOpen}) async {
    final rawSubject = _subjectController.text.trim();
    final room = _roomController.text.trim();

    if (rawSubject.isEmpty) {
      _subjectFocusNode?.requestFocus();
      AppDialogs.showError(
        context: context,
        title: 'Missing Subject',
        message: 'Please enter or select a subject before saving.',
      );
      return;
    }
    if (_endTime <= _startTime) {
      AppDialogs.showError(
        context: context,
        title: 'Invalid Time',
        message: 'End time must be after the start time.',
      );
      return;
    }

    // Always strip component suffixes to get the canonical subject code
    final subject = TimetableEntry.stripComponentSuffix(rawSubject);

    setState(() => _isLoading = true);

    try {
      final isEditing = widget.existingEntry != null;
      final bool wasOneOff =
          isEditing && widget.existingEntry!.validForDate != null;

      String? targetDateStr;
      if (!_repeatWeekly) {
        if (widget.targetDateForOverride != null) {
          targetDateStr = DateFormat(
            'yyyy-MM-dd',
          ).format(widget.targetDateForOverride!);
        } else if (wasOneOff && _selectedDay == widget.initialDay) {
          targetDateStr = widget.existingEntry!.validForDate;
        } else {
          targetDateStr = _getTargetDateStr(_selectedDay);
        }
      }

      // If replacing a RECURRING lecture with a ONE-OFF lecture:
      final bool replacingRecurringWithOneOff =
          isEditing && !wasOneOff && !_repeatWeekly;

      final entryId = replacingRecurringWithOneOff
          ? FirebaseFirestore.instance.collection('timetables').doc().id
          : (widget.existingEntry?.id ??
                FirebaseFirestore.instance.collection('timetables').doc().id);

      // Auto-populate facultyId if a mapping exists in faculty_profiles
      final facultyMap = await TimetableManager.getSubjectToFacultyIdMap(
        widget.division,
      );
      final mappedFacultyId = facultyMap[subject];

      final entry = TimetableEntry(
        id: entryId,
        subject: subject,
        component: _component,
        category: _category,
        batch: _batch,
        startTime: _startTime,
        endTime: _endTime,
        durationMinutes: _endTime - _startTime,
        room: room.isEmpty ? null : room,
        status: 'active',
        facultyId: mappedFacultyId,
        validForDate: targetDateStr,
        hiddenOnDates: replacingRecurringWithOneOff
            ? []
            : (widget.existingEntry?.hiddenOnDates ?? []),
      );

      if (replacingRecurringWithOneOff) {
        // Compute the date on which the original recurring lecture should be hidden.
        String originalDateStr;
        if (widget.targetDateForOverride != null) {
          originalDateStr = DateFormat(
            'yyyy-MM-dd',
          ).format(widget.targetDateForOverride!);
        } else {
          originalDateStr = _getTargetDateStr(widget.initialDay);
        }

        // Hide original recurring lecture on this date
        final oldEntry = widget.existingEntry!;
        final updatedHiddenDates = List<String>.from(oldEntry.hiddenOnDates)
          ..add(originalDateStr);
        await FirebaseFirestore.instance
            .collection('timetables')
            .doc(widget.division)
            .collection(widget.initialDay)
            .doc(oldEntry.id)
            .update({'hiddenOnDates': updatedHiddenDates});

        // Create the new one-off lecture
        await TimetableManager.addLecture(
          division: widget.division,
          day: _selectedDay,
          entry: entry,
          oldEntry: oldEntry, // Ignore overlap with oldEntry
        );
      } else {
        if (isEditing && widget.initialDay != _selectedDay) {
          await FirebaseFirestore.instance
              .collection('timetables')
              .doc(widget.division)
              .collection(widget.initialDay)
              .doc(entryId)
              .delete();
        }

        await TimetableManager.addLecture(
          division: widget.division,
          day: _selectedDay,
          entry: entry,
          oldEntry: widget.existingEntry,
        );
      }

      final timeStr = TimetableManager.formatTime(
        entry.startTime,
        entry.endTime,
      );
      await HistoryService.logOperation(
        division: widget.division,
        operation: widget.existingEntry != null
            ? 'Lecture Replaced'
            : 'Lecture Added',
        details: '${entry.displaySubject} on $_selectedDay at $timeStr',
        role: AppSettings.currentRole.name,
      );

      _lastSubject = subject;
      _lastBatch = _batch;
      _lastComponent = _component;
      _lastCategory = _category;
      _lastRoom = room;

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      AppDialogs.showSnackBar(
        context: context,
        message: widget.existingEntry != null
            ? 'Lecture updated!'
            : 'Lecture added successfully!',
      );

      if (keepOpen) {
        setState(() {
          _startTime = _endTime;
          _endTime = _startTime + 60;
        });
      } else {
        Navigator.pop(context);
      }
    } on ValidationException catch (e) {
      AppDialogs.showError(
        context: context,
        title: e.title,
        message: e.message,
      );
    } catch (e) {
      AppDialogs.showError(
        context: context,
        title: 'Error',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:${m.toString().padLeft(2, '0')} $suffix';
  }

  // Calculate duration label
  String get _durationLabel {
    final mins = _endTime - _startTime;
    if (mins <= 0) return '';
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Widget _buildSectionLabel(String label) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: sem.onSurfaceMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isEditing = widget.existingEntry != null;
    final isCR = AppSettings.currentRole == UserRole.cr;
    final isSR = AppSettings.currentRole == UserRole.sr;
    final canDelete =
        isCR ||
        (isSR &&
            widget.existingEntry != null &&
            PermissionService.canManageLecture(
              lectureSubject: widget.existingEntry!.subjectCode,
              lectureComponent: widget.existingEntry!.component,
              lectureBatch: widget.existingEntry!.batch,
            ));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SchedlyBottomSheet(
        title: isEditing ? 'Edit Lecture' : 'Add Lecture',
        subtitle: isEditing ? widget.existingEntry!.displaySubject : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2l,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section: Day ─────────────────────────────────────────
            _buildSectionLabel('Day'),
            _DayPillSelector(
              days: _days,
              selected: _selectedDay,
              onSelected: (d) => setState(() => _selectedDay = d),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Section: Lecture Details ──────────────────────────────
            _buildSectionLabel('Lecture Details'),

            Container(
              decoration: BoxDecoration(
                color: isDark ? sem.surfaceElevated2 : colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: sem.borderSubtle),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subject autocomplete
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty)
                        return _availableSubjects;
                      return _availableSubjects.where(
                        (option) => option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text.isEmpty &&
                              _subjectController.text.isNotEmpty) {
                            controller.text = _subjectController.text;
                          }
                          controller.addListener(
                            () => _subjectController.text = controller.text,
                          );
                          _subjectFocusNode = focusNode;
                          return SchedlyTextField(
                            controller: controller,
                            focusNode: focusNode,
                            labelText: 'Subject / Course Code',
                            prefixIcon: Icons.book_rounded,
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Batch + Room
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _batch,
                          decoration: InputDecoration(
                            labelText: 'Batch',
                            prefixIcon: Icon(
                              Icons.groups_rounded,
                              size: 20,
                              color: sem.onSurfaceMuted,
                            ),
                            fillColor: isDark
                                ? sem.surfaceElevated
                                : const Color(0xFFF8F8FC),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: sem.borderFocus,
                                width: 1.5,
                              ),
                            ),
                          ),
                          isExpanded: true,
                          items: _batchOptions
                              .map(
                                (b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(
                                    b,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => _batch = val!),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Autocomplete<String>(
                          optionsBuilder: (tv) {
                            if (tv.text.isEmpty) return _availableRooms;
                            return _availableRooms.where(
                              (option) => option.toLowerCase().contains(
                                tv.text.toLowerCase(),
                              ),
                            );
                          },
                          fieldViewBuilder:
                              (context, controller, focusNode, _) {
                                if (controller.text.isEmpty &&
                                    _roomController.text.isNotEmpty) {
                                  controller.text = _roomController.text;
                                }
                                controller.addListener(
                                  () => _roomController.text = controller.text,
                                );
                                return SchedlyTextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  labelText: 'Room',
                                  prefixIcon: Icons.room_rounded,
                                );
                              },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Lecture type chips
                  Text(
                    'Type',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sem.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _buildTypeChip(
                        'Theory',
                        EventCategory.academic,
                        Icons.auto_stories_rounded,
                      ),
                      _buildTypeChip(
                        'Lab',
                        EventCategory.academic,
                        Icons.science_rounded,
                      ),
                      _buildTypeChip(
                        'Tutorial',
                        EventCategory.academic,
                        Icons.school_rounded,
                      ),
                      _buildTypeChip(
                        'Project',
                        EventCategory.academic,
                        Icons.assignment_rounded,
                      ),
                      _buildTypeChip(
                        'Seminar',
                        EventCategory.academic,
                        Icons.record_voice_over_rounded,
                      ),
                      _buildTypeChip(
                        'Viva',
                        EventCategory.academic,
                        Icons.mic_rounded,
                      ),
                      _buildTypeChip(
                        'Event',
                        EventCategory.event,
                        Icons.celebration_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),

            // ── Section: Timing ────────────────────────────────────────
            _buildSectionLabel('Timing'),
            Row(
              children: [
                Expanded(
                  child: _TimePicker(
                    label: 'Start',
                    time: _formatTime(_startTime),
                    onTap: _selectStartTime,
                    isDark: isDark,
                    sem: sem,
                    colorScheme: colorScheme,
                    isStart: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: sem.onSurfaceMuted,
                      ),
                      if (_durationLabel.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _durationLabel,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sem.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _TimePicker(
                    label: 'End',
                    time: _formatTime(_endTime),
                    onTap: _selectEndTime,
                    isDark: isDark,
                    sem: sem,
                    colorScheme: colorScheme,
                    isStart: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2l),

            // ── Section: Options ──────────────────────────────────────
            _buildSectionLabel('Options'),
            Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  color: _repeatWeekly
                      ? colorScheme.primary.withValues(
                          alpha: isDark ? 0.15 : 0.08,
                        )
                      : (isDark
                            ? sem.surfaceElevated
                            : const Color(0xFFF8F8FC)),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: _repeatWeekly
                        ? colorScheme.primary.withValues(alpha: 0.4)
                        : sem.borderSubtle,
                    width: _repeatWeekly ? 1.5 : 1.0,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _repeatWeekly = !_repeatWeekly);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _repeatWeekly
                                ? colorScheme.primary.withValues(alpha: 0.15)
                                : (isDark
                                      ? sem.surfaceElevated2
                                      : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Icon(
                            _repeatWeekly
                                ? Icons.repeat_rounded
                                : Icons.today_rounded,
                            size: 20,
                            color: _repeatWeekly
                                ? colorScheme.primary
                                : sem.onSurfaceMuted,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Repeat weekly',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _repeatWeekly
                                    ? 'Applies every $_selectedDay'
                                    : 'Only applies on ${widget.targetDateForOverride != null ? DateFormat('d MMM').format(widget.targetDateForOverride!) : DateFormat('d MMM').format(DateTime.parse(_getTargetDateStr(_selectedDay)))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: _repeatWeekly
                                      ? colorScheme.primary
                                      : sem.onSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch.adaptive(
                            value: _repeatWeekly,
                            activeColor: colorScheme.primary,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              setState(() => _repeatWeekly = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3l),

            // ── Action Buttons ────────────────────────────────────────
            if (isEditing)
              Row(
                children: [
                  if (canDelete) ...[
                    // Delete button (icon only, outlined)
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                        child: const Icon(Icons.delete_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: _ActionButton(
                      label: 'Save Changes',
                      isLoading: _isLoading,
                      onPressed: () => _save(keepOpen: false),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Save & Add Next',
                      isLoading: _isLoading,
                      isFilled: false,
                      onPressed: () => _save(keepOpen: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ActionButton(
                      label: 'Save & Close',
                      isLoading: _isLoading,
                      onPressed: () => _save(keepOpen: false),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.x2l),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          icon: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_rounded,
              color: colorScheme.error,
              size: 28,
            ),
          ),
          title: Text(
            'Delete Lecture?',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Text(
            !_repeatWeekly
                ? 'This will cancel the lecture for $_selectedDay only.'
                : 'This will permanently remove the lecture. Students and faculty will be notified.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
              child: Text(
                'Delete',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final oldEntry = widget.existingEntry!;

      if (!_repeatWeekly && oldEntry.validForDate == null) {
        // One-off cancellation of a recurring lecture
        final targetDateStr = widget.targetDateForOverride != null
            ? DateFormat('yyyy-MM-dd').format(widget.targetDateForOverride!)
            : _getTargetDateStr(_selectedDay);

        // Hide original
        final updatedHiddenDates = List<String>.from(oldEntry.hiddenOnDates)
          ..add(targetDateStr);
        await FirebaseFirestore.instance
            .collection('timetables')
            .doc(widget.division)
            .collection(widget.initialDay)
            .doc(oldEntry.id)
            .update({'hiddenOnDates': updatedHiddenDates});

        // Add cancelled placeholder
        final cancelledEntry = oldEntry.copyWith(
          id: FirebaseFirestore.instance.collection('timetables').doc().id,
          validForDate: targetDateStr,
          status: 'cancelled',
          hiddenOnDates: [],
        );

        await TimetableManager.addLecture(
          division: widget.division,
          day: _selectedDay,
          entry: cancelledEntry,
          oldEntry: oldEntry, // ignore overlap
        );
      } else {
        // Permanent delete OR deleting an already one-off lecture
        await FirebaseFirestore.instance
            .collection('timetables')
            .doc(widget.division)
            .collection(widget.initialDay)
            .doc(oldEntry.id)
            .delete();

        await TimetableEventService.handleModification(
          division: widget.division,
          day: widget.initialDay,
          oldEntry: oldEntry,
          newEntry: null,
          isDelete: true,
        );
      }

      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(
          context: context,
          title: 'Error',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTypeChip(
    String component,
    EventCategory category,
    IconData icon,
  ) {
    final isSelected = _component == component && _category == category;
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _component = component;
          _category = category;
        });
      },
      child: AnimatedContainer(
        duration: AppDuration.standard,
        curve: AppCurves.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : sem.surfaceElevated2,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected ? colorScheme.primary : sem.borderSubtle,
            width: isSelected ? 0 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : sem.onSurfaceMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              component,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Day Pill Selector ──────────────────────────────────────────────────────────
class _DayPillSelector extends StatelessWidget {
  final List<String> days;
  final String selected;
  final ValueChanged<String> onSelected;

  const _DayPillSelector({
    required this.days,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: days.map((day) {
          final isSelected = selected == day;
          return Padding(
            padding: EdgeInsets.only(
              right: days.last == day ? 0 : AppSpacing.sm,
            ),
            child: GestureDetector(
              onTap: () => onSelected(day),
              child: AnimatedContainer(
                duration: AppDuration.standard,
                curve: AppCurves.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : isDark
                      ? sem.surfaceElevated2
                      : const Color(0xFFF0F0F8),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : sem.borderSubtle,
                    width: isSelected ? 0 : 1,
                  ),
                ),
                child: Text(
                  day.substring(0, 3),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Time Picker Card ───────────────────────────────────────────────────────────
class _TimePicker extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;
  final bool isDark;
  final AppSemanticColors sem;
  final ColorScheme colorScheme;
  final bool isStart;

  const _TimePicker({
    required this.label,
    required this.time,
    required this.onTap,
    required this.isDark,
    required this.sem,
    required this.colorScheme,
    required this.isStart,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl,
            horizontal: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: isDark ? sem.surfaceElevated2 : colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: sem.borderSubtle),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isStart
                        ? Icons.play_circle_fill_rounded
                        : Icons.stop_circle_rounded,
                    size: 16,
                    color: isStart
                        ? colorScheme.primary
                        : colorScheme.secondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sem.onSurfaceMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                time,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap to change',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action Button ──────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isFilled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.isFilled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isFilled ? Colors.white : colorScheme.primary,
            ),
          )
        : Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          );

    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(vertical: AppSpacing.lg),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );

    if (isFilled) {
      return FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: child,
      );
    } else {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: child,
      );
    }
  }
}
