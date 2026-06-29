import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_settings.dart';
import 'user_roles.dart';
import 'timetable_manager.dart';
import 'models/batch_analytics.dart';
import 'services/analytics_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/counting_text.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'onboarding/services/onboarding_service.dart';
import 'onboarding/widgets/tutorial_target.dart';

class AnalyticsPage extends StatefulWidget {
  final String division;

  const AnalyticsPage({super.key, required this.division});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Future<List<String>> _uniqueSubjectsFuture;

  @override
  void initState() {
    super.initState();
    _uniqueSubjectsFuture = _initAndLoadSubjects();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OnboardingService.instance.checkAnalyticsContext(context);
    });
  }

  Future<List<String>> _initAndLoadSubjects() async {
    await AnalyticsService.initializeSubjectAnalytics(widget.division);
    return TimetableManager.getUniqueSubjects(division: widget.division);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<String>>(
          future: _uniqueSubjectsFuture,
          builder: (context, subjectSnapshot) {
            if (subjectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final uniqueSubjects = subjectSnapshot.data ?? [];

            return StreamBuilder<List<BatchAnalytics>>(
              stream: AnalyticsService.streamAnalytics(widget.division),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var batchAnalytics = snapshot.data ?? [];

                // Aggregate BatchAnalytics into SubjectAnalytics
                final aggregatedMap = <String, List<BatchAnalytics>>{};

                for (final batch in batchAnalytics) {
                  aggregatedMap.putIfAbsent(batch.displaySubject, () => []).add(batch);
                }

                // Apply unique subjects rule to ensure zeroed subjects appear
                var analytics = <SubjectAnalytics>[];
                for (final sub in uniqueSubjects) {
                  analytics.add(SubjectAnalytics(
                    subject: sub,
                    batches: aggregatedMap[sub] ?? [],
                  ));
                }

                // If no unique subjects found from timetable, fallback to the existing ones
                if (uniqueSubjects.isEmpty) {
                  analytics = aggregatedMap.entries
                      .map((e) => SubjectAnalytics(subject: e.key, batches: e.value))
                      .toList();
                }

                if (AppSettings.currentRole == UserRole.sr &&
                    AppSettings.srSubject != null) {
                  analytics = analytics
                      .where((a) => a.subject.startsWith(AppSettings.srSubject!))
                      .toList();
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      title: Text(
                        'Semester Progress',
                        style: Theme.of(context).appBarTheme.titleTextStyle,
                      ),
                    ),

                    if (analytics.isEmpty)
                      SliverFillRemaining(
                        child: FloatingEmptyState(
                          icon: Icons.insights_rounded,
                          title: 'No analytics yet',
                          subtitle: 'Lectures will appear here once verified',
                        ),
                      ),

                    if (analytics.isNotEmpty &&
                        AppSettings.currentRole != UserRole.sr) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.x2l,
                          AppSpacing.sm,
                          AppSpacing.x2l,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: StaggeredListItem(
                            index: 0,
                            child: TutorialTarget(
                              id: 'health_card',
                              child: _SemesterHealthCard(analytics: analytics),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.x2l),
                      ),
                    ],

                    if (analytics.isNotEmpty &&
                        AppSettings.currentRole != UserRole.sr) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2l,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _AtRiskSection(analytics: analytics),
                        ),
                      ),
                    ],

                    if (analytics.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.x2l,
                          AppSpacing.x2l,
                          AppSpacing.x2l,
                          AppSpacing.md,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: StaggeredListItem(
                            index: 1,
                            child: TutorialTarget(
                              id: 'subject_breakdown',
                              child: Text(
                                'Subject Breakdown',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (analytics.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2l,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return StaggeredListItem(
                                index: 2 + index,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: _SubjectProgressCard(
                                    subject: analytics[index],
                                  ),
                                ),
                              );
                            },
                            childCount: analytics.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.x6l),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SemesterHealthCard extends StatelessWidget {
  final List<SubjectAnalytics> analytics;

  const _SemesterHealthCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int totalTarget = 0, totalCompleted = 0, totalPending = 0, totalCancelled = 0;
    for (var a in analytics) {
      totalTarget += a.totalTarget;
      totalCompleted += a.totalCompleted;
      totalPending += a.totalPending;
      totalCancelled += a.totalCancelled;
    }

    final percentage =
        totalTarget == 0 ? 0.0 : totalCompleted / totalTarget;
    final remaining = totalTarget - totalCompleted - totalCancelled;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF2D2B6B)]
              : [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.level4(colorScheme.primary, isDark: isDark),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x2l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Semester Progress',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CountingText(
                                value: percentage * 100,
                                suffix: '%',
                                isPercentage: true,
                                style: GoogleFonts.outfit(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                  letterSpacing: -2,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: Text(
                                  'complete',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (AppSettings.currentRole == UserRole.cr &&
                        totalPending > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm - 2,
                        ),
                        decoration: BoxDecoration(
                          color: sem.warning.withValues(alpha: 0.25),
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: sem.warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalPending Pending',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percentage),
                    duration: const Duration(milliseconds: 1200),
                    curve: AppCurves.standard,
                    builder: (_, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    _StatPill(
                      value: '$totalCompleted',
                      label: 'Done',
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatPill(
                      value: '${remaining < 0 ? 0 : remaining}',
                      label: 'Left',
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatPill(
                      value: '$totalCancelled',
                      label: 'Cancelled',
                      icon: Icons.cancel_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatPill({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm - 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          Text(
            '$value $label',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AtRiskSection extends StatelessWidget {
  final List<SubjectAnalytics> analytics;

  const _AtRiskSection({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final atRisk = analytics
        .where((a) => a.completionPercentage < 0.6 && a.totalTarget > 0)
        .toList();

    if (atRisk.isEmpty) return const SizedBox.shrink();

    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 16, color: sem.warning),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Subjects At Risk',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: sem.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...atRisk.map(
          (a) => Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: sem.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: sem.warning.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    a.subject,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${(a.completionPercentage * 100).round()}%',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: sem.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectProgressCard extends StatelessWidget {
  final SubjectAnalytics subject;

  const _SubjectProgressCard({required this.subject});

  Color _healthColor(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    if (subject.completionPercentage >= 0.75) return sem.conducted;
    if (subject.completionPercentage >= 0.5) return sem.warning;
    return sem.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final healthColor = _healthColor(context);
    final isVerified = subject.totalPending == 0;

    return AnimatedCard(
      backgroundColor:
          isDark ? sem.surfaceElevated : colorScheme.surface,
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
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.subject,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${subject.totalCompleted} of ${subject.totalTarget} lectures',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: subject.completionPercentage,
                          ),
                          duration: const Duration(milliseconds: 1200),
                          curve: AppCurves.standard,
                          builder: (_, value, _) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 5,
                              backgroundColor: isDark
                                  ? sem.borderSubtle
                                  : const Color(0xFFEEEEF8),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                healthColor,
                              ),
                              strokeCap: StrokeCap.round,
                            );
                          },
                        ),
                      ),
                      CountingText(
                        value: subject.completionPercentage * 100,
                        suffix: '%',
                        isPercentage: true,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: healthColor,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: SizedBox(
                  height: 8,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1200),
                    curve: AppCurves.standard,
                    builder: (_, t, _) {
                      final total = subject.totalTarget == 0
                          ? 1
                          : subject.totalTarget;
                      final completedFraction =
                          (subject.totalCompleted / total * t).clamp(0.0, 1.0);
                      final cancelledFraction =
                          (subject.totalCancelled / total * t)
                              .clamp(0.0, 1.0 - completedFraction);
                      final pendingFraction =
                          (subject.totalPending / total * t).clamp(
                              0.0,
                              1.0 -
                                  completedFraction -
                                  cancelledFraction);
                      return CustomPaint(
                        painter: _StackedBarPainter(
                          completed: completedFraction,
                          cancelled: cancelledFraction,
                          pending: pendingFraction,
                          completedColor: sem.conducted,
                          cancelledColor: sem.cancelled,
                          pendingColor: sem.warning,
                          trackColor: isDark
                              ? sem.borderSubtle
                              : const Color(0xFFEEEEF8),
                        ),
                        size: const Size(double.infinity, 8),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _MiniStat(
                        count: subject.remaining < 0 ? 0 : subject.remaining,
                        label: 'Left',
                        color: sem.onSurfaceMuted,
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      _MiniStat(
                        count: subject.totalCancelled,
                        label: 'Cancelled',
                        color: sem.cancelled,
                      ),
                      if (AppSettings.currentRole == UserRole.cr ||
                          AppSettings.currentRole == UserRole.sr) ...[
                        const SizedBox(width: AppSpacing.xl),
                        _MiniStat(
                          count: subject.totalPending,
                          label: 'Pending',
                          color: sem.warning,
                        ),
                      ],
                    ],
                  ),
                  if (AppSettings.currentRole == UserRole.cr)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? sem.conducted.withValues(alpha: 0.1)
                            : sem.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified
                                ? Icons.verified_rounded
                                : Icons.pending_rounded,
                            size: 13,
                            color: isVerified ? sem.conducted : sem.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? 'Verified' : '${subject.totalPending} pending',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isVerified ? sem.conducted : sem.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _MiniStat({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CountingText(
          value: count.toDouble(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context)
                .extension<AppSemanticColors>()!
                .onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  final double completed;
  final double cancelled;
  final double pending;
  final Color completedColor;
  final Color cancelledColor;
  final Color pendingColor;
  final Color trackColor;

  const _StackedBarPainter({
    required this.completed,
    required this.cancelled,
    required this.pending,
    required this.completedColor,
    required this.cancelledColor,
    required this.pendingColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));
    
    paint.color = trackColor;
    canvas.drawRRect(rRect, paint);

    double currentX = 0;

    void drawSegment(double fraction, Color color) {
      if (fraction <= 0) return;
      final w = size.width * fraction;
      paint.color = color;
      
      if (currentX == 0 && currentX + w >= size.width) {
        canvas.drawRRect(rRect, paint);
      } else if (currentX == 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(0, 0, w, size.height),
            topLeft: Radius.circular(size.height / 2),
            bottomLeft: Radius.circular(size.height / 2),
          ),
          paint,
        );
      } else if (currentX + w >= size.width * 0.99) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(currentX, 0, size.width - currentX, size.height),
            topRight: Radius.circular(size.height / 2),
            bottomRight: Radius.circular(size.height / 2),
          ),
          paint,
        );
      } else {
        canvas.drawRect(Rect.fromLTWH(currentX, 0, w, size.height), paint);
      }
      currentX += w;
    }

    drawSegment(completed, completedColor);
    drawSegment(cancelled, cancelledColor);
    drawSegment(pending, pendingColor);
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) {
    return oldDelegate.completed != completed ||
        oldDelegate.cancelled != cancelled ||
        oldDelegate.pending != pending;
  }
}
