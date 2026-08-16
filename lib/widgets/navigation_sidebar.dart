import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// A floating contextual sidebar for desktop layouts.
///
/// Designed with a premium Arc/Linear aesthetic. Sits inside a padded container,
/// defaults to a minimal icon-only width, and expands smoothly on hover.
class NavigationSidebar extends StatefulWidget {
  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  const NavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  State<NavigationSidebar> createState() => _NavigationSidebarState();
}

class _NavigationSidebarState extends State<NavigationSidebar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _SidebarItem(Icons.home_outlined, Icons.home_rounded, 'Workspace'),
      _SidebarItem(
        Icons.view_week_outlined,
        Icons.view_week_rounded,
        'Timetable',
      ),
      _SidebarItem(
        Icons.insights_outlined,
        Icons.insights_rounded,
        'Analytics',
      ),
      _SidebarItem(
        Icons.notifications_outlined,
        Icons.notifications_rounded,
        'Updates',
        badge: widget.unreadCount,
      ),
      _SidebarItem(
        Icons.account_circle_outlined,
        Icons.account_circle_rounded,
        'Profile',
      ),
    ];

    final double targetWidth = _isHovered ? 220.0 : 64.0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: AppDuration.spring,
          curve: AppCurves.spring,
          width: targetWidth,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF111111).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: sem.borderSubtle, width: 1),
            boxShadow: AppShadow.level2(colorScheme.primary, isDark: isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    // Brand Mark / Workspace Icon
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: sem.accent,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Center(
                              child: Text(
                                'S',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          if (_isHovered) ...[
                            const SizedBox(width: AppSpacing.md),
                            const Expanded(
                              child: Text(
                                'Schedly',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Nav Items
                    ...List.generate(items.length, (i) {
                      final item = items[i];
                      final isSelected = widget.selectedIndex == i;
                      return _SidebarNavItem(
                        item: item,
                        isSelected: isSelected,
                        isExpanded: _isHovered,
                        onTap: () => widget.onTap(i),
                      );
                    }),
                    const Spacer(),
                    // Quick Action or Help (Minimal)
                    if (_isHovered)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              size: 16,
                              color: sem.onSurfaceMuted,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Help & Feedback',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: sem.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;

  const _SidebarItem(
    this.icon,
    this.selectedIcon,
    this.label, {
    this.badge = 0,
  });
}

class _SidebarNavItem extends StatefulWidget {
  final _SidebarItem item;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            curve: AppCurves.standard,
            height: 44,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? sem.accent.withValues(alpha: 0.1)
                  : _isHovered
                  ? sem.onSurfaceMuted.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                // Active Indicator (3px accent line)
                AnimatedContainer(
                  duration: AppDuration.fast,
                  curve: AppCurves.standard,
                  width: 3,
                  height: widget.isSelected ? 24 : 0,
                  margin: const EdgeInsets.only(left: 2, right: 6),
                  decoration: BoxDecoration(
                    color: widget.isSelected ? sem.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),

                // Icon Container
                SizedBox(
                  width: 32,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          widget.isSelected
                              ? widget.item.selectedIcon
                              : widget.item.icon,
                          color: widget.isSelected
                              ? sem.accent
                              : sem.onSurfaceMuted,
                          size: AppIconSize.md,
                        ),
                        if (widget.item.badge > 0 && !widget.isExpanded)
                          Positioned(
                            top: -2,
                            right: -4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: sem.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Label and Badge (Expanded Mode)
                if (widget.isExpanded) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: widget.isSelected
                            ? sem.accent
                            : sem.onSurfaceMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  if (widget.item.badge > 0)
                    Container(
                      margin: const EdgeInsets.only(right: AppSpacing.md),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sem.error,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        widget.item.badge.toString(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
