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

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScaleAnimation;

  @override
  void initState() {
    super.initState();
    // Strict premium timing: 120ms (between 100-140ms)
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
    );

    // Exact scale rule: 0.97
    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
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

    return Semantics(
      button: true,
      enabled: !disabled,
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
          animation: _pressController,
          builder: (context, child) {
            final matrix = Matrix4.diagonal3Values(
              _pressScaleAnimation.value,
              _pressScaleAnimation.value,
              1.0,
            );

            return Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: Container(
                height: widget.height,
                width: widget.width,
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  color: disabled
                      ? theme.colorScheme.surfaceContainerHighest
                      : bgColor,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: widget.isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: fgColor,
                                strokeWidth: 2,
                              ), // Keep minimal spinner but styled thin
                            )
                          : DefaultTextStyle(
                              key: const ValueKey('text'),
                              style: TextStyle(
                                color: disabled
                                    ? theme.colorScheme.onSurfaceVariant
                                    : fgColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
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
