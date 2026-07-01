import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'course_details_setup_page.dart';
import 'models/event_category.dart';
import 'models/studio_state.dart';
import 'models/timetable_entry.dart';
import 'theme/theme.dart';
import 'widgets/studio/period_builder_step.dart';
import 'widgets/studio/weekly_builder_step.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/studio/working_days_step.dart';

class ManualTimetableStudio extends StatefulWidget {
  final String division;
  final bool editMode; // true = start at weekly builder (step 3)

  const ManualTimetableStudio({
    super.key,
    required this.division,
    this.editMode = false,
  });

  @override
  State<ManualTimetableStudio> createState() => _ManualTimetableStudioState();
}

class _ManualTimetableStudioState extends State<ManualTimetableStudio>
    with TickerProviderStateMixin {
  int _step = 0; // 0=days, 1=periods, 2=weekly builder
  StudioDraftConfig _draft = StudioDraftConfig.blank();
  bool _isLoading = true;
  bool _isPublishing = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _init();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('studio_draft_${widget.division}');
    
    if (widget.editMode) {
      // Typically if editMode is true, we should load from Firestore into draft.
      // But for simplicity in this demo, if draft exists we load it, else we start blank at step 3.
      if (raw != null) {
        try {
          _draft = StudioDraftConfig.fromJsonString(raw);
        } catch (_) {}
      }
      _step = 3;
    } else {
      if (raw != null) {
        try {
          _draft = StudioDraftConfig.fromJsonString(raw);
          // Auto-resume to weekly builder if periods are defined
          if (_draft.periods.isNotEmpty) {
            _step = 2;
          }
        } catch (_) {}
      }
    }

    _draft.ensureSlotsInitialised();
    setState(() => _isLoading = false);
    _slideController.forward();
    print('DEBUG ManualTimetableStudio [_init]: loaded draft batches=${_draft.batches}, step=$_step');
  }

  void _saveDraft() {
    _draft.lastSaved = DateTime.now();
    print('DEBUG ManualTimetableStudio [_saveDraft]: saving batches=${_draft.batches}');
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('studio_draft_${widget.division}', _draft.toJsonString());
    });
  }

  void _nextStep() {
    print('DEBUG ManualTimetableStudio [_nextStep]: before increment, step=$_step, batches=${_draft.batches}');
    if (_step < 2) {
      _slideController.reset();
      setState(() => _step++);
      _slideController.forward();
      _saveDraft();
      print('DEBUG ManualTimetableStudio [_nextStep]: after increment, step=$_step');
    }
  }

  void _prevStep() {
    print('DEBUG ManualTimetableStudio [_prevStep]: before decrement, step=$_step, batches=${_draft.batches}');
    if (_step > 0) {
      _slideController.reset();
      setState(() => _step--);
      _slideController.forward();
      _saveDraft();
      print('DEBUG ManualTimetableStudio [_prevStep]: after decrement, step=$_step');
    }
  }

  Future<void> _publish() async {
    setState(() => _isPublishing = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final day in _draft.selectedDays) {
        final daySlots = _draft.slots[day] ?? {};
        int skipUntilIdx = -1;

        for (int pIdx = 0; pIdx < _draft.periods.length; pIdx++) {
          if (pIdx < skipUntilIdx) continue;

          final period = _draft.periods[pIdx];
          final periodList = daySlots[period.id] ?? [];
          
          int maxDuration = 1;

          for (final slot in periodList) {
            if (slot.isFilled && slot.type == SlotType.lecture) {
              if (slot.durationPeriods > maxDuration) {
                maxDuration = slot.durationPeriods;
              }
              
              int endMinutes = period.endMinutes;
              int duration = period.durationMinutes;

              if (slot.durationPeriods > 1) {
                final lastIdx = (pIdx + slot.durationPeriods - 1).clamp(0, _draft.periods.length - 1);
                endMinutes = _draft.periods[lastIdx].endMinutes;
                duration = endMinutes - period.startMinutes;
              }
              
              final ref = FirebaseFirestore.instance
                  .collection('timetables')
                  .doc(widget.division)
                  .collection(day)
                  .doc(); // Auto ID

              final category = EventCategoryExtension.inferFromSubject(slot.subject ?? '');

              final entry = TimetableEntry(
                id: ref.id,
                subject: slot.subject!,
                category: category,
                batch: slot.batch ?? 'Whole Class',
                startTime: period.startMinutes,
                endTime: endMinutes,
                durationMinutes: duration,
                component: slot.component,
                room: slot.room,
              );

              batch.set(ref, entry.toFirestore());
            }
          }
          if (maxDuration > 1) {
            skipUntilIdx = pIdx + maxDuration;
          }
        }
      }

      final sectionRef = FirebaseFirestore.instance.collection('sections').doc(widget.division);
      batch.set(sectionRef, {'timetablePublished': true}, SetOptions(merge: true));

      await batch.commit();

      // Clear draft
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('studio_draft_${widget.division}');

      if (!mounted) return;
      AppDialogs.showSnackBar(
        context: context,
        message: 'Timetable published! Next: Configure Subjects.',
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CourseDetailsSetupPage(
            division: widget.division,
            isFromPublish: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Publish Failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    print('DEBUG ManualTimetableStudio [build]: step=$_step, draft.batches=${_draft.batches}');

    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titles = ['Working Days', 'Batch Setup', 'Period Schedule', 'Weekly Builder'];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        leading: _step > 0 && _step < 2
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _prevStep)
            : (_step == 0 ? const BackButton() : null),
        automaticallyImplyLeading: _step == 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titles[_step], style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
            if (_step < 2)
              Text('Step ${_step + 1} of 3', style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted))
            else
              Text(AppSettings.sectionId ?? widget.division, style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted)),
          ],
        ),
        actions: [
          if (_step < 3)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 4),
                    width: i == _step ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= _step ? colorScheme.primary : sem.borderSubtle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return WorkingDaysStep(
          selected: _draft.selectedDays,
          onChanged: (v) {
            _draft.selectedDays = v;
            _draft.ensureSlotsInitialised();
            _saveDraft();
          },
          onContinue: _nextStep,
        );
      case 1:
        return PeriodBuilderStep(
          periods: _draft.periods,
          onChanged: (v) {
            _draft.periods = v;
            _draft.ensureSlotsInitialised();
            _saveDraft();
          },
          onContinue: _nextStep,
        );
      case 2:
        return WeeklyBuilderStep(
          draft: _draft,
          onChanged: (v) {
            setState(() => _draft = v);
            _saveDraft();
          },
          onPublish: _publish,
          isPublishing: _isPublishing,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
