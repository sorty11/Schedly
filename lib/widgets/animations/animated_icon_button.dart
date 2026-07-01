import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double padding;

  const AnimatedIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.padding = 8.0,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScaleAnimation;
  
  late AnimationController _hoverController;
  late Animation<double> _hoverScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Press Physics
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );

    // Hover Physics
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(_) {
    if (widget.onPressed == null) return;
    _pressController.reverse();
  }
  
  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = widget.onPressed == null;
    final iconColor = widget.color ?? theme.colorScheme.onSurface;

    Widget button = MouseRegion(
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
            widget.onPressed!();
          }
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressController, _hoverController]),
          builder: (context, child) {
            final currentScale = _pressScaleAnimation.value * _hoverScaleAnimation.value;
            
            final hoverColor = widget.backgroundColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.1);
            final currentColor = disabled 
                ? Colors.transparent 
                : Color.lerp(widget.backgroundColor ?? Colors.transparent, hoverColor, _hoverController.value);

            return Transform.scale(
              scale: currentScale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentColor,
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onPressed,
                    customBorder: const CircleBorder(),
                    splashColor: iconColor.withValues(alpha: 0.2),
                    highlightColor: iconColor.withValues(alpha: 0.1),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: Padding(
                        padding: EdgeInsets.all(widget.padding),
                        child: IconTheme.merge(
                          data: IconThemeData(
                            color: disabled ? theme.colorScheme.onSurface.withValues(alpha: 0.38) : iconColor,
                          ),
                          child: widget.icon,
                        ),
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

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.tooltip,
      child: button,
    );
  }
}
