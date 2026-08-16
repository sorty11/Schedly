import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
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
    final result = await showModal<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.x2l,
            AppSpacing.lg,
            AppSpacing.x2l,
            AppSpacing.x2l,
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            AppSpacing.x2l,
            AppSpacing.x2l,
            AppSpacing.x2l,
            AppSpacing.sm,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDestructive ? sem.error : null,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(80, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                cancelText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDestructive
                    ? sem.error
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                confirmText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
    return showModal(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.x2l,
            AppSpacing.sm,
            AppSpacing.x2l,
            AppSpacing.x2l,
          ),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          iconPadding: const EdgeInsets.fromLTRB(
            AppSpacing.x2l,
            AppSpacing.x2l,
            AppSpacing.x2l,
            AppSpacing.sm,
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            AppSpacing.x2l,
            AppSpacing.sm,
            AppSpacing.x2l,
            AppSpacing.xs,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (resolution != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: iconColor,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          resolution,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: iconColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.x2l,
            AppSpacing.sm,
            AppSpacing.x2l,
            AppSpacing.x2l,
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Got it',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Professional snackbar — floating, blurred, rounded pill.
  static void showSnackBar({
    required BuildContext context,
    required String message,
    bool isError = false,
  }) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconColor = isError ? sem.error : sem.success;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    final bgColor = isDark
        ? const Color(0xFF1C1C2A).withValues(alpha: 0.75)
        : const Color(0xFF1A1A28).withValues(alpha: 0.75);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: bgColor,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        padding: EdgeInsets
            .zero, // Remove default padding to allow ClipRRect to cover fully
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(AppSpacing.lg),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
