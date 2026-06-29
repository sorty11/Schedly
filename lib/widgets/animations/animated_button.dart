import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double? width;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const AnimatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56,
    this.width,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.padding,
    this.borderRadius = 16,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> with TickerProviderStateMixin {
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

    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );

    // Hover Physics
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _hoverTranslationY = Tween<double>(begin: 0.0, end: -2.0).animate(
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
    if (widget.onPressed == null || widget.isLoading) return;
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(_) {
    if (widget.onPressed == null || widget.isLoading) return;
    _pressController.reverse();
  }
  
  void _handleTapCancel() {
    if (widget.onPressed == null || widget.isLoading) return;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final fgColor = widget.foregroundColor ?? theme.colorScheme.onPrimary;
    final disabled = widget.onPressed == null || widget.isLoading;

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
            widget.onPressed!();
          }
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressController, _hoverController]),
          builder: (context, child) {
            final currentScale = _pressScaleAnimation.value * _hoverScaleAnimation.value;
            
            final matrix = Matrix4.translationValues(0.0, _hoverTranslationY.value, 0.0)
              ..multiply(Matrix4.diagonal3Values(currentScale, currentScale, 1.0));

            // Interpolate color for hover
            final currentColor = disabled 
                ? theme.colorScheme.surfaceContainerHighest 
                : Color.lerp(bgColor, Colors.white.withValues(alpha: 0.1 * bgColor.a), _hoverController.value * 0.5) ?? bgColor;

            final blurRadius = 12.0 + (_hoverController.value * 8.0);
            final offsetY = 4.0 + (_hoverController.value * 4.0);

            return Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: Container(
                height: widget.height,
                width: widget.width,
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  color: currentColor,
                  boxShadow: [
                    if (!disabled)
                      BoxShadow(
                        color: bgColor.withValues(alpha: 0.25 + (_hoverController.value * 0.15)),
                        blurRadius: blurRadius,
                        offset: Offset(0, offsetY),
                        spreadRadius: _pressController.value * 2,
                      ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    onTap: widget.onPressed,
                    splashColor: fgColor.withValues(alpha: 0.2),
                    highlightColor: fgColor.withValues(alpha: 0.1),
                    child: Center(
                      child: widget.isLoading 
                        ? SizedBox(
                            width: 24, 
                            height: 24, 
                            child: CircularProgressIndicator(color: fgColor, strokeWidth: 2.5)
                          )
                        : DefaultTextStyle(
                            style: TextStyle(
                              color: disabled ? theme.colorScheme.onSurfaceVariant : fgColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            child: widget.child,
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
