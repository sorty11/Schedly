import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/subject_metadata.dart';
import 'models/timetable_entry.dart';
import 'services/subject_metadata_service.dart';
import 'theme/theme.dart';
import 'app_settings.dart';
import 'widgets/app_dialogs.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text('Course Details Setup', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: false,
        actions: [
          if (widget.isFromPublish)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Skip', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _subjects.isEmpty
          ? Center(
              child: Text('No subjects found in timetable.',
                  style: GoogleFonts.inter(color: sem.onSurfaceMuted)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _subjects.length,
                    itemBuilder: (context, index) {
                      final sub = _subjects[index];
                      return _buildSubjectCard(sub, sem, colorScheme, isDark);
                    },
                  ),
                ),
                _buildSummaryAndSave(sem, colorScheme, isDark),
              ],
            ),
    );
  }

  Widget _buildSubjectCard(String sub, AppSemanticColors sem, ColorScheme cs, bool isDark) {
    final recHours = _recommendedHours[sub] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sem.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _hoursControllers[sub]!.text.isEmpty,
          title: Text(sub, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
          subtitle: Text('Recommended: $recHours Hours', style: GoogleFonts.inter(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const SizedBox(height: 8),
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
                const SizedBox(width: 12),
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
            const SizedBox(height: 12),
            _buildTextField(
              controller: _hoursControllers[sub]!,
              focusNode: _hoursFocusNodes[sub],
              label: 'Total Teaching Hours *',
              icon: Icons.access_time_rounded,
              keyboardType: TextInputType.number,
              sem: sem,
              cs: cs,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _facultyControllers[sub]!,
              label: 'Faculty Name (optional)',
              icon: Icons.person_outline_rounded,
              sem: sem,
              cs: cs,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.3) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sem.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science_outlined, size: 18, color: sem.onSurfaceMuted),
                      const SizedBox(width: 8),
                      Text('Lab Subject', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
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
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: sem.onSurfaceMuted),
        prefixIcon: Icon(icon, size: 18, color: sem.onSurfaceMuted),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark 
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3) 
            : cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: sem.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: sem.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildSummaryAndSave(AppSemanticColors sem, ColorScheme cs, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated : cs.surface,
        border: Border(top: BorderSide(color: sem.borderSubtle)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Subjects', style: GoogleFonts.inter(fontSize: 14, color: sem.onSurfaceMuted, fontWeight: FontWeight.w600)),
              Text('${_subjects.length}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Total Semester Hours', style: GoogleFonts.inter(fontSize: 14, color: sem.onSurfaceMuted, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          ..._subjects.map((sub) {
            final text = _hoursControllers[sub]!.text;
            final hrs = int.tryParse(text) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sub, style: GoogleFonts.inter(fontSize: 14)),
                  Text('$hrs', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: sem.borderSubtle, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('$_totalSemesterHours Hours', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: cs.primary)),
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
                  : Text('Configure Now', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
