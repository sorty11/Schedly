import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// A comprehensive utility layer for adaptive and responsive UI across Schedly.
class ResponsiveUtils {
  // Breakpoints based on standard Material Design guidelines
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Returns true if the current viewport is considered a mobile device (narrow width).
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Returns true if the current viewport is considered a tablet device.
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < desktopBreakpoint;

  /// Returns true if the current viewport is considered a desktop device.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  /// Dynamically computes the appropriate outer padding for standard pages.
  /// Uses larger padding on wide screens and tighter padding on small/mobile screens.
  static double getPagePadding(BuildContext context) {
    if (isMobile(context)) {
      return AppSpacing.lg; // 16px for mobile
    } else if (isTablet(context)) {
      return AppSpacing.xl; // 24px for tablet
    } else {
      return AppSpacing.x3l; // 48px for desktop
    }
  }

  /// Dynamically computes internal padding for cards and dialogs.
  static double getCardPadding(BuildContext context) {
    if (isMobile(context)) {
      return AppSpacing.lg; // 16px for compact environments
    } else {
      return AppSpacing.x2l; // 32px for spacious environments
    }
  }

  /// Determines if a layout should switch from horizontal to vertical.
  /// Useful for components like Role Cards that might get compressed by text scaling and narrow screens.
  /// [availableWidth] should be the width provided by a LayoutBuilder.
  /// [minRequiredWidth] is the threshold under which the layout switches to vertical.
  static bool shouldUseVerticalLayout(
    BuildContext context, {
    required double availableWidth,
    double minRequiredWidth = 250,
  }) {
    // If the physical available width is smaller than our threshold, go vertical.
    if (availableWidth < minRequiredWidth) return true;

    // If the user has extremely large font scaling, force vertical to prevent text truncation
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (textScale > 1.4 && availableWidth < (minRequiredWidth * 1.5))
      return true;

    return false;
  }

  /// Returns a standard ConstrainedBox with a maximum width, suitable for centering forms and content.
  static Widget constrainedFormBox(
    BuildContext context, {
    required Widget child,
    double maxWidth = 500,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
  }

  /// Bottom sheet margin for responsive bottom sheets (e.g. CR verification).
  static EdgeInsets getBottomSheetMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    }
    return const EdgeInsets.symmetric(horizontal: AppSpacing.x2l);
  }
}
