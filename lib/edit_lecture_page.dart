import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'user_roles.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/animated_list_tile.dart';

class EditLecturePage extends StatefulWidget {
  final Map<String, String> lecture;
  final String division;

  const EditLecturePage({
    super.key,
    required this.lecture,
    required this.division,
  });

  @override
  State<EditLecturePage> createState() =>
      _EditLecturePageState();
}

class _EditLecturePageState
    extends State<EditLecturePage> {
  late TextEditingController subjectController;
  late TextEditingController timeController;
  late TextEditingController roomController;

  // Split mode controllers
  bool isSplit = false;
  late TextEditingController splitSubjectController;
  late TextEditingController splitRoomController;
  String splitBatch = '';

  bool cancelled = false;
  
  List<String> uniqueSubjects = [];
  String targetBatch = '';
  
  String get _divLetter {
    if (widget.division.isEmpty) return '';
    final last = widget.division.trim().characters.last.toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(last) ? last : '';
  }

  List<String> get _batchOptions {
    final l = _divLetter;
    if (l.isEmpty) return ['Whole Class', 'Batch 1', 'Batch 2', 'Batch 3'];
    return ['Whole Class ($l)', '${l}1', '${l}2', '${l}3'];
  }

  bool get isSR =>
      AppSettings.currentRole ==
      UserRole.sr;

  @override
  void initState() {
    super.initState();

    String initialSubject = widget.lecture['subject'] ?? '';
    String initialBatch = widget.lecture['batch'] ?? '';
    
    targetBatch = _batchOptions.contains(initialBatch) ? initialBatch : _batchOptions.first;
    splitBatch = _batchOptions.first;

    subjectController = TextEditingController(text: initialSubject);
    timeController = TextEditingController(text: widget.lecture['time']);
    roomController = TextEditingController(text: widget.lecture['room']);

    splitSubjectController = TextEditingController();
    splitRoomController = TextEditingController(text: widget.lecture['room']);

    cancelled = widget.lecture['cancelled'] == 'true';
    
    _loadSubjects();
  }
  
  Future<void> _loadSubjects() async {
    final subs = await TimetableManager.getUniqueSubjects(division: widget.division);
    if (mounted) {
      setState(() {
        uniqueSubjects = subs;
      });
    }
  }

  @override
  void dispose() {
    subjectController.dispose();
    timeController.dispose();
    roomController.dispose();
    splitSubjectController.dispose();
    splitRoomController.dispose();
    super.dispose();
  }

  Future<void> _saveLecture() async {
    String constructSubject(String base) {
      return base.trim();
    }

    final currentDur = TimetableManager.computeDurationHours(timeController.text);
    if (currentDur == 1) {
      final req1 = await TimetableManager.getSubjectRequiredDuration(division: widget.division, subject: subjectController.text);
      if (req1 >= 2) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Invalid Replacement', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface)),
            content: Text('This replacement requires a 2-hour continuous slot, but the selected lecture occupies only a 1-hour period.', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
            ],
          )
        );
        return;
      }
      
      if (isSplit) {
        final req2 = await TimetableManager.getSubjectRequiredDuration(division: widget.division, subject: splitSubjectController.text);
        if (req2 >= 2) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Invalid Replacement', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface)),
              content: Text('Batch 2 replacement requires a 2-hour continuous slot, but the selected lecture occupies only a 1-hour period.', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
              ],
            )
          );
          return;
        }
      }
    }

    if (!mounted) return;

    if (isSplit) {
      Navigator.pop(context, {
        'action': 'split',
        'lecture1': {
          'id': widget.lecture['id'] ?? '',
          'subject': constructSubject(subjectController.text),
          'batch': targetBatch,
          'time': timeController.text,
          'room': roomController.text,
          'cancelled': cancelled.toString(),
        },
        'lecture2': {
          'subject': constructSubject(splitSubjectController.text),
          'batch': splitBatch,
          'time': timeController.text,
          'room': splitRoomController.text,
          'cancelled': 'false',
        }
      });
    } else {
      Navigator.pop(context, {
        'action': 'update',
        'id': widget.lecture['id'] ?? '',
        'subject': constructSubject(subjectController.text),
        'batch': targetBatch,
        'time': timeController.text,
        'room': roomController.text,
        'cancelled': cancelled.toString(),
      });
    }
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
        title: const Text('Edit Lecture'),
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
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return uniqueSubjects;
                      return uniqueSubjects.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    initialValue: TextEditingValue(text: subjectController.text),
                    onSelected: (String selection) {
                      subjectController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.addListener(() {
                        subjectController.text = controller.text;
                      });
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !isSR,
                        style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                        decoration: _modernDecoration(isSplit ? 'Subject (Batch 1)' : 'Subject', Icons.book_rounded).copyWith(
                          helperText: isSR ? 'Only CR can change subject' : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _batchOptions.contains(targetBatch) ? targetBatch : _batchOptions.first,
                    decoration: _modernDecoration(isSplit ? 'Target Batch (Batch 1)' : 'Target Batch', Icons.groups_rounded),
                    icon: Icon(Icons.expand_more_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                    items: _batchOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)))).toList(),
                    onChanged: !isSR ? (val) {
                      setState(() {
                        targetBatch = val ?? _batchOptions.first;
                      });
                    } : null,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: timeController,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                    decoration: _modernDecoration('Time', Icons.access_time_rounded),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: roomController,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                    decoration: _modernDecoration(isSplit ? 'Room (Batch 1)' : 'Room', Icons.meeting_room_rounded),
                  ),
                ],
              ),
            ),
            
            if (isSplit) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 12),
                child: Text('Second Batch Lecture', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
              ),
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
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return uniqueSubjects;
                        return uniqueSubjects.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      initialValue: TextEditingValue(text: splitSubjectController.text),
                      onSelected: (String selection) {
                        splitSubjectController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        controller.addListener(() {
                          splitSubjectController.text = controller.text;
                        });
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                          decoration: _modernDecoration('Subject (Batch 2)', Icons.book_rounded),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _batchOptions.contains(splitBatch) ? splitBatch : _batchOptions.first,
                      decoration: _modernDecoration('Target Batch (Batch 2)', Icons.groups_rounded),
                      icon: Icon(Icons.expand_more_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                      items: _batchOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)))).toList(),
                      onChanged: (val) {
                        setState(() {
                          splitBatch = val ?? _batchOptions.first;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: splitRoomController,
                      style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      decoration: _modernDecoration('Room (Batch 2)', Icons.meeting_room_rounded),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (!isSR && !isSplit)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call_split_rounded),
                  label: const Text('Split into Two Lectures', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    setState(() {
                      isSplit = true;
                      final sub = subjectController.text;
                      if (sub.contains(' ')) {
                         final parts = sub.split(' ');
                         subjectController.text = parts.first;
                         splitSubjectController.text = parts.skip(1).join(' ');
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

            AnimatedListTile(
              onTap: () {
                setState(() {
                  cancelled = !cancelled;
                });
              },
              backgroundColor: cancelled 
                ? Theme.of(context).extension<AppSemanticColors>()!.cancelled.withValues(alpha: 0.1) 
                : Theme.of(context).colorScheme.surface,
              title: Text('Lecture Cancelled', 
                style: TextStyle(
                  fontWeight: FontWeight.w700, 
                  color: cancelled 
                    ? Theme.of(context).extension<AppSemanticColors>()!.cancelled 
                    : Theme.of(context).colorScheme.onSurface
                )
              ),
              trailing: Switch(
                value: cancelled,
                activeThumbColor: Theme.of(context).extension<AppSemanticColors>()!.cancelled,
                onChanged: (value) {
                  setState(() {
                    cancelled = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              height: 56,
              child: AnimatedButton(
                onPressed: _saveLecture,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save_rounded),
                    const SizedBox(width: 8),
                    const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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