import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_colors.dart';

/// The root scrollable container for page content.
///
/// On desktop, content fills the available width (no artificial max-width cap).
/// On mobile, content uses full width with appropriate padding.
class Workspace extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? scrollController;
  final Widget? header;
  final EdgeInsetsGeometry? padding;

  const Workspace({
    super.key,
    required this.children,
    this.scrollController,
    this.header,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: padding ?? const EdgeInsets.all(AppSpacing.x2l),
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: AppSpacing.xl),
        ],
        ...children,
      ],
    );
  }
}

/// A two-column layout section for desktop.
///
/// On mobile (<700px): stacks children vertically.
/// On desktop (≥700px): places children side-by-side in a flexible row.
class WorkspaceSection extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final List<int>? flexValues;

  const WorkspaceSection({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.flexValues,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.mobile;

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children
                  .map((child) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: child,
                      ))
                  .toList(),
            );
          }

          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: List.generate(children.length, (i) {
              final flex = (flexValues != null && i < flexValues!.length)
                  ? flexValues![i]
                  : 1;
              return Expanded(
                flex: flex,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == children.length - 1 ? 0 : AppSpacing.lg,
                  ),
                  child: children[i],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// A compact inline metric row (replaces giant stat cards on dashboards).
///
/// Displays 3-5 key metrics in a single horizontal strip.
class MetricStrip extends StatelessWidget {
  final List<MetricItem> items;

  const MetricStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: sem.borderSubtle, width: 1),
      ),
      child: Row(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(
              width: 1,
              height: 32,
              margin:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              color: sem.borderSubtle,
            );
          }
          final item = items[i ~/ 2];
          return Expanded(child: _MetricCell(item: item));
        }),
      ),
    );
  }
}

class MetricItem {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const MetricItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });
}

class _MetricCell extends StatelessWidget {
  final MetricItem item;

  const _MetricCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.onSurfaceDark : AppColors.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: sem.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 14, color: item.valueColor ?? textColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              item.value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: item.valueColor ?? textColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Apple Settings-style grouped list container.
///
/// Renders children as rows inside a bordered surface with dividers between them.
class GroupedList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const GroupedList({
    super.key,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: sem.borderSubtle, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          children.length * 2 - 1,
          (i) {
            if (i.isOdd) {
              return Divider(
                height: 1,
                thickness: 1,
                color: sem.borderSubtle,
                indent: AppSpacing.lg,
              );
            }
            return children[i ~/ 2];
          },
        ),
      ),
    );
  }
}

/// A single row inside a GroupedList.
class GroupedListTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? leading;
  final Color? leadingColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const GroupedListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingColor,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  State<GroupedListTile> createState() => _GroupedListTileState();
}

class _GroupedListTileState extends State<GroupedListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.isDestructive
        ? sem.error
        : (isDark ? AppColors.onSurfaceDark : AppColors.onSurface);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          color: _isHovered
              ? sem.onSurfaceMuted.withValues(alpha: 0.04)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (widget.leadingColor ?? sem.accent)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.leading,
                    size: 16,
                    color: widget.leadingColor ?? sem.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: sem.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              widget.trailing ??
                  (widget.onTap != null
                      ? Icon(Icons.chevron_right_rounded,
                          size: 18, color: sem.onSurfaceFaint)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small uppercase section label (used above GroupedList or content sections).
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? padding;

  const SectionLabel({
    super.key,
    required this.text,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: padding ??
          const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
            top: AppSpacing.xl,
          ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: sem.onSurfaceMuted,
        ),
      ),
    );
  }
}

/// A page-level title header with optional subtitle and trailing actions.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.onSurfaceDark
                        : AppColors.onSurface,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: sem.onSurfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
