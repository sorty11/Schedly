import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../services/assignment_service.dart';
import '../app_settings.dart';
import '../user_roles.dart';
import '../theme/theme.dart';
import '../widgets/animations/floating_empty_state.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/skeleton_components.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/ads/schedly_banner_ad.dart';
import '../services/ad_service.dart';
import 'widgets/assignment_card.dart';
import 'widgets/assignment_reminder_settings_sheet.dart';
import 'create_assignment_page.dart';

class AssignmentsPage extends StatefulWidget {
  final String? division;
  final bool isEmbedded;

  const AssignmentsPage({
    super.key,
    this.division,
    this.isEmbedded = false,
  });

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'submitted', 'overdue'

  String get _effectiveSectionId {
    return widget.division ??
        AppSettings.sectionId ??
        AppSettings.division ??
        '';
  }

  bool get _isCRorSR =>
      AppSettings.currentRole == UserRole.cr ||
      AppSettings.currentRole == UserRole.sr;

  bool _canManageAssignment(Assignment item) {
    if (AppSettings.currentRole == UserRole.cr) return true;
    if (AppSettings.currentRole == UserRole.sr) {
      final srSub = AppSettings.srSubject?.trim().toLowerCase();
      if (srSub != null && srSub.isNotEmpty) {
        return item.subject.trim().toLowerCase() == srSub;
      }
      return true;
    }
    return false;
  }

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>()!;
    final isDark = theme.brightness == Brightness.dark;
    final sec = _effectiveSectionId;
    final uid = _currentUid ?? '';

