import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard_page.dart';
import 'weekly_timetable_page.dart';
import 'analytics_page.dart';
import 'updates_page.dart';
import 'profile_page.dart';
import 'services/announcement_listener.dart';
import 'services/conduct_sync_service.dart';
import 'services/migration_service.dart';
import 'theme/theme.dart';
import 'app_settings.dart';
import 'onboarding/services/onboarding_service.dart';
import 'onboarding/services/feature_discovery_service.dart';
import 'onboarding/widgets/tutorial_target.dart';
import 'onboarding/services/tutorial_controller.dart';

class HomePage extends StatefulWidget {
  final String division;

  const HomePage({
    super.key,
    required this.division,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    AnnouncementListener.start(widget.division);
    ConductSyncService.syncPendingLectures(widget.division);
    _loadUnreadCount();

    FirebaseFirestore.instance
        .collection('sections')
        .doc(widget.division)
        .collection('notifications')
        .snapshots()
        .listen((_) => _loadUnreadCount());

    _runMigrationIfNeeded();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      OnboardingService.instance.initializeAndCheckFirstLaunch(context, AppSettings.currentRole);
      FeatureDiscoveryService.checkNewFeatures(context);
    });
  }

  Future<void> _runMigrationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'migration_v2_${widget.division}';
    if (!(prefs.getBool(key) ?? false)) {
      try {
        await MigrationService.upgradeToV2(widget.division);
        await prefs.setBool(key, true);
      } catch (e) {
        debugPrint('Migration failed: $e');
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt('last_seen_notifications') ?? 0;
      final snap = await FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .collection('notifications')
          .get();

      int count = 0;
      for (final doc in snap.docs) {
        final ts = doc.data()['createdAt'];
        if (ts != null &&
            (ts as Timestamp).millisecondsSinceEpoch > lastSeen) {
          count++;
        }
      }
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadCount = 0);
    }
  }

  Future<void> _markNotificationsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'last_seen_notifications',
      DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() => _unreadCount = 0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      DashboardPage(division: widget.division),
      WeeklyTimetablePage(division: widget.division),
      AnalyticsPage(division: widget.division),
      const UpdatesPage(),
      ProfilePage(division: widget.division),
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
      bottomNavigationBar: _SchedlyNavBar(
        selectedIndex: _currentIndex,
        unreadCount: _unreadCount,
        onTap: (index) async {
          if (index == 3) await _markNotificationsRead();
          setState(() => _currentIndex = index);
          TutorialController.instance.completeStep();
        },
      ),
    );
  }
}

// ─── Custom Navigation Bar ─────────────────────────────────────────────────────
class _SchedlyNavBar extends StatelessWidget {
  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  const _SchedlyNavBar({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home', targetId: 'dashboard_tab'),
      _NavItem(Icons.view_week_outlined, Icons.view_week_rounded, 'Timetable', targetId: 'timetable_tab'),
      _NavItem(Icons.insights_outlined, Icons.insights_rounded, 'Analytics', targetId: 'analytics_tab'),
      _NavItem(
        Icons.notifications_outlined,
        Icons.notifications_rounded,
        'Updates',
        badge: unreadCount,
        targetId: 'announcements_tab',
      ),
      _NavItem(Icons.account_circle_outlined, Icons.account_circle_rounded, 'Profile', targetId: 'profile_tab'),
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
                color: isDark
                    ? sem.borderSubtle
                    : const Color(0xFFE8E8F0),
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
                    child: items[i].targetId != null ? TutorialTarget(
                      id: items[i].targetId!,
                      child: _NavBarItem(
                        item: items[i],
                        isSelected: selectedIndex == i,
                        onTap: () => onTap(i),
                      ),
                    ) : _NavBarItem(
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
  final int badge;
  final String? targetId;

  const _NavItem(
    this.icon,
    this.selectedIcon,
    this.label, {
    this.targetId,
    this.badge = 0,
  });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedSwitcher(
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
                        if (widget.item.badge > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: sem.cancelled,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.surfaceDark
                                      : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                widget.item.badge > 9
                                    ? '9+'
                                    : '${widget.item.badge}',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
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
