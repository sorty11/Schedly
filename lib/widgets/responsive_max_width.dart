import 'package:flutter/material.dart';

class ResponsiveMaxWidth extends StatelessWidget {
  final Widget child;

  const ResponsiveMaxWidth({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // No width constraint: the app occupies the full viewport at all sizes.
    return child;
  }
}
