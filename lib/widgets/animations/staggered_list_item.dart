import 'package:flutter/material.dart';

class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final int delayMs;
  final Offset slideOffset;
  final Axis axis;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.delayMs = 60,
    this.slideOffset = const Offset(0, 0.04),
    this.axis = Axis.vertical,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Derive the actual slide offset based on the axis parameter.
    // When axis is horizontal, the user's slideOffset x/y values are used but
    // we flip the axes: horizontal slides come from dx, vertical from dy.
    final Offset resolvedOffset = widget.axis == Axis.horizontal
        ? Offset(widget.slideOffset.dy == 0.0 ? widget.slideOffset.dx : widget.slideOffset.dy, 0)
        : Offset(0, widget.slideOffset.dy == 0.0 ? widget.slideOffset.dx : widget.slideOffset.dy);

    _slideAnimation =
        Tween<Offset>(begin: resolvedOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _playAnimation();
  }

  void _playAnimation() async {
    await Future.delayed(
        Duration(milliseconds: widget.index * widget.delayMs));
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
