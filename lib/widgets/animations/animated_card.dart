import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double borderRadius;
  final bool disableTilt;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.margin,
    this.backgroundColor,
    this.borderRadius = 20,
    this.disableTilt =
        true, // Default to true now to prevent unnecessary movement
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Strict Premium Timing (Cards): 160ms (between 140-180ms constraint)
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 160),
    );

    // Exact scale requirement: 0.97 without elastic overshoot
    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive =
        widget.onTap != null || widget.onLongPress != null;

    return Semantics(
      button: isInteractive,
      enabled: isInteractive,
      child: Container(
        margin: widget.margin,
        child: GestureDetector(
          behavior: isInteractive
              ? HitTestBehavior.opaque
              : HitTestBehavior.deferToChild,
          onTapDown: isInteractive ? _onTapDown : null,
          onTapUp: isInteractive ? _onTapUp : null,
          onTapCancel: isInteractive ? _onTapCancel : null,
          onTap: widget.onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onTap!();
                }
              : null,
          onLongPress: widget.onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  widget.onLongPress!();
                }
              : null,
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
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    color: widget.backgroundColor ?? Colors.transparent,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
