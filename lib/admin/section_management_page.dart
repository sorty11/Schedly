import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/theme.dart';
import '../widgets/schedly_text_field.dart';
import '../widgets/schedly_card.dart';
import '../models/section_config.dart';
import '../models/period_config.dart';
import '../nmims_structure.dart';
import '../services/division_membership_service.dart';
import '../widgets/animations/animated_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/security_utils.dart';
import '../widgets/app_dialogs.dart';

import '../utils/responsive_utils.dart';

class SectionManagementPage extends StatefulWidget {
  const SectionManagementPage({super.key});

  @override
  State<SectionManagementPage> createState() => _SectionManagementPageState();
}

class _SectionManagementPageState extends State<SectionManagementPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Section Management', style: TextStyle(fontFamily: 'Outfit')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () => _createSection(context),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: const StadiumBorder(),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 4,
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Section', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: SchedlyTextField(
              hintText: 'Search Sections...',
              prefixIcon: Icons.search_rounded,
              onChanged: (val) {
                setState(() => _searchQuery = val.toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('sections').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final filteredDocs = docs.where((doc) {
                  return doc.id.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'No sections found.',
                      style: TextStyle(color: semanticColors.onSurfaceMuted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.x6l),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isActive = data['active'] ?? true;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: SchedlyCard(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: ListTile(
                          title: Text(doc.id, style: TextStyle(fontWeight: FontWeight.bold, decoration: isActive ? null : TextDecoration.lineThrough)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${data['branch']} • Div ${data['division']} • ${data['academicYear']}${data['semester'] != null ? ' • ${data['semester']}' : ''}',
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isActive ? 'Active' : 'Archived',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isActive ? Colors.green[700] : Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FutureBuilder<int>(
                                    future: DivisionMembershipService.getSectionRoleCount(doc.id, 'Student'),
                                    builder: (context, snap) => Text(
                                      '${snap.data ?? 0} Students',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FutureBuilder<int>(
                                    future: DivisionMembershipService.getSectionRoleCount(doc.id, 'Faculty'),
                                    builder: (context, snap) => Text(
                                      '${snap.data ?? 0} Faculty',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_rounded),
                                tooltip: 'Clone Section',
                                onPressed: () => _cloneSection(context, doc.id, data),
                              ),
                              IconButton(
                                icon: Icon(isActive ? Icons.archive_rounded : Icons.unarchive_rounded),
                                tooltip: isActive ? 'Archive' : 'Unarchive',
                                onPressed: () => _toggleArchive(doc.id, isActive),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _createSection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _CreateSectionSheet(),
    );
  }

  void _cloneSection(BuildContext context, String originalId, Map<String, dynamic> originalData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CreateSectionSheet(
        cloneFromData: originalData,
      ),
    );
  }

  Future<void> _toggleArchive(String id, bool currentlyActive) async {
    await FirebaseFirestore.instance.collection('sections').doc(id).update({
      'active': !currentlyActive,
    });
  }
}

class _CreateSectionSheet extends StatefulWidget {
  final Map<String, dynamic>? cloneFromData;
  const _CreateSectionSheet({this.cloneFromData});

  @override
  State<_CreateSectionSheet> createState() => _CreateSectionSheetState();
}

class _CreateSectionSheetState extends State<_CreateSectionSheet> {
  final _yearCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _divCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();
  bool _loading = false;
  List<String> _existingDivisions = [];

  @override
  void initState() {
    super.initState();
    if (widget.cloneFromData != null) {
      _yearCtrl.text = widget.cloneFromData!['academicYear'] ?? '';
      _branchCtrl.text = widget.cloneFromData!['branch'] ?? '';
      _divCtrl.text = widget.cloneFromData!['division'] ?? '';
      _semesterCtrl.text = widget.cloneFromData!['semester'] ?? '';
      _fetchExistingDivisions();
    }
    
    // Fetch divisions when year or branch changes
    _yearCtrl.addListener(_onFieldChanged);
    _branchCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _yearCtrl.removeListener(_onFieldChanged);
    _branchCtrl.removeListener(_onFieldChanged);
    _yearCtrl.dispose();
    _branchCtrl.dispose();
    _divCtrl.dispose();
    _semesterCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_yearCtrl.text.isNotEmpty && _branchCtrl.text.isNotEmpty) {
      _fetchExistingDivisions();
    }
  }

  Future<void> _fetchExistingDivisions() async {
    if (_yearCtrl.text.isEmpty || _branchCtrl.text.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sections')
          .where('academicYear', isEqualTo: _yearCtrl.text.trim())
          .where('branch', isEqualTo: _branchCtrl.text.trim())
          .get();
      final divs = snap.docs.map((d) => d.data()['division'] as String).toList();
      divs.sort();
      if (mounted) {
        setState(() {
          _existingDivisions = divs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching divisions: $e');
    }
  }

  Future<void> _save() async {
    final year = _yearCtrl.text.trim();
    final branch = _branchCtrl.text.trim();
    final div = _divCtrl.text.trim().toUpperCase();
    final sem = _semesterCtrl.text.trim();
    
    if (year.isEmpty || branch.isEmpty || div.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Year, Branch, and Division are required')));
      return;
    }

    setState(() => _loading = true);
    try {
      final sectionId = '${year.replaceAll(' ', '')}_${branch.replaceAll(' ', '')}_$div';
      
      final doc = await FirebaseFirestore.instance.collection('sections').doc(sectionId).get();
      if (doc.exists) {
        if (mounted) {
          AppDialogs.showError(context: context, title: 'Error', message: 'Section $sectionId already exists.');
        }
        setState(() => _loading = false);
        return;
      }
      
      Map<String, dynamic> dataToSave;
      
      if (widget.cloneFromData != null) {
        dataToSave = Map<String, dynamic>.from(widget.cloneFromData!);
        dataToSave['academicYear'] = year;
        dataToSave['branch'] = branch;
        dataToSave['division'] = div;
        if (sem.isNotEmpty) dataToSave['semester'] = sem;
        dataToSave['active'] = true;
      } else {
        final periods = [
          PeriodConfig(id: 'p1', name: 'Period 1', startTime: 900, endTime: 1000, isBreak: false),
          PeriodConfig(id: 'p2', name: 'Period 2', startTime: 1000, endTime: 1100, isBreak: false),
          PeriodConfig(id: 'br1', name: 'Break', startTime: 1100, endTime: 1130, isBreak: true),
          PeriodConfig(id: 'p3', name: 'Period 3', startTime: 1130, endTime: 1230, isBreak: false),
          PeriodConfig(id: 'p4', name: 'Period 4', startTime: 1230, endTime: 1330, isBreak: false),
          PeriodConfig(id: 'br2', name: 'Lunch', startTime: 1330, endTime: 1430, isBreak: true),
          PeriodConfig(id: 'p5', name: 'Period 5', startTime: 1430, endTime: 1530, isBreak: false),
          PeriodConfig(id: 'p6', name: 'Period 6', startTime: 1530, endTime: 1630, isBreak: false),
        ];
        
        List<String> generateDefaultBatches(String d, int count) {
          if (count == 1) return ['Whole Class'];
          final parts = d.trim().split(RegExp(r'[\s_]+'));
          String base = parts.isNotEmpty ? parts.last : 'Batch';
          if (base.isEmpty) base = 'Batch';
          return List.generate(count, (i) => '$base${i + 1}');
        }

        
        final config = SectionConfig(
          id: sectionId,
          academicYear: year,
          branch: branch,
          division: div,
          semester: sem.isNotEmpty ? sem : null,
          active: true,
          workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
          batches: generateDefaultBatches(div, 3),
          periods: periods,
        );
        dataToSave = config.toJson();
      }

      final batch = FirebaseFirestore.instance.batch();
      
      final actionRef = FirebaseFirestore.instance.collection('admin_actions').doc('${FirebaseAuth.instance.currentUser!.uid}_$sectionId');
      batch.set(actionRef, {
        'masterHash': SecurityUtils.masterHash,
        'action': widget.cloneFromData != null ? 'cloneSection' : 'createSection',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final sectionRef = FirebaseFirestore.instance.collection('sections').doc(sectionId);
      batch.set(sectionRef, dataToSave);

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      AppDialogs.showSuccess(context: context, title: 'Success', message: 'Section created successfully');
    } catch (e) {
      debugPrint('Section Creation Error: $e');
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Error',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _generatedId {
    final year = _yearCtrl.text.trim().replaceAll(' ', '');
    final branch = _branchCtrl.text.trim().replaceAll(' ', '');
    final div = _divCtrl.text.trim();
    if (year.isEmpty && branch.isEmpty && div.isEmpty) return 'Section ID Preview';
    return '${year.isEmpty ? 'Year' : year}_${branch.isEmpty ? 'Branch' : branch}_${div.isEmpty ? 'Div' : div}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.cloneFromData != null ? 'Clone Section' : 'Create Section';
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveUtils.constrainedFormBox(
            context,
            maxWidth: 500,
            child: Padding(
              padding: ResponsiveUtils.getBottomSheetMargin(context).copyWith(top: AppSpacing.xl, bottom: AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              const SizedBox(height: AppSpacing.md),
              
              DropdownButtonFormField<String>(
                value: _yearCtrl.text.isEmpty ? null : _yearCtrl.text,
                decoration: InputDecoration(
                  labelText: 'Academic Year',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: NMIMSStructure.academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _yearCtrl.text = val);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              
              DropdownButtonFormField<String>(
                value: _branchCtrl.text.isEmpty ? null : _branchCtrl.text,
                decoration: InputDecoration(
                  labelText: 'Department/Branch',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: NMIMSStructure.branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _branchCtrl.text = val;
                      _divCtrl.text = ''; // Reset division when branch changes
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              
              if (_branchCtrl.text.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_existingDivisions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs),
                        child: Text('Existing divisions: ${_existingDivisions.join(', ')}', 
                          style: TextStyle(color: semanticColors.onSurfaceMuted, fontSize: 12)),
                      ),
                    SchedlyTextField(
                      controller: _divCtrl, 
                      labelText: 'Division', 
                      hintText: 'e.g. A, B, C or custom name',
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ]
                ),

              SchedlyTextField(controller: _semesterCtrl, labelText: 'Semester (Optional)', hintText: 'e.g. Semester 3'),
              const SizedBox(height: AppSpacing.lg),

              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: semanticColors.surfaceTinted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: semanticColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generated Section ID', style: TextStyle(fontSize: 12, color: semanticColors.onSurfaceMuted)),
                    const SizedBox(height: 4),
                    Text(_generatedId, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),
              AnimatedButton(
                onPressed: _loading ? null : _save,
                isLoading: _loading,
                child: Text(title),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}
