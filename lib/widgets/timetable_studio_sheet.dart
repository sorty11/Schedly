import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/theme.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import '../timetable_manager.dart';
import '../app_settings.dart';
import '../user_roles.dart';
import '../services/history_service.dart';
import 'app_dialogs.dart';

class TimetableStudioSheet extends StatefulWidget {
  final String division;
  final String initialDay;
  final TimetableEntry? existingEntry;
  final TimetableEntry? duplicateFrom;

  const TimetableStudioSheet({
    super.key,
    required this.division,
    required this.initialDay,
    this.existingEntry,
    this.duplicateFrom,
  });

  static Future<void> show(BuildContext context, {required String division, required String initialDay, TimetableEntry? existingEntry, TimetableEntry? duplicateFrom}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimetableStudioSheet(
        division: division,
        initialDay: initialDay,
        existingEntry: existingEntry,
        duplicateFrom: duplicateFrom,
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

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  List<String> get _batchOptions {
    final l = _divLetter;
    if (l.isEmpty) return ['Whole Class', 'Batch 1', 'Batch 2'];
    return ['Whole Class', '${l}1', '${l}2'];
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
    } else if (widget.duplicateFrom != null) {
      final entry = widget.duplicateFrom!;
      _subject = entry.subject;
      _batch = entry.batch;
      _component = entry.component;
      _category = entry.category;
      _room = entry.room ?? '';
      _startTime = entry.startTime;
      _endTime = entry.endTime;
    } else {
      _subject = _lastSubject ?? '';
      _batch = _lastBatch ?? 'Whole Class';
      _component = _lastComponent ?? 'Theory';
      _category = _lastCategory ?? EventCategory.academic;
      _room = _lastRoom ?? '';
      _startTime = 9 * 60;
      _endTime = _startTime + 60;
    }

    _subjectController.text = _subject;
    _roomController.text = _room;
  }

  Future<void> _fetchMetadata() async {
    final subjects = await TimetableManager.getUniqueSubjects(division: widget.division);
    
    final Set<String> rooms = {};
    for (final day in _days) {
      final entries = await TimetableManager.getEntriesForDay(division: widget.division, day: day);
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

  Future<void> _save({required bool keepOpen}) async {
    final subject = _subjectController.text.trim();
    final room = _roomController.text.trim();

    if (subject.isEmpty) {
      _subjectFocusNode?.requestFocus();
      _showErrorDialog('Missing Information', 'Subject cannot be empty.');
      return;
    }
    if (_endTime <= _startTime) {
      _showErrorDialog('Invalid Time', 'End time must be after start time.');
      return;
    }
    
    // Validation is now handled inside TimetableManager.addLecture

    setState(() => _isLoading = true);

    try {
      final entryId = widget.existingEntry?.id ?? FirebaseFirestore.instance.collection('timetables').doc().id;

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
      );

      if (widget.existingEntry != null && widget.initialDay != _selectedDay) {
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

      final timeStr = TimetableManager.formatTime(entry.startTime, entry.endTime);
      await HistoryService.logOperation(
        division: widget.division,
        operation: widget.existingEntry != null ? 'Lecture Replaced' : 'Lecture Added',
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
        message: widget.existingEntry != null ? 'Lecture updated!' : 'Lecture added successfully!',
      );

      if (keepOpen) {
        // Reset time for next entry
        setState(() {
          _startTime = _endTime;
          _endTime = _startTime + 60;
        });
      } else {
        Navigator.pop(context);
      }
    } on ValidationException catch (e) {
      _showErrorDialog(e.title, e.message);
    } catch (e) {
      _showErrorDialog('Error', e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:${m.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.x2l),
        decoration: BoxDecoration(
          color: isDark ? sem.surfaceElevated : colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.x2l)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: sem.onSurfaceMuted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              Text(
                widget.existingEntry != null ? 'Edit Lecture' : 'Add Lecture',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.x2l),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SegmentedButton<String>(
                  segments: _days.map((day) => ButtonSegment<String>(
                    value: day,
                    label: Text(day.substring(0, 3)),
                  )).toList(),
                  selected: {_selectedDay},
                  onSelectionChanged: (set) => setState(() => _selectedDay = set.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return _availableSubjects;
                  return _availableSubjects.where((option) =>
                      option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  if (controller.text.isEmpty && _subjectController.text.isNotEmpty) {
                    controller.text = _subjectController.text;
                  }
                  controller.addListener(() => _subjectController.text = controller.text);
                  _subjectFocusNode = focusNode;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: const Icon(Icons.book_rounded),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _batch,
                      decoration: InputDecoration(
                        labelText: 'Batch',
                        prefixIcon: const Icon(Icons.groups_rounded),
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ),
                      isExpanded: true,
                      items: _batchOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => _batch = val!),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 1,
                    child: Autocomplete<String>(
                      optionsBuilder: (tv) {
                        if (tv.text.isEmpty) return _availableRooms;
                        return _availableRooms.where((option) =>
                            option.toLowerCase().contains(tv.text.toLowerCase()));
                      },
                      fieldViewBuilder: (context, controller, focusNode, _) {
                        if (controller.text.isEmpty && _roomController.text.isNotEmpty) {
                          controller.text = _roomController.text;
                        }
                        controller.addListener(() => _roomController.text = controller.text);
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Room',
                            prefixIcon: const Icon(Icons.room_rounded),
                            filled: true,
                            fillColor: colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Lecture Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: sem.onSurfaceMuted)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8.0,
                runSpacing: 0.0,
                children: [
                  _buildTypeChip('Theory', EventCategory.academic),
                  _buildTypeChip('Lab', EventCategory.academic),
                  _buildTypeChip('Tutorial', EventCategory.academic),
                  _buildTypeChip('Event', EventCategory.event),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartTime,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(color: sem.borderSubtle),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start Time', style: TextStyle(fontSize: 12, color: sem.onSurfaceMuted)),
                            const SizedBox(height: 4),
                            Text(_formatTime(_startTime), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndTime,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(color: sem.borderSubtle),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('End Time', style: TextStyle(fontSize: 12, color: sem.onSurfaceMuted)),
                            const SizedBox(height: 4),
                            Text(_formatTime(_endTime), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Repeat weekly', style: TextStyle(fontWeight: FontWeight.w500)),
                value: _repeatWeekly,
                onChanged: (val) => setState(() => _repeatWeekly = val ?? true),
              ),
              const SizedBox(height: AppSpacing.xl),

              Row(
                children: [
                  if (widget.existingEntry != null && AppSettings.currentRole == UserRole.cr)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () async {
                          setState(() => _isLoading = true);
                          await FirebaseFirestore.instance
                              .collection('timetables')
                              .doc(widget.division)
                              .collection(widget.initialDay)
                              .doc(widget.existingEntry!.id)
                              .delete();
                          HapticFeedback.mediumImpact();
                          if (mounted) Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        ),
                        child: const Icon(Icons.delete_rounded),
                      ),
                    ),
                  if (widget.existingEntry != null && AppSettings.currentRole == UserRole.cr) const SizedBox(width: AppSpacing.md),
                  if (widget.existingEntry == null)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => _save(keepOpen: true),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save & Add Next', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (widget.existingEntry == null) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 1,
                    child: FilledButton(
                      onPressed: _isLoading ? null : () => _save(keepOpen: false),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.existingEntry != null ? 'Save Changes' : 'Save & Close', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String component, EventCategory category) {
    final isSelected = _component == component && _category == category;
    return ChoiceChip(
      label: Text(component),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _component = component;
            _category = category;
          });
        }
      },
    );
  }
}
