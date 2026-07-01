import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme.dart';

class AppDialogs {
  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
    String? resolution,
  }) {
    return _showBaseDialog(
      context: context,
      icon: Icons.error_outline_rounded,
      iconColor: Theme.of(context).extension<AppSemanticColors>()!.error,
      title: title,
      message: message,
      resolution: resolution,
    );
  }

  static Future<void> showWarning({
    required BuildContext context,
    required String title,
    required String message,
    String? resolution,
  }) {
    return _showBaseDialog(
      context: context,
      icon: Icons.warning_amber_rounded,
      iconColor: Theme.of(context).extension<AppSemanticColors>()!.warning,
      title: title,
      message: message,
      resolution: resolution,
    );
  }

  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _showBaseDialog(
      context: context,
      icon: Icons.check_circle_outline_rounded,
      iconColor: Theme.of(context).extension<AppSemanticColors>()!.success,
      title: title,
      message: message,
    );
  }

  static Future<bool> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: sem.onSurfaceMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? sem.error : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> _showBaseDialog({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String? resolution,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        icon: Icon(icon, color: iconColor, size: 48),
        title: Text(title, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14)),
            if (resolution != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: iconColor, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        resolution,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: iconColor),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static void showSnackBar({
    required BuildContext context,
    required String message,
    bool isError = false,
  }) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final bgColor = isError ? sem.error : sem.success;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_rounded;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        margin: EdgeInsets.all(AppSpacing.md),
        elevation: 8,
      ),
    );
  }
}
