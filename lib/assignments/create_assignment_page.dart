import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../app_settings.dart';
import '../user_roles.dart';
import '../theme/theme.dart';
import '../widgets/schedly_text_field.dart';
import '../widgets/app_dialogs.dart';

class CreateAssignmentPage extends StatefulWidget {
  final Assignment? existingAssignment;
  final String? initialSectionId;

  const CreateAssignmentPage({
    super.key,
    this.existingAssignment,
    this.initialSectionId,
  });

  @override
  State<CreateAssignmentPage> createState() => _CreateAssignmentPageState();
}

class _CreateAssignmentPageState extends State<CreateAssignmentPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedBatch = 'Whole Class';
  List<String> _availableBatches = ['Whole Class'];
  List<String> _availableSubjects = [];
  bool _isSaving = false;

  bool get _isEdit => widget.existingAssignment != null;
  bool get _isSR => AppSettings.currentRole == UserRole.sr;

  String get _effectiveSectionId {
    return widget.existingAssignment?.sectionId ??
        widget.initialSectionId ??
        AppSettings.sectionId ??
        AppSettings.division ??
        '';
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAssignment;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _linkController =
        TextEditingController(text: existing?.attachmentUrl ?? '');

    if (_isSR && AppSettings.srSubject != null) {
      _subjectController = TextEditingController(text: AppSettings.srSubject);
    } else {
      _subjectController =
          TextEditingController(text: existing?.subject ?? '');
    }

    if (existing != null) {
      final local = existing.dueAt.toLocal();
      _selectedDate = DateTime(local.year, local.month, local.day);
      _selectedTime = TimeOfDay(hour: local.hour, minute: local.minute);
      _selectedBatch = existing.batch ?? 'Whole Class';
    } else {
      // Default to tomorrow 11:59 PM
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      _selectedTime = const TimeOfDay(hour: 23, minute: 59);
      if (_isSR && AppSettings.srBatch != null && AppSettings.srBatch!.isNotEmpty) {
        _selectedBatch = AppSettings.srBatch!;
      }
    }

    _loadSectionMetadata();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadSectionMetadata() async {
    final sec = _effectiveSectionId;
    if (sec.isEmpty) return;

    try {
      // Fetch section doc to load batches
      final secDoc =
          await FirebaseFirestore.instance.collection('sections').doc(sec).get();
      if (secDoc.exists) {
        final data = secDoc.data()!;
        final rawBatches = data['batches'] as List<dynamic>?;
        if (rawBatches != null && rawBatches.isNotEmpty) {
          final batches = <String>['Whole Class'];
          for (final b in rawBatches) {
            final name = b.toString();
            if (!batches.contains(name)) batches.add(name);
          }
          if (mounted) setState(() => _availableBatches = batches);
        }
      }

      // Fetch subjects from section if available
      final subSnap = await FirebaseFirestore.instance
          .collection('sections')
          .doc(sec)
          .collection('subjects')
          .get();
      final subjects = <String>[];
      for (final doc in subSnap.docs) {
        final name = doc.data()['name']?.toString() ?? doc.id;
        if (!subjects.contains(name)) subjects.add(name);
      }
      if (mounted) setState(() => _availableSubjects = subjects);
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate != null && _selectedDate!.isAfter(now)
        ? _selectedDate!
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final initial = _selectedTime ?? const TimeOfDay(hour: 23, minute: 59);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  DateTime? _combineDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dueAt = _combineDateTime();
    if (dueAt == null) {
      AppDialogs.showSnackBar(
        context: context,
        message: 'Please choose a due date and time',
        isError: true,
      );
      return;
    }

    if (!dueAt.isAfter(DateTime.now())) {
      AppDialogs.showSnackBar(
        context: context,
        message: 'Deadline must be in the future',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEdit) {
        await AssignmentService.updateAssignment(
          existing: widget.existingAssignment!,
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          dueAt: dueAt,
          batch: _selectedBatch == 'Whole Class' ? null : _selectedBatch,
          attachmentUrl: _linkController.text.trim(),
        );
        if (mounted) {
          AppDialogs.showSnackBar(
            context: context,
            message: 'Assignment updated successfully',
          );
          Navigator.pop(context, true);
        }
      } else {
        await AssignmentService.createAssignment(
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          dueAt: dueAt,
          sectionId: _effectiveSectionId,
          batch: _selectedBatch == 'Whole Class' ? null : _selectedBatch,
          attachmentUrl: _linkController.text.trim(),
        );
        if (mounted) {
          AppDialogs.showSnackBar(
            context: context,
            message: 'Assignment created and reminders scheduled',
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showSnackBar(
          context: context,
          message: 'Failed to save assignment: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    final dateText = _selectedDate != null
        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
        : 'Select Date';
    final timeText = _selectedTime != null
        ? _selectedTime!.format(context)
        : 'Select Time';

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Assignment' : 'Create Assignment',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Target Section Info Chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.class_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Section: $_effectiveSectionId',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        _isSR ? 'SR Mode' : 'CR Mode',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'Assignment Title *',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SchedlyTextField(
                controller: _titleController,
                hintText: 'e.g. DSA Assignment 3',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Subject
              Text(
                'Subject *',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_isSR)
                SchedlyTextField(
                  controller: _subjectController,
                  enabled: false,
                  hintText: 'Subject',
                )
              else if (_availableSubjects.isNotEmpty)
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _subjectController.text),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _availableSubjects;
                    }
                    return _availableSubjects.where((sub) => sub
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (selection) {
                    _subjectController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _subjectController.addListener(() {
                      if (controller.text != _subjectController.text) {
                        controller.text = _subjectController.text;
                      }
                    });
                    return SchedlyTextField(
                      controller: controller,
                      focusNode: focusNode,
                      hintText: 'e.g. Data Structures & Algorithms',
                      onChanged: (val) => _subjectController.text = val,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Subject is required';
                        }
                        return null;
                      },
                    );
                  },
                )
              else
                SchedlyTextField(
                  controller: _subjectController,
                  hintText: 'e.g. Data Structures & Algorithms',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Subject is required';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: AppSpacing.lg),

              // Target Batch
              Text(
                'Target Batch',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? sem.surfaceElevated : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: sem.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _availableBatches.contains(_selectedBatch)
                        ? _selectedBatch
                        : 'Whole Class',
                    isExpanded: true,
                    items: _availableBatches.map((b) {
                      return DropdownMenuItem<String>(
                        value: b,
                        child: Text(
                          b,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBatch = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Deadline: Due Date & Time
              Text(
                'Deadline *',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? sem.surfaceElevated : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: sem.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              dateText,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? sem.surfaceElevated : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: sem.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              timeText,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Optional Link / Attachment
              Text(
                'Resource / Submission Link (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SchedlyTextField(
                controller: _linkController,
                hintText: 'https://docs.google.com/...',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Description
              Text(
                'Description / Instructions (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SchedlyTextField(
                controller: _descriptionController,
                hintText: 'Add guidelines, chapter references or questions...',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.x3l),

              // Submit CTA
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded,
                          size: 18),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : (_isEdit ? 'Update Assignment' : 'Create & Schedule Reminders'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
