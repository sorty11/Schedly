import 'package:flutter/material.dart';
export 'skeleton_shimmer.dart';
import 'skeleton_shimmer.dart';
import '../../theme/theme.dart';

class HeroCardSkeleton extends StatelessWidget {
  const HeroCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.lg),
        padding: EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(AppRadius.x2l),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SkeletonBlock(width: 120, height: 16, borderRadius: 4),
                  const SizedBox(height: AppSpacing.sm),
                  const SkeletonBlock(width: 200, height: 28, borderRadius: 6),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      const SkeletonBlock(width: 80, height: 32, borderRadius: AppRadius.full),
                      const SizedBox(width: AppSpacing.sm),
                      const SkeletonBlock(width: 80, height: 32, borderRadius: AppRadius.full),
                    ],
                  ),
                ],
              ),
            ),
            const SkeletonBlock(width: 72, height: 72, borderRadius: 36),
          ],
        ),
      ),
    );
  }
}

class StatsRowSkeleton extends StatelessWidget {
  const StatsRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
        child: Row(
          children: [
            Expanded(child: _buildStatBlock(context)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _buildStatBlock(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBlock(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.02)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock(width: 32, height: 32, borderRadius: 8),
          SizedBox(height: AppSpacing.md),
          SkeletonBlock(width: 60, height: 24, borderRadius: 4),
          SizedBox(height: AppSpacing.xs),
          SkeletonBlock(width: 100, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

class LectureCardSkeleton extends StatelessWidget {
  final bool includeTime;
  
  const LectureCardSkeleton({super.key, this.includeTime = false});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBlock(width: 48, height: 48, borderRadius: AppRadius.md),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (includeTime) ...[
                      const SkeletonBlock(width: 60, height: 12, borderRadius: 4),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    const SkeletonBlock(width: double.infinity, height: 18, borderRadius: 4),
                    const SizedBox(height: AppSpacing.sm),
                    const Row(
                      children: [
                        SkeletonBlock(width: 80, height: 14, borderRadius: 4),
                        SizedBox(width: AppSpacing.md),
                        SkeletonBlock(width: 50, height: 14, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubjectCardSkeleton extends StatelessWidget {
  const SubjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonBlock(width: 120, height: 16, borderRadius: 4),
                  SkeletonBlock(width: 40, height: 16, borderRadius: 4),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              SkeletonBlock(width: double.infinity, height: 8, borderRadius: 4),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(width: 200, height: 12, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class AnnouncementCardSkeleton extends StatelessWidget {
  const AnnouncementCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonBlock(width: 80, height: 24, borderRadius: AppRadius.full),
                  SkeletonBlock(width: 24, height: 24, borderRadius: AppRadius.full),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              SkeletonBlock(width: 250, height: 20, borderRadius: 4),
              SizedBox(height: AppSpacing.sm),
              SkeletonBlock(width: double.infinity, height: 14, borderRadius: 4),
              SizedBox(height: 4),
              SkeletonBlock(width: 200, height: 14, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // Appbar area spacing
        const SizedBox(height: 72),
        const HeroCardSkeleton(),
        const StatsRowSkeleton(),
        const SizedBox(height: AppSpacing.x2l),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
          child: Text(
            'Today\'s Schedule',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
          child: LectureCardSkeleton(includeTime: true),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
          child: LectureCardSkeleton(includeTime: true),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
          child: LectureCardSkeleton(includeTime: true),
        ),
      ],
    );
  }
}

class TimetableSkeleton extends StatelessWidget {
  const TimetableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.lg, AppSpacing.x2l, AppSpacing.x6l),
      itemCount: 5,
      itemBuilder: (context, index) => const LectureCardSkeleton(includeTime: true),
    );
  }
}

class AnalyticsSkeleton extends StatelessWidget {
  const AnalyticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.sm),
      children: [
        Row(
          children: [
            Expanded(child: _buildChartSkeleton(context)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: _buildChartSkeleton(context)),
          ],
        ),
        const SizedBox(height: AppSpacing.x2l),
        Text(
          'Subject Breakdown',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SubjectCardSkeleton(),
        const SubjectCardSkeleton(),
        const SubjectCardSkeleton(),
        const SubjectCardSkeleton(),
      ],
    );
  }

  Widget _buildChartSkeleton(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        height: 160,
        padding: EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: const Center(
          child: SkeletonBlock(width: 100, height: 100, borderRadius: 50),
        ),
      ),
    );
  }
}

class UpdatesSkeleton extends StatelessWidget {
  const UpdatesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.sm),
      itemCount: 4,
      itemBuilder: (context, index) => const AnnouncementCardSkeleton(),
    );
  }
}

