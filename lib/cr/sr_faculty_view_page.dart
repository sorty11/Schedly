import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme.dart';
import '../faculty/faculty_sr_connection_service.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/floating_empty_state.dart';

class SRFacultyViewPage extends StatefulWidget {
  final String division;
  final String subject;

  const SRFacultyViewPage({
    super.key,
    required this.division,
    required this.subject,
  });

  @override
  State<SRFacultyViewPage> createState() => _SRFacultyViewPageState();
}

class _SRFacultyViewPageState extends State<SRFacultyViewPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _facultyList = [];

  @override
  void initState() {
    super.initState();
    _loadFaculty();
  }

  Future<void> _loadFaculty() async {
    final list = await FacultySrConnectionService.getAssignedFaculty(
      division: widget.division,
      subject: widget.subject,
    );
    if (mounted) {
      setState(() {
        _facultyList = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assigned Faculty',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _facultyList.isEmpty
          ? FloatingEmptyState(
              icon: Icons.person_off_outlined,
              title: 'No Faculty Assigned',
              subtitle:
                  'No faculty member is currently registered for ${widget.subject} in Section ${widget.division.replaceAll('_', ' ')}.',
            )
          : RefreshIndicator(
              onRefresh: _loadFaculty,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.x2l),
                itemCount: _facultyList.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final f = _facultyList[index];
                  final name = f['name'] ?? 'Faculty Member';
                  final email = f['email'] ?? '';
                  final cabin = f['cabin'] ?? '';
                  final department = f['department'] ?? '';
                  final designation = f['designation'] ?? 'Professor';

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
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.school_rounded,
                                    color: colorScheme.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$designation${department.isNotEmpty ? ' • $department' : ''}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: sem.onSurfaceMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Divider(color: sem.borderSubtle, height: 1),
                            const SizedBox(height: AppSpacing.md),
                            if (cabin.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.meeting_room_outlined,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Cabin: $cabin',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                            ],
                            if (email.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: sem.onSurfaceMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                            ],
                            Row(
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Subject: ${widget.subject} (Section ${widget.division.replaceAll('_', ' ')})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
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
