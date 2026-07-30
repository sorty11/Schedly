import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// The absolute lowest-level primitive for any elevated or bounded content in Project Phoenix.
/// It strictly enforces flat surfaces, 1px borders, and pure geometry.
class WorkspaceSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool isInteractive;
  final VoidCallback? onTap;

  const WorkspaceSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.backgroundColor,
    this.borderColor,
    this.isInteractive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBg = isDark ? AppColors.surfaceDark : Colors.white;
    final defaultBorder = sem.borderSubtle;

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? defaultBorder, width: 1),
      ),
      child: child,
    );

    if (isInteractive || onTap != null) {
      return _InteractiveSurface(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      );
    }

    return content;
  }
}

class _InteractiveSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  const _InteractiveSurface({
    required this.child,
    this.onTap,
    required this.borderRadius,
  });

  @override
  State<_InteractiveSurface> createState() => _InteractiveSurfaceState();
}

class _InteractiveSurfaceState extends State<_InteractiveSurface> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDuration.fast);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.standard),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Semantics(
        button: widget.onTap != null,
        enabled: widget.onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedOpacity(
            opacity: _isHovered ? 0.95 : 1.0,
            duration: AppDuration.fast,
            child: widget.child,
          ),
          ),
        ),
      ),
    );
  }
}

/// A specialized WorkspaceSurface for grouping related metrics or controls.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurface(
      padding: padding,
      child: child,
    );
  }
}

/// A specialized Panel for displaying a key metric.
class MetricPanel extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final Color? valueColor;

  const MetricPanel({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    
    return WorkspaceSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: sem.onSurfaceMuted,
                ),
              ),
              if (trailing != null) SizedBox(child: trailing),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: valueColor ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.onSurfaceDark : AppColors.onSurface),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A structural header for sections within a Workspace.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.onSurfaceDark : AppColors.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: sem.onSurfaceMuted,
                  ),
                ),
              ]
            ],
          ),
          if (trailing != null) SizedBox(child: trailing),
        ],
      ),
    );
  }
}
