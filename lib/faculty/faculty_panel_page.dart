import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/theme.dart';
import '../app_settings.dart';
import '../models/faculty_request.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../create_announcement_page.dart';

import 'faculty_sections_page.dart';
import 'faculty_sr_connections_page.dart';
import 'faculty_timetable_page.dart';
import 'faculty_conflicts_page.dart';
import 'faculty_request_sheet.dart';
import 'faculty_requests_history_page.dart';
import 'faculty_profile_page.dart';

class FacultyPanelPage extends StatefulWidget {
  const FacultyPanelPage({super.key});

  @override
  State<FacultyPanelPage> createState() => _FacultyPanelPageState();
}

class _FacultyPanelPageState extends State<FacultyPanelPage> {
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingRequestsCount();
  }

  Future<void> _loadPendingRequestsCount() async {
    final uid = AppSettings.facultyId;
    final divisions = AppSettings.facultyAssignedDivisions ?? [];
    if (uid == null || divisions.isEmpty) return;

    try {
      int count = 0;
      for (final div in divisions) {
        final snap = await FirebaseFirestore.instance
            .collection('sections')
            .doc(div)
            .collection('faculty_requests')
            .where('facultyId', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .get();
        count += snap.docs.length;
      }
      if (mounted) setState(() => _pendingRequestsCount = count);
    } catch (_) {}
  }

  Widget _buildSectionLabel(String label, {int staggerIndex = 0}) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return StaggeredListItem(
      index: staggerIndex,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xs,
          bottom: AppSpacing.sm,
          top: AppSpacing.lg,
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: sem.onSurfaceMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required int staggerIndex,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    Widget? trailingBadge,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return StaggeredListItem(
      index: staggerIndex,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AnimatedCard(
          onTap: onTap,
          borderRadius: AppRadius.xl,
          backgroundColor: sem.surfaceElevated,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: sem.borderSubtle, width: 1),
            ),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: sem.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailingBadge != null) ...[
                  trailingBadge,
                  const SizedBox(width: AppSpacing.sm),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: sem.onSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final name = AppSettings.facultyName ?? 'Faculty Member';
    final designation = AppSettings.facultyDesignation ?? 'Professor';
    final department = AppSettings.facultyDepartment ?? 'Department';
    final cabin = AppSettings.facultyCabin ?? '';
    final divisions = AppSettings.facultyAssignedDivisions ?? [];

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'Faculty Control Panel',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient Header Card ───────────────────────────────────────
            StaggeredListItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.x2l),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$designation • $department',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Text(
                                  '${divisions.length} Section${divisions.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (cabin.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    'Cabin $cabin',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Teaching & Sections ────────────────────────────────────────
            _buildSectionLabel('Teaching & Sections', staggerIndex: 1),
            _buildActionCard(
              staggerIndex: 2,
              icon: Icons.groups_rounded,
              title: 'My Sections',
              subtitle:
                  'View taught sections and subjects (${divisions.map((d) => d.replaceAll('_', ' ')).join(', ')})',
              color: colorScheme.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FacultySectionsPage()),
              ),
            ),
            _buildActionCard(
              staggerIndex: 3,
              icon: Icons.hub_rounded,
              title: 'My Subject / SR Connections',
              subtitle:
                  'View assigned Subject Representatives for your courses',
              color: AppColors.secondary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FacultySrConnectionsPage(),
                ),
              ),
            ),

            // ── Timetable & Schedule ───────────────────────────────────────
            _buildSectionLabel('Timetable & Schedule', staggerIndex: 4),
            _buildActionCard(
              staggerIndex: 5,
              icon: Icons.calendar_month_rounded,
              title: 'My Timetable',
              subtitle: 'Consolidated schedule with real-time CR/SR overrides',
              color: colorScheme.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FacultyTimetablePage()),
              ),
            ),
            _buildActionCard(
              staggerIndex: 6,
              icon: Icons.warning_amber_rounded,
              title: 'Timetable Conflicts',
              subtitle: 'Detect overlaps and notify affected section CRs',
              color: sem.cancelled,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FacultyConflictsPage()),
              ),
            ),

            // ── Coordination & Requests ────────────────────────────────────
            _buildSectionLabel('Lecture Requests', staggerIndex: 7),
            _buildActionCard(
              staggerIndex: 8,
              icon: Icons.add_circle_outline_rounded,
              title: 'Request Extra Lecture',
              subtitle: 'Propose extra session to Section CR and Subject SR',
              color: sem.conducted,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const FacultyRequestSheet(
                  requestType: FacultyRequestType.addExtra,
                ),
              ),
            ),
            _buildActionCard(
              staggerIndex: 9,
              icon: Icons.cancel_outlined,
              title: 'Request Cancellation',
              subtitle: 'Propose lecture cancellation for upcoming date',
              color: sem.cancelled,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const FacultyRequestSheet(
                  requestType: FacultyRequestType.cancel,
                ),
              ),
            ),
            _buildActionCard(
              staggerIndex: 10,
              icon: Icons.history_rounded,
              title: 'Lecture Requests History',
              subtitle: 'Track status of your submitted requests',
              color: sem.warning,
              trailingBadge: _pendingRequestsCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sem.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '$_pendingRequestsCount Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sem.warning,
                        ),
                      ),
                    )
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FacultyRequestsHistoryPage(),
                ),
              ),
            ),

            // ── Communication ──────────────────────────────────────────────
            _buildSectionLabel('Communication', staggerIndex: 11),
            _buildActionCard(
              staggerIndex: 12,
              icon: Icons.campaign_rounded,
              title: 'Create Announcement',
              subtitle:
                  'Post announcements targeted by Section, Batch, or Subject',
              color: colorScheme.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateAnnouncementPage(),
                ),
              ),
            ),

            // ── Profile ────────────────────────────────────────────────────
            _buildSectionLabel('Profile', staggerIndex: 13),
            _buildActionCard(
              staggerIndex: 14,
              icon: Icons.person_outline_rounded,
              title: 'Faculty Profile',
              subtitle: 'View cabin, department, designation, and contact info',
              color: sem.onSurfaceMuted,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FacultyProfilePage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
