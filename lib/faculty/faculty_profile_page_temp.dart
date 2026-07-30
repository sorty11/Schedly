import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_settings.dart';
import '../theme/theme.dart';
import '../onboarding_flow.dart';
import '../widgets/animations/animated_button.dart';
import '../timetable_manager.dart';
import '../main.dart';
import '../services/notification_service.dart';
import '../services/local_notification_service.dart';
import '../models/faculty_lecture_context.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../widgets/animations/animated_list_tile.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../onboarding/services/tutorial_storage_service.dart';
import '../onboarding/services/onboarding_service.dart';
import '../about_schedly_page.dart';
import '../widgets/app_dialogs.dart';
import 'package:schedly/exceptions.dart';
import '../widgets/schedly_card.dart';
import '../widgets/dashboard_layout.dart';


class FacultyProfilePage extends StatefulWidget {
  const FacultyProfilePage({super.key});

  @override
  State<FacultyProfilePage> createState() => _FacultyProfilePageState();
}

class _FacultyProfilePageState extends State<FacultyProfilePage> {
  bool _isLoading = true;
  Map<String, List<String>> _subjectsMap = {};
  int _estimatedClasses = 0;
  AuthorizationStatus? _webNotificationStatus;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    if (kIsWeb) {
      _checkWebNotificationStatus();
    }
  }

  Future<void> _checkWebNotificationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (mounted) {
      setState(() {
        _webNotificationStatus = settings.authorizationStatus;
      });
    }
  }

  String get _facultyId {
    return AppSettings.facultyId ?? '';
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      if (_facultyId.isEmpty) throw AppException('Faculty ID is missing.');
      final snap = await FirebaseFirestore.instance.collection('faculty_profiles').doc(_facultyId).get();
      if (snap.exists) {
        final data = snap.data()!;
        final dynamic rawSubjects = data['subjects'];
        final Map<String, List<String>> parsedMap = {};
        if (rawSubjects is Map) {
          rawSubjects.forEach((k, v) {
            if (v is List) {
              parsedMap[k.toString()] = v.map((e) => e.toString()).toList();
            }
          });
        }
        _subjectsMap = parsedMap;
      } else {
        final divs = AppSettings.facultyAssignedDivisions ?? [];
        for (var div in divs) {
          _subjectsMap[div] = [];
        }
      }
      await _calculateEstimates();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateEstimates() async {
    int count = 0;
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    for (final div in _subjectsMap.keys) {
      final assignedSubj = _subjectsMap[div] ?? [];
      if (assignedSubj.isEmpty) continue;
      
      for (final day in days) {
        final entries = await TimetableManager.getEntriesForDay(division: div, day: day);
        for (final e in entries) {
          if (assignedSubj.any((s) => s.toLowerCase() == e.subject.toLowerCase() || s.toLowerCase() == e.subjectCode.toLowerCase() || e.subject.toLowerCase().contains(s.toLowerCase()))) {
            count++;
          }
        }
      }
    }
    if (mounted) {
      setState(() {
        _estimatedClasses = count;
      });
    }
  }

  Future<void> _saveChanges() async {
    try {
      final assignedDivs = _subjectsMap.keys.toList()..sort();
      
      await FirebaseFirestore.instance.collection('faculty_profiles').doc(_facultyId).set({
        'assignedDivisions': assignedDivs,
        'subjects': _subjectsMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      await AppSettings.saveFacultyDetails(
        name: AppSettings.facultyName ?? '',
        email: AppSettings.facultyEmail ?? '',
        department: AppSettings.facultyDepartment ?? '',
        designation: AppSettings.facultyDesignation ?? '',
        cabin: AppSettings.facultyCabin ?? '',
        assignedDivisions: assignedDivs,
      );
      
      await _calculateEstimates();
    } catch (e) {
      if (mounted) {
        AppDialogs.showSnackBar(context: context, message: 'Error saving: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> _rescheduleReminders() async {
    final divisions = AppSettings.facultyAssignedDivisions ?? [];
    if (divisions.isEmpty) return;

    final String today = DateFormat('EEEE').format(DateTime.now());
    List<FacultyLectureContext> allLectures = [];

    for (final div in divisions) {
      final mySubjects = List<String>.from(_subjectsMap[div] ?? []);
      if (mySubjects.isEmpty) continue;

      final entries = await TimetableManager.getEntriesForDay(division: div, day: today);

      for (final entry in entries) {
        if (mySubjects.contains(entry.subjectCode)) {
          allLectures.add(FacultyLectureContext(
            division: div,
            entry: entry,
          ));
        }
      }
    }

    allLectures.sort((a, b) => a.entry.startTime.compareTo(b.entry.startTime));
    
    await LocalNotificationService.scheduleFacultyReminders(
      allLectures,
      AppSettings.facultyReminderTime,
    );

    if (mounted) {
      AppDialogs.showSnackBar(
        context: context,
        message: 'Reminders updated for today.',
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final sem = Theme.of(context).extension<AppSemanticColors>()!;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Text(
            'Logout?',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: sem.cancelled,
              ),
              child: Text(
                'Logout',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await AppSettings.resetRole();
    await FirebaseAuth.instance.signOut();
    
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      (route) => false,
    );
  }

  void _removeDivision(String div) {
    final removedSubjects = _subjectsMap[div];
    setState(() {
      _subjectsMap.remove(div);
    });
    _saveChanges();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$div removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _subjectsMap[div] = removedSubjects ?? [];
            });
            _saveChanges();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showRemoveDivisionConfirmation(String div) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Remove Division?', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        content: Text(
          'Remove $div from your profile? This will also remove its associated subjects. The CR\'s timetable is not affected.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeDivision(div);
            },
            style: FilledButton.styleFrom(backgroundColor: sem.cancelled),
            child: Text('Remove', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddDivisionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDivisionSheet(
        existingDivisions: _subjectsMap.keys.toSet(),
        onDivisionsSelected: (selectedDivs) {
          setState(() {
            for (final div in selectedDivs) {
              if (!_subjectsMap.containsKey(div)) {
                _subjectsMap[div] = [];
              }
            }
          });
          _saveChanges();
        },
      ),
    );
  }

  void _showManageSubjectsBottomSheet(String div) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManageSubjectsSheet(
        division: div,
        initialSelected: _subjectsMap[div] ?? [],
        onSave: (newSubjects) {
          setState(() {
            _subjectsMap[div] = newSubjects;
          });
          _saveChanges();
        },
      ),
    );
  }

  Widget _sectionHeader(String label) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
        top: AppSpacing.x3l,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontFamily: 'Inter', 
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: semanticColors.onSurfaceMuted,
        ),
      ),
    );
  }

  Widget _buildAppearanceSegment() {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
        final current = themeController.themeMode;

        return Container(
          decoration: BoxDecoration(
            color: semanticColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: semanticColors.borderSubtle, width: 1),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              _appearancePill(
                label: 'Light',
                icon: Icons.wb_sunny_rounded,
                mode: ThemeMode.light,
                selected: current == ThemeMode.light,
                colorScheme: colorScheme,
                semanticColors: semanticColors,
              ),
              const SizedBox(width: AppSpacing.xs),
              _appearancePill(
                label: 'System',
                icon: Icons.language_rounded,
                mode: ThemeMode.system,
                selected: current == ThemeMode.system,
                colorScheme: colorScheme,
                semanticColors: semanticColors,
              ),
              const SizedBox(width: AppSpacing.xs),
              _appearancePill(
                label: 'Dark',
                icon: Icons.nightlight_round,
                mode: ThemeMode.dark,
                selected: current == ThemeMode.dark,
                colorScheme: colorScheme,
                semanticColors: semanticColors,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _appearancePill({
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required bool selected,
    required ColorScheme colorScheme,
    required AppSemanticColors semanticColors,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => themeController.setThemeMode(mode),
        child: AnimatedContainer(
          duration: AppDuration.standard,
          curve: AppCurves.standard,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? Colors.white
                    : semanticColors.onSurfaceMuted,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(fontFamily: 'Inter', 
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : semanticColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileGroup(List<Widget> tiles) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: semanticColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: semanticColors.borderSubtle, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.x2l,
                endIndent: AppSpacing.x2l,
                color: semanticColors.borderSubtle,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    bool isDestructive = false,
  }) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final effectiveColor = isDestructive ? semanticColors.cancelled : iconColor;

    return AnimatedListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: effectiveColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontFamily: 'Inter', 
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDestructive
              ? semanticColors.cancelled
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontFamily: 'Inter', 
          fontSize: 12,
          color: semanticColors.onSurfaceMuted,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: isDestructive
            ? semanticColors.cancelled.withValues(alpha: 0.5)
            : semanticColors.onSurfaceMuted,
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(fontFamily: 'Inter', 
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontFamily: 'Outfit', 
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(fontFamily: 'Inter', 
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildDivisionCard(String div, List<String> subjects) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SchedlyCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      div.replaceAll('_', ' '),
                      style: TextStyle(fontFamily: 'Outfit', 
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${subjects.length} Subjects Assigned',
                      style: TextStyle(fontFamily: 'Inter', 
                        fontSize: 13,
                        color: sem.onSurfaceMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showRemoveDivisionConfirmation(div),
                icon: Icon(Icons.delete_outline_rounded, color: sem.cancelled),
                tooltip: 'Remove Division',
              ),
            ],
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: subjects.map((s) => Chip(
                label: Text(
                  s,
                  style: TextStyle(fontFamily: 'Inter', 
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                onDeleted: () {
                  setState(() {
                    _subjectsMap[div]?.remove(s);
                  });
                  _saveChanges();
                },
                deleteIcon: Icon(Icons.close_rounded, size: 14, color: sem.onSurfaceMuted),
                backgroundColor: isDark ? sem.surfaceElevated2 : const Color(0xFFF0F0F8),
                side: BorderSide(color: sem.borderSubtle, width: 1),
              )).toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showManageSubjectsBottomSheet(div),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                foregroundColor: colorScheme.primary,
              ),
              child: const Text('Manage Subjects'),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = AppSettings.facultyName ?? 'Faculty Name';
    final email = AppSettings.facultyEmail ?? 'faculty@example.com';
    final department = AppSettings.facultyDepartment ?? 'Department';
    final designation = AppSettings.facultyDesignation ?? 'Designation';
    final cabin = AppSettings.facultyCabin ?? 'Cabin Unknown';

    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'F';

    final int totalDivisions = _subjectsMap.keys.length;
    final int totalSubjects = _subjectsMap.values.fold(0, (acc, list) => acc + list.length);

    int staggerIndex = 0;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'Faculty Profile',
          style: TextStyle(fontFamily: 'Outfit', 
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero header card ──────────────────────────────────────────
                  StaggeredListItem(
                    index: staggerIndex++,
                    child: AnimatedCard(
                      borderRadius: AppRadius.xl,
                      backgroundColor: sem.surfaceElevated,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(
                            color: sem.borderSubtle,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.x2l),
                        child: Column(
                          children: [
                            // Avatar gradient circle
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: TextStyle(fontFamily: 'Outfit', 
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // Name
                            Text(
                              name,
                              style: TextStyle(fontFamily: 'Outfit', 
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Division + Role chips
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _infoChip(
                                  icon: Icons.school_rounded,
                                  label: 'Faculty',
                                  bgColor: colorScheme.secondary.withValues(alpha: 0.1),
                                  textColor: colorScheme.secondary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _infoChip(
                                  icon: Icons.business_rounded,
                                  label: department,
                                  bgColor: sem.accent.withValues(alpha: 0.1),
                                  textColor: sem.accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(designation, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(email, style: TextStyle(color: sem.onSurfaceMuted, fontSize: 13)),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.meeting_room_rounded, size: 14, color: sem.onSurfaceMuted),
                                const SizedBox(width: 4),
                                Text(cabin, style: TextStyle(color: sem.onSurfaceMuted, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Teaching Portfolio Summary ───────────────────────────────────────────
                  _sectionHeader('Teaching Portfolio'),
                  StaggeredListItem(
                    index: staggerIndex++,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildPortfolioStat('Divisions', totalDivisions.toString(), Colors.white),
                          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                          _buildPortfolioStat('Subjects', totalSubjects.toString(), Colors.white),
                          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                          _buildPortfolioStat('Classes/wk', _estimatedClasses.toString(), Colors.white),
                        ],
                      ),
                    ),
                  ),

                  // ── Teaching Assignments ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm, top: AppSpacing.x3l),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TEACHING ASSIGNMENTS',
                          style: TextStyle(fontFamily: 'Inter', 
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: sem.onSurfaceMuted,
                          ),
                        ),
                        InkWell(
                          onTap: _showAddDivisionBottomSheet,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 16, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text('Add', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (_subjectsMap.isEmpty)
                    StaggeredListItem(
                      index: staggerIndex++,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4l, horizontal: AppSpacing.x2l),
                        decoration: BoxDecoration(
                          color: sem.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: sem.borderSubtle, width: 1),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 40,
                              color: sem.onSurfaceMuted.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No divisions assigned',
                              style: TextStyle(fontFamily: 'Outfit', 
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: sem.onSurfaceMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Tap "Add" above to assign your divisions',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Inter', 
                                fontSize: 13,
                                color: sem.onSurfaceMuted.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._subjectsMap.keys.toList().map((div) => StaggeredListItem(
                      index: staggerIndex++,
                      child: _buildDivisionCard(div, _subjectsMap[div] ?? []),
                    )),

                  // ── Appearance section ────────────────────────────────────────
                  _sectionHeader('Appearance'),
                  StaggeredListItem(
                    index: staggerIndex++,
                    child: _buildAppearanceSegment(),
                  ),

                  // ── Notification Preferences ──────────────────────────────────
                  _sectionHeader('Notification Preferences'),
                  StaggeredListItem(
                    index: staggerIndex++,
                    child: _buildTileGroup([
                      AnimatedListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: sem.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(Icons.notifications_active_rounded, color: sem.accent, size: 22),
                        ),
                        title: Text(
                          'Upcoming Lecture Reminder',
                          style: TextStyle(fontFamily: 'Inter', 
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Notify before class starts',
                          style: TextStyle(fontFamily: 'Inter', 
                            fontSize: 12,
                            color: sem.onSurfaceMuted,
                          ),
                        ),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: AppSettings.facultyReminderTime,
                            icon: Icon(Icons.expand_more_rounded, color: sem.onSurfaceMuted),
                            style: TextStyle(fontFamily: 'Inter', 
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Off')),
                              DropdownMenuItem(value: 5, child: Text('5 Minutes')),
                              DropdownMenuItem(value: 10, child: Text('10 Minutes')),
                              DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                            ],
                            onChanged: (int? newValue) async {
                              if (newValue != null) {
                                if (newValue > 0) {
                                  if (kIsWeb) {
                                    await NotificationService.promptWebPermission();
                                    await _checkWebNotificationStatus();
                                  } else {
                                    final plugin = LocalNotificationService.notifications.resolvePlatformSpecificImplementation<
                                        AndroidFlutterLocalNotificationsPlugin>();
                                    final isGranted = await plugin?.areNotificationsEnabled();
                                    if (isGranted == false) {
                                      if (context.mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Permissions Required'),
                                            content: const Text('To receive reminders, please enable notifications for Schedly in your device settings.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  }
                                }
                                await AppSettings.setFacultyReminderTime(newValue);
                                setState(() {});
                                
                                // Fetch today's classes and reschedule immediately
                                _rescheduleReminders();
                              }
                            },
                          ),
                        ),
                      ),
                    ]),
                  ),

                  // ── App Settings (Web Only for Notifications) ─────────────────
                  if (kIsWeb) ...[
                    _sectionHeader('App Settings'),
                    StaggeredListItem(
                      index: staggerIndex++,
                      child: _buildTileGroup([
                        _buildWebNotificationTile(sem),
                      ]),
                    ),
                  ],

                  // ── Help & Tutorials ──────────────────────────────────────────
                  _sectionHeader('Help & Tutorials'),
                  StaggeredListItem(
                    index: staggerIndex++,
                    child: _buildTileGroup([
                      _buildRoleTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Replay Tutorial',
                        subtitle: 'Replay the interactive guide',
                        iconColor: sem.accent,
                        onTap: () async {
                          await TutorialStorageService.resetAll();
                          if (!context.mounted) return;
                          OnboardingService.instance.startRoleTour(context, AppSettings.currentRole);
                        },
                      ),
                    ]),
                  ),

                  // ── About Schedly section ─────────────────────────────────────
                  _sectionHeader('About'),
                  StaggeredListItem(
                    index: staggerIndex++,
                    child: _buildTileGroup([
                      _buildRoleTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About Schedly',
                        subtitle: 'Version, features, and developer info',
                        iconColor: colorScheme.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AboutSchedlyPage()),
                          );
                        },
                      ),
                    ]),
                  ),

                  // ── Account section (destructive) ─────────────────────────────
                  _sectionHeader('Account'),
                  StaggeredListItem(
                    index: staggerIndex++,
                    child: Container(
                      decoration: BoxDecoration(
                        color: sem.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: sem.cancelled.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildRoleTile(
                        icon: Icons.logout_rounded,
                        title: 'Reset App & Logout',
                        subtitle: 'Clear all local data and sign out',
                        iconColor: sem.cancelled,
                        isDestructive: true,
                        onTap: () => _logout(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4l),
                ],
              ),
            ),
            ),
          ),
    );
  }

  Widget _buildWebNotificationTile(AppSemanticColors sem) {
    IconData icon;
    String title;
    String subtitle;
    Color color;
    bool isEnabled = false;
    bool isBlocked = false;

    switch (_webNotificationStatus) {
      case AuthorizationStatus.authorized:
        icon = Icons.notifications_active_rounded;
        title = 'Notifications Enabled';
        subtitle = 'You will receive push notifications';
        color = sem.success;
        isEnabled = true;
        break;
      case AuthorizationStatus.denied:
        icon = Icons.notifications_off_rounded;
        title = 'Permission Blocked';
        subtitle = 'Please enable notifications in your browser settings';
        color = sem.cancelled;
        isBlocked = true;
        break;
      default:
        icon = Icons.notifications_none_rounded;
        title = 'Push Notifications';
        subtitle = 'Tap to enable notifications on this device';
        color = sem.accent;
        break;
    }

    return AnimatedListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontFamily: 'Inter', 
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontFamily: 'Inter', 
          fontSize: 12,
          color: sem.onSurfaceMuted,
        ),
      ),
      trailing: isEnabled || isBlocked
          ? null
          : AnimatedButton(
              onPressed: () async {
                await NotificationService.promptWebPermission();
                await _checkWebNotificationStatus();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification settings updated')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'Enable',
                  style: TextStyle(fontFamily: 'Inter', 
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
            ),
    );
  }
}

class _AddDivisionSheet extends StatefulWidget {
  final Set<String> existingDivisions;
  final Function(List<String>) onDivisionsSelected;

  const _AddDivisionSheet({
    required this.existingDivisions,
    required this.onDivisionsSelected,
  });

  @override
  State<_AddDivisionSheet> createState() => _AddDivisionSheetState();
}

class _AddDivisionSheetState extends State<_AddDivisionSheet> {
  bool _isLoading = true;
  List<String> _availableDivisions = [];
  final Set<String> _selected = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchDivisions();
  }

  Future<void> _fetchDivisions() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('sections').where('active', isEqualTo: true).get();
      final allDivs = snap.docs.map((d) => d.id).toList();
      allDivs.removeWhere((div) => widget.existingDivisions.contains(div));
      allDivs.sort();
      if (mounted) {
        setState(() {
          _availableDivisions = allDivs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _availableDivisions.where((d) => d.toLowerCase().contains(_searchQuery)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Divisions',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search divisions...',
                    prefixIcon: Icon(Icons.search_rounded, color: sem.onSurfaceMuted),
                    filled: true,
                    fillColor: isDark ? sem.surfaceElevated : const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(child: Text('No divisions found.', style: TextStyle(color: sem.onSurfaceMuted)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (ctx, i) {
                          final div = filtered[i];
                          final isSelected = _selected.contains(div);
                          return CheckboxListTile(
                            title: Text(div.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w600)),
                            value: isSelected,
                            activeColor: colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selected.add(div);
                                else _selected.remove(div);
                              });
                            },
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: AnimatedButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      widget.onDivisionsSelected(_selected.toList());
                      Navigator.pop(context);
                    },
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              child: Text('Add ${_selected.length} Divisions', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

class _ManageSubjectsSheet extends StatefulWidget {
  final String division;
  final List<String> initialSelected;
  final Function(List<String>) onSave;

  const _ManageSubjectsSheet({
    required this.division,
    required this.initialSelected,
    required this.onSave,
  });

  @override
  State<_ManageSubjectsSheet> createState() => _ManageSubjectsSheetState();
}

class _ManageSubjectsSheetState extends State<_ManageSubjectsSheet> {
  bool _isLoading = true;
  List<String> _availableSubjects = [];
  late Set<String> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.toSet();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    try {
      final unique = await TimetableManager.getUniqueSubjects(division: widget.division);
      if (mounted) {
        setState(() {
          _availableSubjects = unique;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _availableSubjects.where((d) => d.toLowerCase().contains(_searchQuery)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Manage Subjects',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                Text(
                  widget.division.replaceAll('_', ' '),
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search subjects...',
                    prefixIcon: Icon(Icons.search_rounded, color: sem.onSurfaceMuted),
                    filled: true,
                    fillColor: isDark ? sem.surfaceElevated : const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(child: Text('No subjects found in timetable.', style: TextStyle(color: sem.onSurfaceMuted)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (ctx, i) {
                          final subj = filtered[i];
                          final isSelected = _selected.contains(subj);
                          return CheckboxListTile(
                            title: Text(subj, style: const TextStyle(fontWeight: FontWeight.w600)),
                            value: isSelected,
                            activeColor: colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selected.add(subj);
                                else _selected.remove(subj);
                              });
                            },
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: AnimatedButton(
              onPressed: () {
                widget.onSave(_selected.toList()..sort());
                Navigator.pop(context);
              },
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

