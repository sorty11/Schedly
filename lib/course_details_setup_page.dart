import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/course_component.dart';
import 'models/course.dart';
import 'models/timetable_entry.dart';
import 'services/course_configuration_service.dart';
import 'theme/theme.dart';
import 'app_settings.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'widgets/schedly_card.dart';
import 'widgets/schedly_text_field.dart';
import 'widgets/dashboard_layout.dart';
import 'widgets/section_header.dart';

class CourseDetailsSetupPage extends StatefulWidget {
  final String division;
  final bool isFromPublish;

  const CourseDetailsSetupPage({
    super.key,
    required this.division,
    this.isFromPublish = false,
  });

  @override
  State<CourseDetailsSetupPage> createState() => _CourseDetailsSetupPageState();
}

class _CourseDetailsSetupPageState extends State<CourseDetailsSetupPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  
  // courseName -> List of Component states
  final Map<String, List<_ComponentSetupState>> _courses = {};
  final Map<String, TextEditingController> _courseCodeControllers = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      
      // Timetable occurrences: componentId -> count
      final Map<String, int> componentOccurrences = {};
      final Set<String> allComponentIds = {};
      
      for (final day in days) {
        final snap = await FirebaseFirestore.instance
            .collection('timetables')
            .doc(widget.division)
            .collection(day)
            .where('isActive', isEqualTo: true)
            .get();
            
        for (final doc in snap.docs) {
          final entry = TimetableEntry.fromFirestore(doc);
          if (entry.isAcademic) {
            componentOccurrences[entry.subject] = (componentOccurrences[entry.subject] ?? 0) + 1;
            allComponentIds.add(entry.subject);
          }
        }
      }
      
      // Load existing metadata
      final existingComps = await CourseConfigurationService.getMetadata(widget.division, forceRefresh: true);
      final Map<String, CourseComponent> existingMap = {
        for (var c in existingComps) c.componentId: c
      };
      
      // Group by Course Name
      for (final compId in allComponentIds) {
        final existing = existingMap[compId];
        final courseName = existing?.courseName ?? TimetableEntry.stripComponentSuffix(compId);
        
        if (!_courses.containsKey(courseName)) {
          _courses[courseName] = [];
          _courseCodeControllers[courseName] = TextEditingController(text: existing?.courseCode ?? '');
        }
        
        // Determine type
        String compType = existing?.componentType ?? 'Theory';
        if (existing == null) {
          final lowerId = compId.toLowerCase();
          if (lowerId.endsWith(' lab')) compType = 'Lab';
          else if (lowerId.endsWith(' tutorial')) compType = 'Tutorial';
          else if (lowerId.endsWith(' project')) compType = 'Project';
          else if (lowerId.endsWith(' seminar')) compType = 'Seminar';
          else if (lowerId.endsWith(' workshop')) compType = 'Workshop';
          else if (lowerId.endsWith(' viva')) compType = 'Viva';
          else if (courseName == compId.trim()) compType = 'Combined';
        }
        
        final recHours = (componentOccurrences[compId] ?? 1) * 16;
        
        _courses[courseName]!.add(_ComponentSetupState(
          componentId: compId,
          componentType: compType,
          targetHours: existing?.targetHours ?? 0,
          credits: existing?.credits ?? 0,
          facultyId: existing?.facultyId ?? '',
          recommendedHours: recHours,
          createdAt: existing?.createdAt ?? DateTime.now(),
        ));
      }
      
      // Attach listeners for dynamic sum updates
      for (final list in _courses.values) {
        for (final comp in list) {
          comp.hoursController.addListener(() => setState(() {}));
        }
      }
      
    } catch (e) {
      debugPrint('Error loading subjects for setup: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  void dispose() {
    for (var c in _courseCodeControllers.values) { c.dispose(); }
    for (var list in _courses.values) {
      for (var comp in list) { comp.dispose(); }
    }
    super.dispose();
  }

  int get _totalSemesterHours {
    int total = 0;
    for (var list in _courses.values) {
      for (var comp in list) {
        total += int.tryParse(comp.hoursController.text) ?? 0;
      }
    }
    return total;
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

  Future<void> _save() async {
    // Validate
    String? invalidComp;
    for (var list in _courses.values) {
      for (var comp in list) {
        final hours = int.tryParse(comp.hoursController.text);
        if (hours == null || hours <= 0) {
          invalidComp = comp.componentId;
          comp.focusNode.requestFocus();
          break;
        }
      }
      if (invalidComp != null) break;
    }
    
    if (invalidComp != null) {
      _showErrorDialog('Validation Error', 'Target Hours for "$invalidComp" must be greater than zero.');
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      List<CourseComponent> metaList = [];
      for (var entry in _courses.entries) {
        final courseName = entry.key;
        final courseCode = _courseCodeControllers[courseName]!.text.trim();
        
        for (var comp in entry.value) {
          metaList.add(CourseComponent(
            componentId: comp.componentId,
            componentType: comp.componentType,
            courseName: courseName,
            courseCode: courseCode,
            targetHours: int.parse(comp.hoursController.text),
            credits: int.tryParse(comp.creditsController.text) ?? 0,
            facultyId: comp.facultyController.text.trim(),
            createdAt: comp.createdAt,
            sectionId: widget.division,
            semesterId: AppSettings.sectionId,
          ));
        }
      }
      
      await CourseConfigurationService.saveMetadata(widget.division, metaList);
      
      if (!mounted) return;
      AppDialogs.showSnackBar(context: context, message: 'Course details saved!');
      Navigator.pop(context);
    } catch (e) {
      _showErrorDialog('Save Error', 'Failed to save course details. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: SafeArea(
        child: Workspace(
          children: [
            SectionHeader(
              title: 'Course Details Setup',
              trailing: widget.isFromPublish
                  ? TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Skip', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                    )
                  : null,
            ),
            if (_courses.isEmpty)
              const Center(
                child: FloatingEmptyState(
                  icon: Icons.book_rounded,
                  title: 'No Subjects Found',
                  subtitle: 'We could not find any subjects in your timetable.',
                ),
              )
            else ...[
              for (var courseName in _courses.keys)
                _buildCourseCard(courseName, sem, colorScheme, isDark),
              const SizedBox(height: AppSpacing.xl),
              _buildSummaryAndSave(sem, colorScheme, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(String courseName, AppSemanticColors sem, ColorScheme cs, bool isDark) {
    final components = _courses[courseName]!;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SchedlyCard(
        variant: SchedlyCardVariant.elevated,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: components.any((c) => c.hoursController.text.isEmpty),
            title: Text(courseName, style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
            subtitle: Text('${components.length} Component${components.length > 1 ? 's' : ''}', 
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600)),
            childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.sm),
              SchedlyTextField(
                controller: _courseCodeControllers[courseName]!,
                labelText: 'Course Code (optional)',
                prefixIcon: Icons.tag_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              ...components.map((comp) => _buildComponentEditor(comp, sem, cs, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentEditor(_ComponentSetupState comp, AppSemanticColors sem, ColorScheme cs, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.2) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: sem.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(comp.componentId, style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(comp.componentType, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
              ),
            ],
          ),
          if (comp.recommendedHours > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text('Recommended: ${comp.recommendedHours} Hours', 
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SchedlyTextField(
                  controller: comp.hoursController,
                  focusNode: comp.focusNode,
                  labelText: 'Target Hours *',
                  prefixIcon: Icons.access_time_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SchedlyTextField(
                  controller: comp.creditsController,
                  labelText: 'Credits',
                  prefixIcon: Icons.star_outline_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SchedlyTextField(
            controller: comp.facultyController,
            labelText: 'Faculty Name',
            prefixIcon: Icons.person_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndSave(AppSemanticColors sem, ColorScheme cs, bool isDark) {
    return SchedlyCard(
      variant: SchedlyCardVariant.elevated,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Courses', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: sem.onSurfaceMuted, fontWeight: FontWeight.w600)),
              Text('${_courses.length}', style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Total Semester Hours', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: sem.onSurfaceMuted, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var list in _courses.values)
            for (var comp in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(comp.componentId, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                    Text('${int.tryParse(comp.hoursController.text) ?? 0}', style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(color: sem.borderSubtle, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700)),
              Text('$_totalSemesterHours Hours', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w800, color: cs.primary)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Configure Now', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentSetupState {
  final String componentId;
  final String componentType;
  final int recommendedHours;
  final DateTime createdAt;
  
  final TextEditingController hoursController;
  final TextEditingController creditsController;
  final TextEditingController facultyController;
  final FocusNode focusNode = FocusNode();

  _ComponentSetupState({
    required this.componentId,
    required this.componentType,
    required this.recommendedHours,
    required int targetHours,
    required int credits,
    required String facultyId,
    required this.createdAt,
  }) : hoursController = TextEditingController(text: targetHours > 0 ? targetHours.toString() : ''),
       creditsController = TextEditingController(text: credits > 0 ? credits.toString() : ''),
       facultyController = TextEditingController(text: facultyId);

  void dispose() {
    hoursController.dispose();
    creditsController.dispose();
    facultyController.dispose();
    focusNode.dispose();
  }
}
