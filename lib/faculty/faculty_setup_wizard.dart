import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme.dart';
import '../nmims_structure.dart';
import '../widgets/animations/animated_button.dart';
import '../app_settings.dart';
import '../timetable_manager.dart';
import 'faculty_home_page.dart';
import '../widgets/schedly_card.dart';

class FacultySetupWizard extends StatefulWidget {
  const FacultySetupWizard({super.key});

  @override
  State<FacultySetupWizard> createState() => _FacultySetupWizardState();
}

class _FacultySetupWizardState extends State<FacultySetupWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  final Set<String> _selectedDivisions = {};

  // Mapping of division -> available subjects
  final Map<String, List<String>> _availableSubjects = {};

  // Mapping of division -> selected subjects
  final Map<String, Set<String>> _selectedSubjects = {};

  final _departmentController = TextEditingController();
  final _designationController = TextEditingController();
  final _cabinController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _departmentController.dispose();
    _designationController.dispose();
    _cabinController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubjectsForDivisions() async {
    setState(() => _isLoading = true);
    try {
      _availableSubjects.clear();
      for (final div in _selectedDivisions) {
        final uniqueSubjects = await TimetableManager.getUniqueSubjects(
          division: div,
        );

        _availableSubjects[div] = uniqueSubjects;
        _selectedSubjects[div] = {}; // Initialize empty selection
      }

      setState(() => _currentStep = 2);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading subjects: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeSetup() async {
    if (_departmentController.text.trim().isEmpty ||
        _designationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Department and Designation are required'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = AppSettings.facultyId ?? '';

      final subjectMap = <String, List<String>>{};
      for (final div in _selectedDivisions) {
        subjectMap[div] = _selectedSubjects[div]?.toList() ?? [];
      }

      final profileData = {
        'department': _departmentController.text.trim(),
        'designation': _designationController.text.trim(),
        'cabin': _cabinController.text.trim(),
        'assignedDivisions': _selectedDivisions.toList(),
        'subjects': subjectMap,
        'setupComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        await FirebaseFirestore.instance
            .collection('faculty_profiles')
            .doc(uid)
            .set(profileData, SetOptions(merge: true));
      } catch (e) {
        debugPrint(
          '[FS_ERROR]\ncollection: faculty_profiles\ndocument: $uid\noperation: WRITE\nexception: $e',
        );
        rethrow;
      }

      DocumentSnapshot<Map<String, dynamic>> profileSnap;
      try {
        profileSnap = await FirebaseFirestore.instance
            .collection('faculty_profiles')
            .doc(uid)
            .get();
      } catch (e) {
        debugPrint(
          '[FS_ERROR]\ncollection: faculty_profiles\ndocument: $uid\noperation: READ\nexception: $e',
        );
        rethrow;
      }
      final data = profileSnap.data()!;

      await AppSettings.saveFacultyDetails(
        name: data['name'] ?? 'Faculty',
        email: data['email'] ?? '',
        department: profileData['department'] as String,
        designation: profileData['designation'] as String,
        cabin: profileData['cabin'] as String,
        assignedDivisions: _selectedDivisions.toList(),
      );

      await AppSettings.completeFacultySetup();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FacultyHomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving setup: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Professional Details',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Please provide your academic information.',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.x2l),
        TextField(
          controller: _departmentController,
          decoration: InputDecoration(
            labelText: 'Department (e.g., Computer Engineering)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _designationController,
          decoration: InputDecoration(
            labelText: 'Designation (e.g., Assistant Professor)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _cabinController,
          decoration: InputDecoration(
            labelText: 'Cabin / Office Location (Optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        const Spacer(),
        AnimatedButton(
          onPressed: () {
            if (_departmentController.text.trim().isEmpty ||
                _designationController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please fill all required fields'),
                ),
              );
              return;
            }
            setState(() => _currentStep = 1);
          },
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _currentStep = 0),
            ),
            Expanded(
              child: Text(
                'Select Divisions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Select all the divisions you teach across all branches and years.',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sections')
                .where('active', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No active divisions found. CRs must setup their portals first.',
                  ),
                );
              }

              // Group by branch
              final Map<String, List<String>> branchDivs = {};
              for (var d in docs) {
                final id = d.id;
                final branch = d['branch'] as String;
                branchDivs.putIfAbsent(branch, () => []).add(id);
              }

              return ListView.builder(
                itemCount: branchDivs.length,
                itemBuilder: (context, index) {
                  final branch = branchDivs.keys.elementAt(index);
                  final divs = branchDivs[branch]!..sort();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          branch,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      ...divs.map((div) {
                        final docData =
                            docs.firstWhere((d) => d.id == div).data()
                                as Map<String, dynamic>;
                        final displayYear = docData['academicYear'];
                        final displayDiv = docData['division'];
                        return CheckboxListTile(
                          title: Text('$displayYear - Div $displayDiv'),
                          value: _selectedDivisions.contains(div),
                          onChanged: (val) {
                            setState(() {
                              if (val == true)
                                _selectedDivisions.add(div);
                              else
                                _selectedDivisions.remove(div);
                            });
                          },
                        );
                      }).toList(),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AnimatedButton(
            onPressed: _selectedDivisions.isEmpty
                ? null
                : _fetchSubjectsForDivisions,
            isLoading: _isLoading,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int totalSelected = 0;
    final allSelectedSubjects = <String>[];
    for (final div in _selectedDivisions) {
      final selected = _selectedSubjects[div] ?? {};
      totalSelected += selected.length;
      allSelectedSubjects.addAll(selected);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _currentStep = 1),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 2 of 3',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select Subjects',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Select the specific subjects you teach in each assigned division.',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search subjects...',
            hintStyle: TextStyle(color: sem.onSurfaceMuted),
            prefixIcon: Icon(Icons.search_rounded, color: sem.onSurfaceMuted),
            filled: true,
            fillColor: isDark ? sem.surfaceElevated : const Color(0xFFF5F5F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: _selectedDivisions.length,
            padding: const EdgeInsets.only(bottom: 24),
            itemBuilder: (context, index) {
              final div = _selectedDivisions.elementAt(index);
              final allSubjects = _availableSubjects[div] ?? [];
              final subjects = allSubjects
                  .where((s) => s.toLowerCase().contains(_searchQuery))
                  .toList();

              final selectedCount = _selectedSubjects[div]?.length ?? 0;

              if (allSubjects.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x2l),
                child: SchedlyCard(
                  variant: SchedlyCardVariant.elevated,
                  padding: const EdgeInsets.all(AppSpacing.x2l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  div.replaceAll('_', ' '),
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${allSubjects.length} Subjects Available',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: sem.onSurfaceMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selectedCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xl,
                                ),
                              ),
                              child: Text(
                                '$selectedCount Selected',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (subjects.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No subjects match your search.',
                              style: TextStyle(color: sem.onSurfaceMuted),
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: subjects.map((subj) {
                            final isSelected = _selectedSubjects[div]!.contains(
                              subj,
                            );

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSubjects[div]!.remove(subj);
                                  } else {
                                    _selectedSubjects[div]!.add(subj);
                                  }
                                });
                                // Add haptic feedback or any micro-interaction if needed here
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : (isDark
                                            ? sem.surfaceElevated2
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : (isDark
                                              ? sem.borderSubtle
                                              : const Color(0xFFE0E0E0)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.menu_book_rounded,
                                      size: 18,
                                      color: isSelected
                                          ? Colors.white
                                          : colorScheme.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Flexible(
                                      child: Text(
                                        subj,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : colorScheme.onSurface,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (totalSelected > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: SchedlyCard(
                    variant: SchedlyCardVariant.standard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected Subjects ($totalSelected)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    for (final div in _selectedDivisions) {
                                      _selectedSubjects[div]?.clear();
                                    }
                                  });
                                },
                                child: Text(
                                  'Clear All',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sem.cancelled,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          allSelectedSubjects.toSet().join(', '),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: sem.onSurfaceMuted,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              AnimatedButton(
                onPressed: _isLoading ? null : _completeSetup,
                isLoading: _isLoading,
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Complete Setup',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: [_buildStep0(), _buildStep1(), _buildStep2()][_currentStep],
          ),
        ),
      ),
    );
  }
}
