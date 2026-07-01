import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/theme.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'widgets/animations/skeleton_components.dart';

class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key});

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String?> _getDivision() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('section_id') ?? prefs.getString('selected_division');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom App Bar ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x2l,
                AppSpacing.lg,
                AppSpacing.x2l,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Updates',
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                  ),
                ],
              ),
            ),

            // ── Custom Tab Bar ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.x2l,
                vertical: AppSpacing.sm,
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? sem.surfaceElevated : const Color(0xFFF0F0F8),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: sem.onSurfaceMuted,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: EdgeInsets.all(AppSpacing.xs),
                  tabs: const [
                    Tab(text: 'Timetable Changes'),
                    Tab(text: 'Announcements'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Tab Views ────────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<String?>(
                future: _getDivision(),
                builder: (context, divSnap) {
                  if (!divSnap.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    );
                  }
                  final division = divSnap.data;
                  if (division == null) {
                    return Center(
                      child: Text(
                        'No division selected.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _ChangesTab(division: division),
                      _AnnouncementsTab(division: division),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timetable Changes Tab ─────────────────────────────────────────────────────
class _ChangesTab extends StatefulWidget {
  final String division;

  const _ChangesTab({required this.division});

  @override
  State<_ChangesTab> createState() => _ChangesTabState();
}

class _ChangesTabState extends State<_ChangesTab> {
  late final Stream<QuerySnapshot> _changesStream;

  @override
  void initState() {
    super.initState();
    _changesStream = FirebaseFirestore.instance
        .collection('sections')
        .doc(widget.division)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Color _typeColor(String type, AppSemanticColors sem) {
    switch (type) {
      case 'cancel': return sem.cancelled;
      case 'add': return sem.success;
      case 'room_change': return sem.rescheduled;
      case 'time_change': return sem.warning;
      default: return sem.onSurfaceMuted;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'cancel': return Icons.cancel_rounded;
      case 'add': return Icons.add_circle_rounded;
      case 'room_change': return Icons.meeting_room_rounded;
      case 'time_change': return Icons.update_rounded;
      case 'edit': return Icons.edit_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'cancel': return 'Cancelled';
      case 'add': return 'Added';
      case 'room_change': return 'Room Changed';
      case 'time_change': return 'Rescheduled';
      case 'edit': return 'Updated';
      default: return 'Update';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: _changesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const UpdatesSkeleton();
        }

        final docs = snapshot.data?.docs ?? [];
        // Filter out announcement-type notifications
        final changes = docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['type'] != 'announcement')
            .toList();

        if (changes.isEmpty) {
          return FloatingEmptyState(
            icon: Icons.event_note_rounded,
            title: 'No changes yet',
            subtitle: 'Timetable updates will appear here',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.x2l,
            vertical: AppSpacing.sm,
          ),
          itemCount: changes.length,
          itemBuilder: (context, index) {
            final data = changes[index].data() as Map<String, dynamic>;
            final type = data['type']?.toString() ?? '';
            final color = _typeColor(type, sem);
            final icon = _typeIcon(type);
            final label = _typeLabel(type);

            return StaggeredListItem(
              index: index,
              child: Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: AnimatedCard(
                  backgroundColor: isDark ? sem.surfaceElevated : Colors.white,
                  borderRadius: AppRadius.xl,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border(
                        left: BorderSide(color: color, width: 3),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppRadius.full),
                                      ),
                                      child: Text(
                                        label.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  data['title']?.toString() ?? '',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  data['message']?.toString() ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Announcements Tab ─────────────────────────────────────────────────────────
class _AnnouncementsTab extends StatefulWidget {
  final String division;

  const _AnnouncementsTab({required this.division});

  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  late final Stream<QuerySnapshot> _announcementsStream;

  @override
  void initState() {
    super.initState();
    _announcementsStream = FirebaseFirestore.instance
        .collection('sections')
        .doc(widget.division)
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Color _priorityColor(String priority, AppSemanticColors sem) {
    switch (priority.toLowerCase()) {
      case 'high': return sem.cancelled;   // Red
      case 'low':  return sem.conducted;   // Green
      default:     return sem.warning;     // Amber for Normal
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return Icons.priority_high_rounded;
      case 'low':  return Icons.keyboard_arrow_down_rounded;
      default:     return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: _announcementsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const UpdatesSkeleton();
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return FloatingEmptyState(
            icon: Icons.campaign_rounded,
            title: 'No announcements',
            subtitle: 'Your CR will post updates here',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.x2l,
            vertical: AppSpacing.sm,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final priority = data['priority']?.toString() ?? 'Normal';
            final color = _priorityColor(priority, sem);
            final icon = _priorityIcon(priority);

            return StaggeredListItem(
              index: index,
              child: Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: AnimatedCard(
                  backgroundColor: isDark ? sem.surfaceElevated : Colors.white,
                  borderRadius: AppRadius.xl,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 12, color: color),
                                    const SizedBox(width: 5),
                                    Text(
                                      priority.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.campaign_rounded,
                                size: 16,
                                color: sem.onSurfaceMuted,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            data['title']?.toString() ?? '',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            data['message']?.toString() ?? '',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}