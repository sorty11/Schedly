import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/theme.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/floating_empty_state.dart';

/// Standalone announcements page (kept for backward compatibility).
/// The primary entry point is now via UpdatesPage announcements tab.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  Future<String?> _getDivision() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('section_id') ?? prefs.getString('selected_division');
  }

  Color _priorityColor(String priority, AppSemanticColors sem) {
    switch (priority.toLowerCase()) {
      case 'high': return sem.cancelled;
      case 'low': return sem.conducted;
      default: return sem.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<String?>(
        future: _getDivision(),
        builder: (context, divSnap) {
          if (!divSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
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

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sections')
                .doc(division)
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return FloatingEmptyState(
                  icon: Icons.campaign_rounded,
                  title: 'No announcements',
                  subtitle: 'Your CR will post updates here',
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x2l,
                  AppSpacing.lg,
                  AppSpacing.x2l,
                  AppSpacing.x6l,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final priority = data['priority']?.toString() ?? 'Normal';
                  final color = _priorityColor(priority, sem);

                  return StaggeredListItem(
                    index: index,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: AnimatedCard(
                        backgroundColor:
                            isDark ? sem.surfaceElevated : Colors.white,
                        borderRadius: AppRadius.xl,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(
                              color: isDark
                                  ? sem.borderSubtle
                                  : const Color(0xFFE8E8F0),
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
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.full),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
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
        },
      ),
    );
  }
}
