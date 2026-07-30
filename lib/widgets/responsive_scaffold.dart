import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_colors.dart';

/// The root layout scaffold for Schedly.
///
/// Desktop (≥1100px): Sidebar + Main Content + optional Context Panel
/// Tablet (700–1099px): Main Content with bottom nav
/// Mobile (<700px): Full-screen with floating bottom dock
class ResponsiveScaffold extends StatelessWidget {
  final Widget mobileBody;
  final Widget? tabletBody;
  final Widget? desktopBody;
  final Widget? bottomNavigationBar;
  final Widget? navigationRail;
  final Widget? contextPanel;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const ResponsiveScaffold({
    super.key,
    required this.mobileBody,
    this.tabletBody,
    this.desktopBody,
    this.bottomNavigationBar,
    this.navigationRail,
    this.contextPanel,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tier = LayoutTier.fromWidth(width);

        final Widget body;
        if (tier == LayoutTier.desktop) {
          body = desktopBody ?? tabletBody ?? mobileBody;
        } else if (tier == LayoutTier.tablet) {
          body = tabletBody ?? mobileBody;
        } else {
          body = mobileBody;
        }

        final scaffoldBg = backgroundColor ??
            (isDark ? AppColors.backgroundDark : AppColors.background);

        // ── Desktop: 3-zone layout ──
        if (tier == LayoutTier.desktop && navigationRail != null) {
          final bool showContextPanel =
              contextPanel != null && width >= AppBreakpoints.desktop;
          final bool showCollapsibleContext =
              contextPanel != null && !showContextPanel;

          return Scaffold(
            appBar: appBar,
            backgroundColor: scaffoldBg,
            floatingActionButton: floatingActionButton,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Zone 1: Navigation sidebar
                navigationRail!,

                // Zone 2: Main content
                Expanded(
                  child: body,
                ),

                // Zone 3: Context panel (persistent on large desktop)
                if (showContextPanel)
                  _ContextPanelContainer(child: contextPanel!),
              ],
            ),
          );
        }

        // ── Mobile / Tablet ──
        return Scaffold(
          extendBody: true,
          appBar: appBar,
          backgroundColor: scaffoldBg,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
          body: body,
        );
      },
    );
  }
}

/// Persistent context panel for large desktops.
class _ContextPanelContainer extends StatelessWidget {
  final Widget child;

  const _ContextPanelContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: sem.borderSubtle, width: 1),
        ),
      ),
      child: child,
    );
  }
}

// ── Layout Tier ──

enum LayoutTier {
  mobile,
  tablet,
  desktop;

  static LayoutTier fromWidth(double width) {
    if (width >= AppBreakpoints.tablet) return LayoutTier.desktop;
    if (width >= AppBreakpoints.mobile) return LayoutTier.tablet;
    return LayoutTier.mobile;
  }
}

LayoutTier getLayoutTier(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return LayoutTier.fromWidth(width);
}
