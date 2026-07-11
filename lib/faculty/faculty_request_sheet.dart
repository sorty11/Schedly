import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../app_settings.dart';
import '../theme/theme.dart';
import '../models/timetable_entry.dart';
import '../models/faculty_request.dart';
import '../widgets/animations/animated_button.dart';
import 'faculty_audit_service.dart';

class FacultyRequestSheet extends StatefulWidget {
  final FacultyRequestType requestType;
  final String? prefillDivision;
  final TimetableEntry? prefillEntry; // For Cancel

  const FacultyRequestSheet({
    super.key,
    required this.requestType,
    this.prefillDivision,
    this.prefillEntry,
  });

  @override
  State<FacultyRequestSheet> createState() => _FacultyRequestSheetState();
}

class _FacultyRequestSheetState extends State<FacultyRequestSheet> {
  bool _isLoading = false;

  String? _selectedDivision;
  String? _selectedSubject;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  final _durationController = TextEditingController();
  final _roomController = TextEditingController();
  final _reasonController = TextEditingController();

  List<String> _availableSubjects = [];

  @override
  void initState() {
    super.initState();
    _selectedDivision = widget.prefillDivision;
    
    if (widget.requestType == FacultyRequestType.cancel && widget.prefillEntry != null) {
      _selectedSubject = widget.prefillEntry!.subjectCode;
      _selectedDate = DateTime.now(); // Usually cancelling today's lecture
    } else {
      _selectedDate = DateTime.now();
      _durationController.text = '60';
    }

    if (_selectedDivision != null) {
      _loadSubjectsForDivision(_selectedDivision!);
    }
  }
  
  @override
  void dispose() {
    _durationController.dispose();
    _roomController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjectsForDivision(String div) async {
    final uid = AppSettings.facultyId;
    if (uid == null) return;

    final profileSnap = await FirebaseFirestore.instance.collection('faculty_profiles').doc(uid).get();
    final profileData = profileSnap.data() ?? {};
    final subjectsMap = (profileData['subjects'] as Map<String, dynamic>?) ?? {};
    
    setState(() {
      _availableSubjects = List<String>.from(subjectsMap[div] ?? []);
      if (!_availableSubjects.contains(_selectedSubject)) {
        _selectedSubject = _availableSubjects.isNotEmpty ? _availableSubjects.first : null;
      }
    });
  }

  Future<void> _submitRequest() async {
    if (_selectedDivision == null || _selectedSubject == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }
    
    if (widget.requestType == FacultyRequestType.addExtra && (_selectedTime == null || _durationController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time and Duration are required for extra lectures')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = AppSettings.facultyId ?? '';
      final name = AppSettings.facultyName ?? 'Faculty';

      int? startTimeMinutes;
      int? endTimeMinutes;
      
      if (widget.requestType == FacultyRequestType.addExtra) {
        startTimeMinutes = _selectedTime!.hour * 60 + _selectedTime!.minute;
        final duration = int.tryParse(_durationController.text.trim()) ?? 60;
        endTimeMinutes = startTimeMinutes + duration;
      }

      final docRef = FirebaseFirestore.instance
          .collection('sections')
          .doc(_selectedDivision)
          .collection('faculty_requests')
          .doc();

      final request = FacultyRequest(
        id: docRef.id,
        facultyId: uid,
        facultyName: name,
        division: _selectedDivision!,
        type: widget.requestType,
        status: FacultyRequestStatus.pending,
        subject: _selectedSubject!,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
        date: _selectedDate,
        startTime: startTimeMinutes,
        endTime: endTimeMinutes,
        room: _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
        originalLectureId: widget.prefillEntry?.id,
        createdAt: DateTime.now(),
      );

      await docRef.set(request.toFirestore());

      await FacultyAuditService.logAction(
        actionType: widget.requestType == FacultyRequestType.cancel 
            ? FacultyActionType.requestCancel 
            : FacultyActionType.requestExtra,
        description: 'Submitted request for $_selectedSubject in $_selectedDivision',
        metadata: {
          'requestId': request.id,
          'division': _selectedDivision,
          'subject': _selectedSubject,
        },
      );

      // Notify CR — wrapped in try-catch so failures never block request submission
      try {
        await FirebaseFirestore.instance.collection('notification_outbox').add({
          'division': _selectedDivision,
          'topic': 'cr_$_selectedDivision',
          'role': 'CR',
          'title': 'New Faculty Request',
          'body': 'Prof. $name requested to ${widget.requestType == FacultyRequestType.cancel ? 'cancel' : 'add'} a $_selectedSubject lecture.',
          'type': 'faculty_request',
          'uid': uid,
          'data': {
            'requestId': request.id,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
          'attempts': 0,
          'nextRetryAt': FieldValue.serverTimestamp(),
        });
      } catch (outboxErr) {
        debugPrint('OUTBOX WARNING (non-fatal, faculty request): $outboxErr');
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted to CR successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCancel = widget.requestType == FacultyRequestType.cancel;
    final title = isCancel ? 'Request Cancellation' : 'Request Extra Lecture';
    final divisions = AppSettings.facultyAssignedDivisions ?? [];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.x2l)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.x2l)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                top: AppSpacing.xl,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Division Selector
                  if (widget.prefillDivision == null)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Select Division', border: OutlineInputBorder()),
                      value: _selectedDivision,
                      items: divisions.map((d) => DropdownMenuItem(value: d, child: Text(d.replaceAll('_', ' ')))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedDivision = val);
                        if (val != null) _loadSubjectsForDivision(val);
                      },
                    )
                  else
                    TextFormField(
                      initialValue: _selectedDivision!.replaceAll('_', ' '),
                      enabled: false,
                      decoration: const InputDecoration(labelText: 'Division', border: OutlineInputBorder()),
                    ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Subject Selector
                  if (widget.prefillEntry == null)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Select Subject', border: OutlineInputBorder()),
                      value: _selectedSubject,
                      items: _availableSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedSubject = val),
                    )
                  else
                    TextFormField(
                      initialValue: _selectedSubject,
                      enabled: false,
                      decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    ),

                  const SizedBox(height: AppSpacing.md),
                  
                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                      child: Text(_selectedDate != null ? DateFormat('MMM d, yyyy').format(_selectedDate!) : 'Select Date'),
                    ),
                  ),
                  
                  if (!isCancel) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime ?? TimeOfDay.now(),
                              );
                              if (time != null) setState(() => _selectedTime = time);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder()),
                              child: Text(_selectedTime != null ? _selectedTime!.format(context) : 'Select Time'),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Duration (mins)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _roomController,
                      decoration: const InputDecoration(labelText: 'Room (Optional)', border: OutlineInputBorder()),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: isCancel ? 'Reason for Cancellation (Optional)' : 'Message to students (Optional)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  AnimatedButton(
                    onPressed: _isLoading ? null : _submitRequest,
                    isLoading: _isLoading,
                    backgroundColor: isCancel ? Colors.red : Theme.of(context).colorScheme.primary,
                    child: Text(isCancel ? 'Submit Cancellation Request' : 'Submit Extra Lecture Request'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
