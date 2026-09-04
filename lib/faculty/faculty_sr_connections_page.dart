import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/theme.dart';
import '../app_settings.dart';
import '../data/course_aliases.dart';
import '../models/faculty_request.dart';
import 'faculty_request_sheet.dart';
import 'faculty_sr_connection_service.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/floating_empty_state.dart';
import '../onboarding/widgets/tutorial_target.dart';
import '../onboarding/services/feature_discovery_service.dart';

class FacultySrConnectionsPage extends StatefulWidget {
  const FacultySrConnectionsPage({super.key});

  @override
  State<FacultySrConnectionsPage> createState() =>
      _FacultySrConnectionsPageState();
}

class _FacultySrConnectionsPageState extends State<FacultySrConnectionsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_ConnectionItem> _connections = [];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final uid = AppSettings.facultyId ?? FirebaseAuth.instance.currentUser?.uid;
    final fallbackDivisions = AppSettings.facultyAssignedDivisions ?? [];

    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('faculty_profiles')
          .doc(uid)
          .get();

      final items = <_ConnectionItem>[];
      final seenPairs = <String>{};

      void addPair(String div, String subj) {
        final key = '${div.toLowerCase()}|${subj.toLowerCase()}';
        if (!seenPairs.contains(key) &&
            div.trim().isNotEmpty &&
            subj.trim().isNotEmpty) {
          seenPairs.add(key);
          items.add(
            _ConnectionItem(division: div.trim(), subject: subj.trim()),
          );
        }
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final divisions = FacultySrConnectionService.parseDivisions(
          data['assignedDivisions'],
        );
        final parsedSubjects = FacultySrConnectionService.parseSubjectsMap(
          data['subjects'],
        );

        final allDivisions = <String>{
          ...divisions,
          ...parsedSubjects.keys,
          ...fallbackDivisions,
        }.toList();

        for (final div in allDivisions) {
          final subjects = FacultySrConnectionService.getSubjectsForDivision(
            parsedSubjects,
            div,
          );
          for (final subj in subjects) {
            addPair(div, subj);
          }
        }

        // Fallback: check excelSchedule in profile if items are still empty
        if (items.isEmpty && data['excelSchedule'] is Iterable) {
          for (final row in (data['excelSchedule'] as Iterable)) {
            if (row is Map) {
              final rowDiv = row['division']?.toString() ?? '';
              final rowSubj = row['subject']?.toString() ?? '';
              if (rowDiv.isNotEmpty && rowSubj.isNotEmpty) {
                addPair(rowDiv, rowSubj);
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _connections = items;
          _isLoading = false;
        });
        if (items.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FeatureDiscoveryService.checkSrConnectionsDiscovery(context);
          });
        }
      }
    } catch (e) {
      debugPrint('[FacultySrConnectionsPage] Error loading connections: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to load subject connections. Tap retry to reload.';
          _isLoading = false;
        });
      }
    }
  }

  void _showConnectionDetails({
    required BuildContext context,
    required _ConnectionItem item,
    required List<String> srs,
    required bool isLoading,
    required bool hasError,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final fullName = courseAliases[item.subject.toUpperCase()] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: sem.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.x2l),
            ),
            border: Border.all(color: sem.borderSubtle),
          ),
          padding: const EdgeInsets.all(AppSpacing.x2l),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sem.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: colorScheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.subject,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (fullName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              fullName,
                              style: TextStyle(
                                fontSize: 13,
                                color: sem.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Divider(color: sem.borderSubtle, height: 1),
                const SizedBox(height: AppSpacing.lg),

                // Section Info
                Row(
                  children: [
                    Icon(
                      Icons.domain_rounded,
                      size: 20,
                      color: sem.onSurfaceMuted,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned Section',
                          style: TextStyle(
                            fontSize: 11,
                            color: sem.onSurfaceMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Section ${item.division.replaceAll('_', ' ')}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // SR Assignment Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.person_pin_rounded,
                      size: 20,
                      color: srs.isNotEmpty ? sem.conducted : sem.warning,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subject Representative (SR)',
                            style: TextStyle(
                              fontSize: 11,
                              color: sem.onSurfaceMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isLoading)
                            const Text(
                              'Checking SR assignment...',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else if (hasError)
                            Text(
                              'Unable to load SR assignment',
                              style: TextStyle(
                                fontSize: 14,
                                color: sem.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (srs.isNotEmpty)
                            ...srs.map(
                              (name) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            )
                          else
                            Text(
                              'No SR assigned for this subject yet',
                              style: TextStyle(
                                fontSize: 13,
                                color: sem.onSurfaceMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2l),

                // Quick Action
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FacultyRequestSheet(
                          requestType: FacultyRequestType.addExtra,
                          prefillDivision: item.division,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Request Extra Lecture for Section'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x2l),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: sem.cancelled,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sem.onSurfaceMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _loadConnections,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
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

                  final card = StaggeredListItem(
                    index: index,
                    child: FutureBuilder<List<String>>(
                      future: FacultySrConnectionService.getAssignedSRs(
                        division: item.division,
                        subject: item.subject,
                      ),
                      builder: (context, snapshot) {
                        final isLoading =
                            snapshot.connectionState == ConnectionState.waiting;
                        final hasError = snapshot.hasError;
                        final srs = snapshot.data ?? [];
                        final hasSR = srs.isNotEmpty;

                        final String srStatusText;
                        if (isLoading) {
                          srStatusText = 'Checking SR...';
                        } else if (hasError) {
                          srStatusText = 'SR status unavailable';
                        } else if (hasSR) {
                          srStatusText = 'SR: ${srs.join(', ')}';
                        } else {
                          srStatusText = 'Awaiting SR assignment';
                        }

                        final statusColor = hasSR
                            ? sem.conducted
                            : (hasError ? sem.warning : sem.onSurfaceMuted);

                        return AnimatedCard(
                          borderRadius: AppRadius.xl,
                          backgroundColor: sem.surfaceElevated,
                          onTap: () => _showConnectionDetails(
                            context: context,
                            item: item,
                            srs: srs,
                            isLoading: isLoading,
                            hasError: hasError,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(
                                color: sem.borderSubtle,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
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
                                          if (isLoading)
                                            SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: statusColor,
                                              ),
                                            )
                                          else
                                            Icon(
                                              hasSR
                                                  ? Icons.check_circle_rounded
                                                  : (hasError
                                                        ? Icons
                                                              .error_outline_rounded
                                                        : Icons
                                                              .info_outline_rounded),
                                              size: 14,
                                              color: statusColor,
                                            ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              srStatusText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: hasSR
                                                    ? colorScheme.onSurface
                                                    : statusColor,
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
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: sem.onSurfaceMuted,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );

                  if (index == 0) {
                    return TutorialTarget(
                      id: 'faculty_sr_connection_view',
                      child: card,
                    );
                  }
                  return card;
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
