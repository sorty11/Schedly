import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/subject_metadata.dart';
import 'models/timetable_entry.dart';
import 'services/subject_metadata_service.dart';
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
  
  final List<String> _subjects = [];
  final Map<String, SubjectMetadata> _metadataMap = {};
  final Map<String, int> _recommendedHours = {};
  
  final Map<String, TextEditingController> _hoursControllers = {};
  final Map<String, TextEditingController> _codeControllers = {};
  final Map<String, TextEditingController> _creditsControllers = {};
  final Map<String, TextEditingController> _facultyControllers = {};
  final Map<String, bool> _isLabMap = {};
  
  final Map<String, FocusNode> _hoursFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      final Map<String, int> weeklyOccurrences = {};
      
      // Load occurrences from timetable
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
            weeklyOccurrences[entry.subject] = (weeklyOccurrences[entry.subject] ?? 0) + 1;
            if (!_subjects.contains(entry.subject)) {
              _subjects.add(entry.subject);
            }
          }
        }
      }
      
      // Load existing metadata if any
      final existing = await SubjectMetadataService.getMetadata(widget.division, forceRefresh: true);
      for (var m in existing) {
        _metadataMap[m.subjectName] = m;
      }
      
      // Setup controllers
      for (final sub in _subjects) {
        final occurrences = weeklyOccurrences[sub] ?? 1;
        _recommendedHours[sub] = occurrences * 16; // 16 weeks
        
        final m = _metadataMap[sub];
        
        _hoursControllers[sub] = TextEditingController(text: m != null && m.totalHours > 0 ? m.totalHours.toString() : '');
        _codeControllers[sub] = TextEditingController(text: m?.courseCode ?? '');
        _creditsControllers[sub] = TextEditingController(text: m != null && m.credits > 0 ? m.credits.toString() : '');
        _facultyControllers[sub] = TextEditingController(text: m?.faculty ?? '');
        _isLabMap[sub] = m?.isLab ?? false;
        
        _hoursFocusNodes[sub] = FocusNode();
        
        // Listen to hours changes for live summary update
        _hoursControllers[sub]!.addListener(() => setState(() {}));
      }
      
    } catch (e) {
      debugPrint('Error loading subjects for setup: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  void dispose() {
    for (var c in _hoursControllers.values) { c.dispose(); }
    for (var c in _codeControllers.values) { c.dispose(); }
    for (var c in _creditsControllers.values) { c.dispose(); }
    for (var c in _facultyControllers.values) { c.dispose(); }
    for (var f in _hoursFocusNodes.values) { f.dispose(); }
    super.dispose();
  }

  int get _totalSemesterHours {
    int total = 0;
    for (var sub in _subjects) {
      final text = _hoursControllers[sub]!.text;
      total += int.tryParse(text) ?? 0;
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
    String? invalidSubject;
    for (var sub in _subjects) {
      final hoursStr = _hoursControllers[sub]!.text;
      final hours = int.tryParse(hoursStr);
      if (hours == null || hours <= 0) {
        invalidSubject = sub;
        break;
      }
    }
    
    if (invalidSubject != null) {
      _hoursFocusNodes[invalidSubject]?.requestFocus();
      _showErrorDialog('Validation Error', 'Total Teaching Hours for "$invalidSubject" must be greater than zero.');
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      List<SubjectMetadata> metaList = [];
      for (var sub in _subjects) {
        metaList.add(SubjectMetadata(
          id: _metadataMap[sub]?.id ?? '',
          subjectName: sub,
          courseCode: _codeControllers[sub]!.text.trim(),
          totalHours: int.parse(_hoursControllers[sub]!.text),
          credits: int.tryParse(_creditsControllers[sub]!.text) ?? 0,
          faculty: _facultyControllers[sub]!.text.trim(),
          isLab: _isLabMap[sub] ?? false,
          createdAt: _metadataMap[sub]?.createdAt ?? DateTime.now(),
          sectionId: widget.division,
          semesterId: AppSettings.sectionId,
        ));
      }
      
      await SubjectMetadataService.saveMetadata(widget.division, metaList);
      
      if (!mounted) return;
      AppDialogs.showSnackBar(
        context: context,
        message: 'Course details saved!',
      );
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Workspace(
      children: [
        SectionHeader(
          title: 'Course Details Setup',
          trailing: widget.isFromPublish
              ? TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Skip', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                )
              : null,
        ),
        if (_subjects.isEmpty)
          Center(
            child: FloatingEmptyState(
              icon: Icons.book_rounded,
              title: 'No Subjects Found',
              subtitle: 'We could not find any subjects in your timetable.',
            ),
          )
        else ...[
          for (var sub in _subjects)
            _buildSubjectCard(sub, sem, colorScheme, isDark),
          const SizedBox(height: AppSpacing.xl),
          _buildSummaryAndSave(sem, colorScheme, isDark),
        ],
      ],
    );
  }

  Widget _buildSubjectCard(String sub, AppSemanticColors sem, ColorScheme cs, bool isDark) {
    final recHours = _recommendedHours[sub] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SchedlyCard(
        variant: SchedlyCardVariant.elevated,
        padding: EdgeInsets.zero,
        child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _hoursControllers[sub]!.text.isEmpty,
          title: Text(sub, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
          subtitle: Text('Recommended: $recHours Hours', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600)),
          childrenPadding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _codeControllers[sub]!,
                    label: 'Course Code (optional)',
                    icon: Icons.tag_rounded,
                    sem: sem,
                    cs: cs,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildTextField(
                    controller: _creditsControllers[sub]!,
                    label: 'Credits (optional)',
                    icon: Icons.star_outline_rounded,
                    keyboardType: TextInputType.number,
                    sem: sem,
                    cs: cs,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTextField(
              controller: _hoursControllers[sub]!,
              focusNode: _hoursFocusNodes[sub],
              label: 'Total Teaching Hours *',
              icon: Icons.access_time_rounded,
              keyboardType: TextInputType.number,
              sem: sem,
              cs: cs,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTextField(
              controller: _facultyControllers[sub]!,
              label: 'Faculty Name (optional)',
              icon: Icons.person_outline_rounded,
              sem: sem,
              cs: cs,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.3) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: sem.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science_outlined, size: 18, color: sem.onSurfaceMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Lab Subject', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Switch(
                    value: _isLabMap[sub] ?? false,
                    onChanged: (val) => setState(() => _isLabMap[sub] = val),
                    activeColor: cs.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    required AppSemanticColors sem,
    required ColorScheme cs,
  }) {
    return SchedlyTextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      labelText: label,
      prefixIcon: icon,
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
              Text('Total Subjects', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: sem.onSurfaceMuted, fontWeight: FontWeight.w600)),
              Text('${_subjects.length}', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Total Semester Hours', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: sem.onSurfaceMuted, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._subjects.map((sub) {
            final text = _hoursControllers[sub]!.text;
            final hrs = int.tryParse(text) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sub, style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                  Text('$hrs', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(color: sem.borderSubtle, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700)),
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
                  : Text('Configure Now', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
