import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedListTile extends StatefulWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsetsGeometry contentPadding;

  const AnimatedListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  });

  @override
  State<AnimatedListTile> createState() => _AnimatedListTileState();
}

class _AnimatedListTileState extends State<AnimatedListTile> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScaleAnimation;
  
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    
    // Press Physics
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );

    // Hover Physics
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (widget.onTap == null) return;
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(_) {
    if (widget.onTap == null) return;
    _pressController.reverse();
  }
  
  void _handleTapCancel() {
    if (widget.onTap == null) return;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        if (!disabled) _hoverController.forward();
      },
      onExit: (_) {
        if (!disabled) _hoverController.reverse();
      },
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: () {
          if (!disabled) {
            HapticFeedback.mediumImpact();
            widget.onTap!();
          }
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressController, _hoverController]),
          builder: (context, child) {
            final currentColor = disabled 
                ? (widget.backgroundColor ?? Colors.transparent)
                : Color.lerp(
                    widget.backgroundColor ?? Colors.transparent, 
                    theme.colorScheme.primary.withValues(alpha: 0.05), 
                    _hoverController.value
                  );

            return Transform.scale(
              scale: _pressScaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onTap,
                    splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                    child: Padding(
                      padding: widget.contentPadding,
                      child: Row(
                        children: [
                          if (widget.leading != null) ...[
                            widget.leading!,
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DefaultTextStyle(
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    color: disabled ? theme.colorScheme.onSurface.withValues(alpha: 0.5) : theme.colorScheme.onSurface,
                                  ),
                                  child: widget.title,
                                ),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  DefaultTextStyle(
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    child: widget.subtitle!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.trailing != null) ...[
                            const SizedBox(width: 16),
                            widget.trailing!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
