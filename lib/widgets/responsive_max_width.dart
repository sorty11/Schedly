import 'package:flutter/material.dart';

class ResponsiveMaxWidth extends StatelessWidget {
  final Widget child;

  const ResponsiveMaxWidth({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double maxWidth;

        if (width < 700) {
          maxWidth = double.infinity; // Mobile
        } else if (width < 1100) {
          maxWidth = 900; // Tablet
        } else if (width < 1600) {
          maxWidth = 1200; // Desktop
        } else {
          maxWidth = 1400; // Ultra-wide
        }

        if (maxWidth == double.infinity) {
          return child;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
