import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String? label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AnimatedFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScaleAnimation;
  
  late AnimationController _hoverController;
  late Animation<double> _hoverScaleAnimation;
  late Animation<double> _hoverTranslationY;

  @override
  void initState() {
    super.initState();
    
    // Press Physics
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );

    // Hover Physics
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _hoverTranslationY = Tween<double>(begin: 0.0, end: -4.0).animate(
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
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(_) {
    _pressController.reverse();
  }
  
  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.primaryContainer;
    final fgColor = widget.foregroundColor ?? theme.colorScheme.onPrimaryContainer;

    Widget fab = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onPressed();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressController, _hoverController]),
          builder: (context, child) {
            final currentScale = _pressScaleAnimation.value * _hoverScaleAnimation.value;
            
            final matrix = Matrix4.translationValues(0.0, _hoverTranslationY.value, 0.0)
              ..multiply(Matrix4.diagonal3Values(currentScale, currentScale, 1.0));

            // Interpolate color for hover
            final currentColor = Color.lerp(
              bgColor, 
              Colors.white.withValues(alpha: 0.2 * bgColor.a), 
              _hoverController.value * 0.5
            ) ?? bgColor;

            final blurRadius = 12.0 + (_hoverController.value * 12.0);
            final offsetY = 6.0 + (_hoverController.value * 4.0);

            final innerChild = widget.label != null 
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTheme.merge(
                      data: IconThemeData(color: fgColor),
                      child: widget.icon,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.label!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : IconTheme.merge(
                  data: IconThemeData(color: fgColor),
                  child: widget.icon,
                );

            return Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: Container(
                padding: widget.label != null ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16) : const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: currentColor,
                  boxShadow: [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.3 + (_hoverController.value * 0.2)),
                      blurRadius: blurRadius,
                      offset: Offset(0, offsetY),
                      spreadRadius: _pressController.value * 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: widget.onPressed,
                    splashColor: fgColor.withValues(alpha: 0.2),
                    highlightColor: fgColor.withValues(alpha: 0.1),
                    child: innerChild,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (widget.tooltip != null) {
      fab = Tooltip(
        message: widget.tooltip!,
        child: fab,
      );
    }

    return fab;
  }
}
