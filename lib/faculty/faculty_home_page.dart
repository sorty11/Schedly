import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme.dart';
import 'faculty_dashboard_page.dart';
import 'faculty_timetable_page.dart';
import 'faculty_panel_page.dart';
import 'faculty_profile_page.dart';

class FacultyHomePage extends StatefulWidget {
  const FacultyHomePage({super.key});

  @override
  State<FacultyHomePage> createState() => _FacultyHomePageState();
}

class _FacultyHomePageState extends State<FacultyHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FacultyDashboardPage(),
      const FacultyTimetablePage(),
      const FacultyPanelPage(),
      const FacultyProfilePage(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppDuration.enter,
        switchInCurve: AppCurves.standard,
        switchOutCurve: AppCurves.exit,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.03),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: _FacultyNavBar(
        selectedIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _FacultyNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FacultyNavBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _NavItem(
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
        'Timetable',
      ),
      _NavItem(
        Icons.dashboard_customize_outlined,
        Icons.dashboard_customize_rounded,
        'Panel',
      ),
      _NavItem(
        Icons.account_circle_outlined,
        Icons.account_circle_rounded,
        'Profile',
      ),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: isDark ? sem.borderSubtle : const Color(0xFFE8E8F0),
                width: 0.8,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: List.generate(
                  items.length,
                  (i) => Expanded(
                    child: _NavBarItem(
                      item: items[i],
                      isSelected: selectedIndex == i,
                      onTap: () => onTap(i),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem(this.icon, this.selectedIcon, this.label);
}

class _NavBarItem extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScale;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AppDuration.fast,
      reverseDuration: AppDuration.spring,
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: AppCurves.standard,
        reverseCurve: AppCurves.spring,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pressController,
          builder: (context, _) {
            return Transform.scale(
              scale: _pressScale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: AppDuration.standard,
                    curve: AppCurves.standard,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : _isHovered
                          ? colorScheme.primary.withValues(alpha: 0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: AnimatedSwitcher(
                      duration: AppDuration.standard,
                      child: Icon(
                        widget.isSelected
                            ? widget.item.selectedIcon
                            : widget.item.icon,
                        key: ValueKey(widget.isSelected),
                        color: widget.isSelected
                            ? colorScheme.primary
                            : sem.onSurfaceMuted,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: AppDuration.standard,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.isSelected
                          ? colorScheme.primary
                          : sem.onSurfaceMuted,
                    ),
                    child: Text(widget.item.label),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