    Widget content = sec.isEmpty
        ? Center(
            child: Text(
              'No division selected.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        : StreamBuilder<List<Assignment>>(
            stream: AssignmentService.streamAssignments(
              sectionId: sec,
              studentBatch: AppSettings.studentBatch,
              isCRorSR: _isCRorSR,
            ),
            builder: (context, assignSnap) {
              if (assignSnap.connectionState == ConnectionState.waiting &&
                  !assignSnap.hasData) {
                return const UpdatesSkeleton();
              }

              if (assignSnap.hasError) {
                debugPrint('[ASSIGNMENTS_STREAM_ERROR] ${assignSnap.error}');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Unable to load assignments: ${assignSnap.error}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: sem.cancelled,
                      ),
                    ),
                  ),
                );
              }

              final assignments = assignSnap.data ?? [];

              return StreamBuilder<Map<String, AssignmentSubmission>>(
                stream: uid.isNotEmpty
                    ? AssignmentService.streamSubmissions(studentId: uid)
                    : Stream.value({}),
                builder: (context, subSnap) {
                  final submissions = subSnap.data ?? {};

                  // Apply filter
                  final filtered = assignments.where((a) {
                    final sub = submissions[a.id];
                    final isSubmitted = sub?.isSubmitted ?? false;
                    final isOverdue = !isSubmitted && a.isOverdue;

                    if (_selectedFilter == 'pending') {
                      return !isSubmitted && !isOverdue;
                    } else if (_selectedFilter == 'submitted') {
                      return isSubmitted;
                    } else if (_selectedFilter == 'overdue') {
                      return isOverdue;
                    }
                    return true;
                  }).toList();

                  final pendingCount = assignments.where((a) {
                    final sub = submissions[a.id];
                    final isSubmitted = sub?.isSubmitted ?? false;
                    return !isSubmitted && !a.isOverdue;
                  }).length;

                  return Column(
                    children: [
                      // Filter bar + Notification prefs button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2l,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _filterChip('all', 'All (${assignments.length})', colorScheme, sem),
                                    const SizedBox(width: AppSpacing.xs),
                                    _filterChip('pending', 'Pending ($pendingCount)', colorScheme, sem),
                                    const SizedBox(width: AppSpacing.xs),
                                    _filterChip('submitted', 'Submitted', colorScheme, sem),
                                    const SizedBox(width: AppSpacing.xs),
                                    _filterChip('overdue', 'Overdue', colorScheme, sem),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            // Notification bell button
                            IconButton(
                              icon: const Icon(Icons.notifications_active_outlined, size: 20),
                              tooltip: 'Reminder settings',
                              onPressed: () =>
                                  AssignmentReminderSettingsSheet.show(context),
                            ),
                          ],
                        ),
                      ),

                      // Assignment cards list
                      Expanded(
                        child: filtered.isEmpty
                            ? FloatingEmptyState(
                                icon: Icons.assignment_turned_in_outlined,
                                title: _selectedFilter == 'all'
                                    ? 'No assignments'
                                    : 'No $_selectedFilter assignments',
                                subtitle: _isCRorSR
                                    ? 'Tap the + button to create an assignment'
                                    : 'Your CR will post upcoming deadlines here',
                              )
                            : Builder(
                                builder: (context) {
                                  final shouldShowAd =
                                      AdService.shouldShowAdsForRole(
                                        AppSettings.currentRole,
                                      );
                                  final itemCount =
                                      filtered.length + (shouldShowAd ? 1 : 0);

                                  return ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      AppSpacing.x2l,
                                      AppSpacing.sm,
                                      AppSpacing.x2l,
                                      _isCRorSR
                                          ? AppSpacing.x6l + 32
                                          : AppSpacing.x4l,
                                    ),
                                    itemCount: itemCount,
                                    itemBuilder: (context, index) {
                                      if (index == filtered.length) {
                                        return const Padding(
                                          padding: EdgeInsets.only(
                                            top: AppSpacing.sm,
                                            bottom: AppSpacing.md,
                                          ),
                                          child: SchedlyBannerAd(
                                            key: ValueKey(
                                              'assignments_bottom_banner_ad',
                                            ),
                                            margin: EdgeInsets.zero,
                                          ),
                                        );
                                      }

                                      final item = filtered[index];
                                      final sub = submissions[item.id];

                                      return StaggeredListItem(
                                        index: index,
                                        child: AssignmentCard(
                                          assignment: item,
                                          submission: sub,
                                          canManage: _canManageAssignment(item),
                                          onEdit: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CreateAssignmentPage(
                                                  existingAssignment: item,
                                                ),
                                              ),
                                            );
                                          },
                                          onCancel: () async {
                                            final confirmed =
                                                await AppDialogs.showConfirm(
                                              context: context,
                                              title: 'Cancel Assignment?',
                                              message:
                                                  'This will mark "${item.title}" as cancelled and stop future reminders.',
                                              confirmText: 'Cancel Assignment',
                                              isDestructive: true,
                                            );
                                            if (confirmed) {
                                              await AssignmentService
                                                  .cancelAssignment(item);
                                            }
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'Assignments & Deadlines',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Reminder settings',
            onPressed: () => AssignmentReminderSettingsSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(child: content),
      floatingActionButton: _isCRorSR
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Material(
                  color: Colors.transparent,
                  elevation: 6,
                  shadowColor: colorScheme.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateAssignmentPage(
                            initialSectionId: _effectiveSectionId,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2l,
                          vertical: AppSpacing.md + 1,
                        ),
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: colorScheme.onPrimary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'New Assignment',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _filterChip(
    String key,
    String label,
    ColorScheme colorScheme,
    AppSemanticColors sem,
  ) {
    final isSelected = _selectedFilter == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedBg = colorScheme.primary;
    final unselectedBg = isDark
        ? sem.surfaceElevated2
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

    final selectedText = colorScheme.onPrimary;
    final unselectedText = isDark ? sem.onSurfaceMuted : colorScheme.onSurface.withValues(alpha: 0.75);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: AppSpacing.sm - 1,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : (isDark ? sem.borderSubtle : colorScheme.outlineVariant.withValues(alpha: 0.4)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? selectedText : unselectedText,
          ),
        ),
      ),
    );
  }
}
