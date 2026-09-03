import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/theme.dart';
import '../app_settings.dart';
import '../models/faculty_request.dart';
import 'faculty_request_sheet.dart';
import 'faculty_sr_connection_service.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/floating_empty_state.dart';

class FacultySectionsPage extends StatefulWidget {
  const FacultySectionsPage({super.key});

  @override
  State<FacultySectionsPage> createState() => _FacultySectionsPageState();
}

class _FacultySectionsPageState extends State<FacultySectionsPage> {
  bool _isLoading = true;
  List<String> _assignedDivisions = [];
  Map<String, List<String>> _subjectsMap = {};

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final uid = AppSettings.facultyId;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('faculty_profiles')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final divisions = List<String>.from(data['assignedDivisions'] ?? []);
        final rawSubjects = (data['subjects'] as Map<String, dynamic>?) ?? {};

        final parsedSubjects = <String, List<String>>{};
        rawSubjects.forEach((k, v) {
          if (v is List) {
            parsedSubjects[k] = List<String>.from(v);
          }
        });

        if (mounted) {
          setState(() {
            _assignedDivisions = divisions;
            _subjectsMap = parsedSubjects;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Sections',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedDivisions.isEmpty
          ? const FloatingEmptyState(
              icon: Icons.groups_outlined,
              title: 'No Sections Assigned',
              subtitle: 'You have not been assigned to any sections yet.',
            )
          : RefreshIndicator(
              onRefresh: _loadSections,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.x2l),
                itemCount: _assignedDivisions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final div = _assignedDivisions[index];
                  final subjects = _subjectsMap[div] ?? [];

                  return StaggeredListItem(
                    index: index,
                    child: AnimatedCard(
                      borderRadius: AppRadius.xl,
                      backgroundColor: sem.surfaceElevated,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: sem.borderSubtle, width: 1),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.domain_rounded,
                                    color: colorScheme.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Section ${div.replaceAll('_', ' ')}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${subjects.length} course${subjects.length == 1 ? '' : 's'} assigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: sem.onSurfaceMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => FacultyRequestSheet(
                                        requestType:
                                            FacultyRequestType.addExtra,
                                        prefillDivision: div,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Extra Lecture'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.xs,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Divider(color: sem.borderSubtle, height: 1),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'ASSIGNED SUBJECTS & SRs',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: sem.onSurfaceMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (subjects.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                child: Text(
                                  'No subjects mapped for this section.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: sem.onSurfaceMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ...subjects.map(
                                (subj) => _SubjectSrItem(
                                  division: div,
                                  subject: subj,
                                  sem: sem,
                                  colorScheme: colorScheme,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _SubjectSrItem extends StatelessWidget {
  final String division;
  final String subject;
  final AppSemanticColors sem;
  final ColorScheme colorScheme;

  const _SubjectSrItem({
    required this.division,
    required this.subject,
    required this.sem,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: FacultySrConnectionService.getAssignedSRs(
        division: division,
        subject: subject,
      ),
      builder: (context, snapshot) {
        final srs = snapshot.data ?? [];
        final hasSR = srs.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: sem.surfaceElevated2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: sem.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasSR
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : sem.onSurfaceMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasSR
                            ? Icons.person_rounded
                            : Icons.person_off_outlined,
                        size: 12,
                        color: hasSR ? colorScheme.primary : sem.onSurfaceMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasSR ? srs.join(', ') : 'No SR assigned',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasSR
                              ? colorScheme.primary
                              : sem.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
