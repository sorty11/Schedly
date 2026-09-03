import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/theme.dart';
import '../app_settings.dart';
import 'faculty_sr_connection_service.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/floating_empty_state.dart';

class FacultySrConnectionsPage extends StatefulWidget {
  const FacultySrConnectionsPage({super.key});

  @override
  State<FacultySrConnectionsPage> createState() =>
      _FacultySrConnectionsPageState();
}

class _FacultySrConnectionsPageState extends State<FacultySrConnectionsPage> {
  bool _isLoading = true;
  List<_ConnectionItem> _connections = [];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
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

        final items = <_ConnectionItem>[];

        for (final div in divisions) {
          final subjects = List<String>.from(rawSubjects[div] ?? []);
          for (final subj in subjects) {
            items.add(_ConnectionItem(division: div, subject: subj));
          }
        }

        if (mounted) {
          setState(() {
            _connections = items;
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
          'Subject & SR Connections',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _connections.isEmpty
          ? const FloatingEmptyState(
              icon: Icons.hub_outlined,
              title: 'No Subject Connections',
              subtitle:
                  'No course assignments found to establish SR connections.',
            )
          : RefreshIndicator(
              onRefresh: _loadConnections,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.x2l),
                itemCount: _connections.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final item = _connections[index];

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
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: FutureBuilder<List<String>>(
                          future: FacultySrConnectionService.getAssignedSRs(
                            division: item.division,
                            subject: item.subject,
                          ),
                          builder: (context, snapshot) {
                            final srs = snapshot.data ?? [];
                            final hasSR = srs.isNotEmpty;

                            return Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
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
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.subject,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Section ${item.division.replaceAll('_', ' ')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: sem.onSurfaceMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            hasSR
                                                ? Icons.check_circle_rounded
                                                : Icons.info_outline_rounded,
                                            size: 14,
                                            color: hasSR
                                                ? sem.conducted
                                                : sem.warning,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              hasSR
                                                  ? 'SR: ${srs.join(', ')}'
                                                  : 'Awaiting SR assignment',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: hasSR
                                                    ? colorScheme.onSurface
                                                    : sem.warning,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
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

class _ConnectionItem {
  final String division;
  final String subject;

  _ConnectionItem({required this.division, required this.subject});
}
