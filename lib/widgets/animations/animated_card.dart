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
    this.disableTilt = false,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _hoverController;
  
  late Animation<double> _pressScaleAnimation;
  late Animation<double> _pressElevationAnimation;
  late Animation<double> _tiltAnimation;
  
  late Animation<double> _hoverScaleAnimation;
  late Animation<double> _hoverElevationAnimation;
  late Animation<double> _hoverTranslationY;

  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    
    // Press Physics (Spring)
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );

    _pressElevationAnimation = Tween<double>(begin: 0.0, end: -4.0).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
    
    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );

    // Hover Physics (Smooth easeOutCubic)
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _hoverElevationAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _hoverTranslationY = Tween<double>(begin: 0.0, end: -3.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _onPanDown(DragDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final localPos = renderBox.globalToLocal(details.globalPosition);
      final dx = (localPos.dx - size.width / 2) / (size.width / 2);
      final dy = (localPos.dy - size.height / 2) / (size.height / 2);
      _tapPosition = Offset(dx, dy);
    }
    
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _onPanCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = widget.onTap != null || widget.onLongPress != null;

    return Container(
      margin: widget.margin,
      child: MouseRegion(
        cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) {
          if (!isInteractive) return;
          _hoverController.forward();
        },
        onExit: (_) {
          if (!isInteractive) return;
          _hoverController.reverse();
        },
        child: GestureDetector(
          onPanDown: isInteractive ? _onPanDown : null,
          onPanCancel: isInteractive ? _onPanCancel : null,
          onPanEnd: (_) => isInteractive ? _onPanCancel() : null,
          onTap: () {
            if (widget.onTap != null) {
              _pressController.forward().then((_) {
                _pressController.reverse();
                widget.onTap!();
              });
            }
          },
          onLongPress: widget.onLongPress != null ? () {
            HapticFeedback.mediumImpact();
            widget.onLongPress!();
          } : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pressController, _hoverController]),
            builder: (context, child) {
              final currentScale = _hoverScaleAnimation.value * _pressScaleAnimation.value;
              
              final matrix = Matrix4.translationValues(0.0, _hoverTranslationY.value, 0.0)
                ..multiply(Matrix4.diagonal3Values(currentScale, currentScale, 1.0))
                ..setEntry(3, 2, 0.001);

              if (!widget.disableTilt && isInteractive) {
                matrix.rotateX(-_tapPosition.dy * _tiltAnimation.value);
                matrix.rotateY(_tapPosition.dx * _tiltAnimation.value);
              }

              final baseColor = widget.backgroundColor ?? Theme.of(context).colorScheme.surface;
              final hoverColor = Color.lerp(
                baseColor, 
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.05), 
                _hoverController.value
              )!;

              final currentElevation = _hoverElevationAnimation.value + _pressElevationAnimation.value;

              return Transform(
                transform: matrix,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05 + (_hoverController.value * 0.05)),
                        blurRadius: currentElevation * 2,
                        offset: Offset(0, currentElevation),
                        spreadRadius: _hoverController.value * 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: hoverColor,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    clipBehavior: Clip.antiAlias,
                    elevation: 0, 
                    child: InkWell(
                      onTap: widget.onTap,
                      onLongPress: widget.onLongPress,
                      splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      child: widget.child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
