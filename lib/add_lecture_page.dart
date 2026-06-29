import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timetable_manager.dart';
import 'services/firestore_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';

class AddLecturePage extends StatefulWidget {
  const AddLecturePage({super.key});

  @override
  State<AddLecturePage> createState() =>
      _AddLecturePageState();
}

class _AddLecturePageState
    extends State<AddLecturePage> {
  final roomController = TextEditingController();
  final subjectController = TextEditingController();

  String targetBatch = 'Whole Class';
  String selectedDay = 'Monday';

  String? selectedSlot;
  String? division;
  
  String get _divLetter {
    if (division == null || division!.isEmpty) return '';
    final last = division!.trim().characters.last.toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(last) ? last : '';
  }

  List<String> get _batchOptions {
    final l = _divLetter;
    if (l.isEmpty) return ['Whole Class', 'Batch 1', 'Batch 2', 'Batch 3'];
    return ['Whole Class ($l)', '${l}1', '${l}2', '${l}3'];
  }

  String? selectedSubject;

  List<String> availableSlots = [];

  List<String> subjects = [];

  bool loadingSlots = true;

  bool loadingSubjects = true;

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _loadDivision();
  }

  Future<void> _loadDivision() async {
    final prefs =
        await SharedPreferences.getInstance();

    division =
        prefs.getString(
      'selected_division',
    );

    if (division == null) return;

    subjects = await TimetableManager.getUniqueSubjects(division: division!);

    if (subjects.isNotEmpty) {
      selectedSubject = subjects.first;
    }
    
    // Set targetBatch to the first option dynamically
    targetBatch = _batchOptions.first;

    setState(() {
      loadingSubjects = false;
    });

    await _refreshSlots();
  }

  Future<void> _refreshSlots() async {
    if (division == null) return;

    setState(() {
      loadingSlots = true;
    });

    final entries = await TimetableManager.getEntriesForDay(division: division!, day: selectedDay);
    final takenSlots = entries.map((e) => TimetableManager.formatTime(e.startTime, e.endTime)).toSet();
    availableSlots = TimetableManager.allSlots.where((s) => !takenSlots.contains(s)).toList();

    if (availableSlots.isNotEmpty) {
      selectedSlot =
          availableSlots.first;
    } else {
      selectedSlot = null;
    }

    setState(() {
      loadingSlots = false;
    });
  }

  @override
  void dispose() {
    roomController.dispose();
    subjectController.dispose();
    super.dispose();
  }

  void _saveLecture() {
    String finalSubject = selectedSubject ?? subjectController.text;
    if (finalSubject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject is required')));
      return;
    }
    
    if (targetBatch != _batchOptions.first) {
       finalSubject = '$finalSubject ($targetBatch)';
    }

    Navigator.pop(
      context,
      {
        'day': selectedDay,
        'subject': finalSubject,
        'time': selectedSlot!,
        'room': roomController.text,
        'cancelled': 'false',
        'batch': targetBatch,
      },
    );
  }

  InputDecoration _modernDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Lecture'),
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.05), width: 1.5),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedDay,
                    decoration: _modernDecoration('Day', Icons.calendar_today_rounded),
                    icon: Icon(Icons.expand_more_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                    items: days.map((day) => DropdownMenuItem(value: day, child: Text(day, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)))).toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      selectedDay = value;
                      await _refreshSlots();
                    },
                  ),
                  const SizedBox(height: 20),
                  if (loadingSubjects)
                    Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  else
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return subjects;
                        return subjects.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) {
                        selectedSubject = selection;
                        subjectController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        controller.addListener(() {
                          selectedSubject = controller.text;
                          subjectController.text = controller.text;
                        });
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                          decoration: _modernDecoration('Subject', Icons.book_rounded),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: targetBatch,
                    decoration: _modernDecoration('Target Batch', Icons.groups_rounded),
                    icon: Icon(Icons.expand_more_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                    items: _batchOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)))).toList(),
                    onChanged: (val) {
                      setState(() {
                        targetBatch = val ?? _batchOptions.first;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (loadingSlots)
                    Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedSlot,
                      decoration: _modernDecoration('Available Slot', Icons.access_time_rounded),
                      icon: Icon(Icons.expand_more_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                      items: availableSlots.map((slot) => DropdownMenuItem(value: slot, child: Text(slot, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)))).toList(),
                      onChanged: availableSlots.isEmpty ? null : (value) {
                        setState(() {
                          selectedSlot = value;
                        });
                      },
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: roomController,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                    decoration: _modernDecoration('Room', Icons.meeting_room_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (availableSlots.isEmpty && !loadingSlots)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).extension<AppSemanticColors>()!.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).extension<AppSemanticColors>()!.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Theme.of(context).extension<AppSemanticColors>()!.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text('No free slots available for this day.', style: TextStyle(color: Theme.of(context).extension<AppSemanticColors>()!.error, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: AnimatedButton(
                onPressed: availableSlots.isEmpty ? null : _saveLecture,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save_rounded),
                    const SizedBox(width: 8),
                    const Text('Save Lecture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
