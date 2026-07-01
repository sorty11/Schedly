import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme.dart';

/// A section header widget that renders a styled ALL-CAPS label
/// with consistent spacing and muted color.
class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.padding,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: padding ??
          EdgeInsets.only(
            bottom: AppSpacing.md,
            top: AppSpacing.x2l,
          ),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: sem.onSurfaceMuted,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}
