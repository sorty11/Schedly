import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard_page.dart';
import 'weekly_timetable_page.dart';

import 'updates_page.dart';
import 'profile_page.dart';
import 'services/announcement_listener.dart';
import 'services/conduct_sync_service.dart';
import 'services/migration_service.dart';
import 'theme/theme.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'onboarding/services/onboarding_service.dart';
import 'onboarding/services/feature_discovery_service.dart';
import 'onboarding/widgets/tutorial_target.dart';
import 'onboarding/services/tutorial_controller.dart';
import 'cr_panel_page.dart';
import 'attendance_page.dart';

class HomePage extends StatefulWidget {
  final String division;

  const HomePage({super.key, required this.division});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _unreadCount = 0;
  StreamSubscription? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    AnnouncementListener.start(widget.division);
    if (AppSettings.currentRole == UserRole.cr ||
        AppSettings.currentRole == UserRole.sr) {
      ConductSyncService.syncPendingLectures(widget.division);
    }
    _loadUnreadCount();

    _notificationsSubscription = FirebaseFirestore.instance
        .collection('sections')
        .doc(widget.division)
        .collection('notifications')
        .snapshots()
        .listen((_) => _loadUnreadCount());

    _runMigrationIfNeeded();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      OnboardingService.instance.initializeAndCheckFirstLaunch(
        context,
        AppSettings.currentRole,
      );
      FeatureDiscoveryService.checkNewFeatures(context);
    });
  }

  Future<void> _runMigrationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final v2Key = 'migration_v2_${widget.division}';
    if (!(prefs.getBool(v2Key) ?? false)) {
      try {
        await MigrationService.upgradeToV2(widget.division);
        await prefs.setBool(v2Key, true);
      } catch (e) {
        debugPrint('Migration failed: $e');
      }
    }

    final sanitizeKey = 'migration_sanitize_subjects_${widget.division}';
    if (!(prefs.getBool(sanitizeKey) ?? false)) {
      try {
        await MigrationService.sanitizeSubjectNames(widget.division);
        await prefs.setBool(sanitizeKey, true);
        debugPrint('Subject sanitization completed for ${widget.division}');
      } catch (e) {
        debugPrint('Subject sanitization failed: $e');
      }
    }

    // Run Batch Migration only for CRs/SRs using a centralized flag
    if (AppSettings.currentRole == UserRole.cr ||
        AppSettings.currentRole == UserRole.sr) {
      try {
        final sectionRef = FirebaseFirestore.instance
            .collection('sections')
            .doc(widget.division);
        final sectionDoc = await sectionRef.get();
        if (sectionDoc.exists &&
            !(sectionDoc.data()?['batchMigrationV1'] ?? false)) {
          await MigrationService.migrateBatchNames(widget.division);
          await sectionRef.update({'batchMigrationV1': true});
          debugPrint('Batch migration V1 completed for ${widget.division}');
        }
      } catch (e) {
        debugPrint('Batch migration failed: $e');
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
        if (ts != null && (ts as Timestamp).millisecondsSinceEpoch > lastSeen) {
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
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(division: widget.division),
      WeeklyTimetablePage(division: widget.division),
      AttendancePage(division: widget.division),

      if (AppSettings.currentRole == UserRole.cr ||
          AppSettings.currentRole == UserRole.sr)
        const CRPanelPage(),
      const UpdatesPage(),
      ProfilePage(division: widget.division),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _SchedlyNavBar(
        selectedIndex: _currentIndex,
        unreadCount: _unreadCount,
        onTap: (index) async {
          if (pages[index] is UpdatesPage) await _markNotificationsRead();
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
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      const _NavItem(
        Icons.home_outlined,
        Icons.home_rounded,
        'Home',
        targetId: 'dashboard_tab',
      ),
      const _NavItem(
        Icons.view_week_outlined,
        Icons.view_week_rounded,
        'Timetable',
        targetId: 'timetable_tab',
      ),
      const _NavItem(
        Icons.fact_check_outlined,
        Icons.fact_check_rounded,
        'Attendance',
        targetId: 'attendance_tab',
      ),

      if (AppSettings.currentRole == UserRole.cr)
        const _NavItem(
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings_rounded,
          'CR Panel',
          targetId: 'admin_tab',
        )
      else if (AppSettings.currentRole == UserRole.sr)
        const _NavItem(
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings_rounded,
          'SR Panel',
          targetId: 'admin_tab',
        ),

      _NavItem(
        Icons.notifications_outlined,
        Icons.notifications_rounded,
        'Updates',
        badge: unreadCount,
        targetId: 'announcements_tab',
      ),
      const _NavItem(
        Icons.account_circle_outlined,
        Icons.account_circle_rounded,
        'Profile',
        targetId: 'profile_tab',
      ),
    ];

    final skin = VisualSkin.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: skin.navigationRecipe.decoration(context),
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
                    child: items[i].targetId != null
                        ? TutorialTarget(
                            id: items[i].targetId!,
                            child: _NavBarItem(
                              item: items[i],
                              isSelected: selectedIndex == i,
                              onTap: () => onTap(i),
                            ),
                          )
                        : _NavBarItem(
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
    final skin = VisualSkin.of(context);
    final activeColor = skin.navigationRecipe.activeItemColor;
    final inactiveColor = skin.navigationRecipe.inactiveItemColor;

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
                          ? activeColor.withValues(alpha: 0.12)
                          : _isHovered
                          ? activeColor.withValues(alpha: 0.06)
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
                                ? activeColor
                                : inactiveColor,
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
                      color: widget.isSelected ? activeColor : inactiveColor,
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
