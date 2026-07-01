import re

file_path = r'c:\Users\ACER\Desktop\schedly\lib\dashboard_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
content = content.replace(
    "import 'widgets/animations/floating_empty_state.dart';",
    "import 'widgets/animations/floating_empty_state.dart';\nimport 'widgets/animations/skeleton_components.dart';"
)

# Remove the early return for CircularProgressIndicator and add isLoading
content = re.sub(
    r'if \(snapshot\.connectionState == ConnectionState\.waiting &&\s+!snapshot\.hasData\) \{\s+return const Center\(child: CircularProgressIndicator\(\)\);\s+\}',
    r'final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;',
    content
)

# Inject skeleton for HeroCard
content = content.replace(
    'if (!_hasTimetable && !_hasDraft && AppSettings.currentRole == UserRole.cr && !_isLoadingTimetableCheck)',
    'if (isLoading)\n                  const SliverToBoxAdapter(child: HeroCardSkeleton()),\n\n                if (!isLoading && !_hasTimetable && !_hasDraft && AppSettings.currentRole == UserRole.cr && !_isLoadingTimetableCheck)'
)

# Fix other conditions to check for !isLoading so they don't break
content = content.replace(
    'if (_hasDraft)',
    'if (!isLoading && _hasDraft)'
)

# LiveLectureCard (Hero)
content = content.replace(
    'if (currentGroup != null)',
    'if (!isLoading && currentGroup != null)'
)

# QuickStatsRow
content = content.replace(
    'if (groupedLectures.isNotEmpty)',
    'if (!isLoading && groupedLectures.isNotEmpty)'
)

# FloatingEmptyState
content = content.replace(
    'if (groupedLectures.isEmpty)',
    'if (!isLoading && groupedLectures.isEmpty)'
)

# Today's Schedule Text replacement
old_text_block = '''SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.x2l,
                      right: AppSpacing.x2l,
                      bottom: AppSpacing.md,
                    ),
                    child: StaggeredListItem(
                      index: 4,
                      child: Row(
                        children: [
                          Text(
                            "Today's Schedule",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          if (groupedLectures.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                '${groupedLectures.length} block${groupedLectures.length == 1 ? '' : 's'}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),'''

new_text_block = '''SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.x2l,
                      right: AppSpacing.x2l,
                      bottom: AppSpacing.md,
                    ),
                    child: StaggeredListItem(
                      index: 4,
                      child: Row(
                        children: [
                          Text(
                            "Today's Schedule",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          if (!isLoading && groupedLectures.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                '${groupedLectures.length} block${groupedLectures.length == 1 ? '' : 's'}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                if (isLoading) ...[
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l), child: LectureCardSkeleton(includeTime: true))),
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l), child: LectureCardSkeleton(includeTime: true))),
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l), child: LectureCardSkeleton(includeTime: true))),
                ],'''

content = content.replace(old_text_block, new_text_block)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated dashboard_page.dart")
