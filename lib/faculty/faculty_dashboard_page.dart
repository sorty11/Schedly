import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../app_settings.dart';
import '../theme/theme.dart';
import '../models/timetable_entry.dart';
import '../models/faculty_request.dart';
import '../timetable_manager.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/animated_button.dart';
import '../widgets/skeleton_loader.dart';
import 'faculty_request_sheet.dart';
import 'faculty_panel_page.dart';
import '../create_announcement_page.dart';
import '../models/faculty_lecture_context.dart';
import '../services/local_notification_service.dart';
import '../services/timetable_resolver_service.dart';

class FacultyDashboardPage extends StatefulWidget {
  const FacultyDashboardPage({super.key});

  @override
  State<FacultyDashboardPage> createState() => _FacultyDashboardPageState();
}

class _FacultyDashboardPageState extends State<FacultyDashboardPage> {
  late Stream<List<FacultyLectureContext>> _todayLecturesStream;
  late Stream<List<FacultyRequest>> _pendingRequestsStream;

  @override
  void initState() {
    super.initState();
    _todayLecturesStream = _streamTodayLectures();
    _pendingRequestsStream = _streamPendingRequests();
  }

  void _refresh() {
    setState(() {
      _todayLecturesStream = _streamTodayLectures();
    });
  }

  Stream<List<FacultyRequest>> _streamPendingRequests() {
    final uid = AppSettings.facultyId ?? '';
    if (uid.isEmpty) return Stream.value([]);

    final divisions = AppSettings.facultyAssignedDivisions ?? [];
    if (divisions.isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collectionGroup('faculty_requests')
        .where('facultyId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => FacultyRequest.fromFirestore(d)).toList(),
        );
  }

  Stream<List<FacultyLectureContext>> _streamTodayLectures() async* {
    final divisions = AppSettings.facultyAssignedDivisions ?? [];
    final String today = DateFormat('EEEE').format(DateTime.now());

    final uid = AppSettings.facultyId;
    if (uid == null) {
      yield [];
      return;
    }

    final profileSnap = await FirebaseFirestore.instance
        .collection('faculty_profiles')
        .doc(uid)
        .get();
    final profileData = profileSnap.data() ?? {};
    final subjectsMap =
        (profileData['subjects'] as Map<String, dynamic>?) ?? {};

    if (divisions.isEmpty) {
      yield [];
      return;
    }

    final streams = divisions.map((div) {
      final mySubjects = List<String>.from(subjectsMap[div] ?? []);
      if (mySubjects.isEmpty) return Stream.value(<FacultyLectureContext>[]);

      return TimetableManager.streamEntriesForDay(
        division: div,
        day: today,
      ).map((entries) {
        final todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final resolved = TimetableResolverService.resolve(
          rawEntries: entries,
          targetDateStr: todayDateStr,
        );

        if (resolved.isHoliday) {
          return <FacultyLectureContext>[];
        }

        return resolved.lectures
            .where((e) => mySubjects.contains(e.subjectCode) && e.isActive)
            .map((e) => FacultyLectureContext(division: div, entry: e))
            .toList();
      });
    }).toList();

    yield* CombineLatestStream.list(streams).map((listOfLists) {
      final allLectures = listOfLists.expand((l) => l).toList();
      allLectures.sort(
        (a, b) => a.entry.startTime.compareTo(b.entry.startTime),
      );

      LocalNotificationService.scheduleFacultyReminders(
        allLectures,
        AppSettings.facultyReminderTime,
      );

      return allLectures;
    });
  }

  String _formatTime(int minutesFromMidnight) {
    int hour = minutesFromMidnight ~/ 60;
    int minute = minutesFromMidnight % 60;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = AppSettings.facultyName ?? 'Faculty';
    final firstName = name.split(' ').first;
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Greeting header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x2l,
                    AppSpacing.x2l,
                    AppSpacing.x2l,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}, $firstName 👋',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              today,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      // Quick actions cluster
                      Row(
                        children: [
                          _HeaderAction(
                            icon: Icons.dashboard_customize_rounded,
                            label: 'Panel',
                            color: colorScheme.primary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FacultyPanelPage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _HeaderAction(
                            icon: Icons.add_circle_outline_rounded,
                            label: 'Extra Class',
                            color: colorScheme.secondary,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const FacultyRequestSheet(
                                requestType: FacultyRequestType.addExtra,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _HeaderAction(
                            icon: Icons.campaign_outlined,
                            label: 'Announce',
                            color: sem.conducted,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateAnnouncementPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Pending requests banner ───────────────────────────────────
              SliverToBoxAdapter(
                child: StreamBuilder<List<FacultyRequest>>(
                  stream: _pendingRequestsStream,
                  builder: (context, snapshot) {
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x2l,
                        AppSpacing.sm,
                        AppSpacing.x2l,
                        AppSpacing.sm,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: sem.warning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: sem.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: sem.warning.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.hourglass_top_rounded,
                                color: sem.warning,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${requests.length} request${requests.length > 1 ? 's' : ''} pending',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: sem.warning,
                                    ),
                                  ),
                                  Text(
                                    'Awaiting CR approval',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: sem.warning.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Today's classes header ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x2l,
                    AppSpacing.xl,
                    AppSpacing.x2l,
                    AppSpacing.md,
                  ),
                  child: Text(
                    "Today's Schedule",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),

              // ── Today's classes list ─────────────────────────────────────
              SliverToBoxAdapter(
                child: StreamBuilder<List<FacultyLectureContext>>(
                  stream: _todayLecturesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2l,
                        ),
                        itemCount: 3,
                        itemBuilder: (ctx, i) => SkeletonLoader(
                          width: double.infinity,
                          height: 120,
                          borderRadius: AppRadius.lg,
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(error: '${snapshot.error}');
                    }

                    final lectures = snapshot.data ?? [];
                    if (lectures.isEmpty) {
                      return const _EmptySchedule();
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2l,
                      ),
                      itemCount: lectures.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        return StaggeredListItem(
                          index: index,
                          child: _LectureCard(
                            item: lectures[index],
                            formatTime: _formatTime,
                            onOptions: () =>
                                _showLectureOptions(context, lectures[index]),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x6l)),
            ],
          ),
        ),
      ),
    );
  }

  void _showLectureOptions(BuildContext context, FacultyLectureContext item) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x2l,
            AppSpacing.lg,
            AppSpacing.x2l,
            AppSpacing.x2l,
          ),
          decoration: BoxDecoration(
            color: isDark ? sem.surfaceElevated : colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.x2l),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sem.borderSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Lecture info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.class_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.entry.displaySubject,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Div ${item.division.split('_').last}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: sem.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),

                // Request cancellation
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: sem.cancelled.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.cancel_outlined,
                        color: sem.cancelled,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Request Cancellation',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: sem.cancelled,
                      ),
                    ),
                    subtitle: Text(
                      'Send a cancellation request to your CR',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: sem.onSurfaceMuted,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FacultyRequestSheet(
                          requestType: FacultyRequestType.cancel,
                          prefillDivision: item.division,
                          prefillEntry: item.entry,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header Action Button ────────────────────────────────────────────────────────
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lecture Card ───────────────────────────────────────────────────────────────
class _LectureCard extends StatelessWidget {
  final FacultyLectureContext item;
  final String Function(int) formatTime;
  final VoidCallback onOptions;

  const _LectureCard({
    required this.item,
    required this.formatTime,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entry = item.entry;
    final divLabel = item.division.split('_').last;
    final isActive = entry.isActive;
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final isLive = nowMins >= entry.startTime && nowMins < entry.endTime;
    final isUpcoming = nowMins < entry.startTime;
    final isPast = nowMins >= entry.endTime;

    Color statusColor = sem.onSurfaceMuted;
    String statusLabel = 'Past';
    IconData statusIcon = Icons.check_circle_outline_rounded;

    if (!isActive) {
      statusColor = sem.cancelled;
      statusLabel = 'Cancelled';
      statusIcon = Icons.cancel_outlined;
    } else if (isLive) {
      statusColor = sem.conducted;
      statusLabel = 'Live now';
      statusIcon = Icons.circle;
    } else if (isUpcoming) {
      statusColor = colorScheme.primary;
      statusLabel = 'Upcoming';
      statusIcon = Icons.schedule_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOptions,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: isLive
                ? colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.06)
                : isDark
                ? sem.surfaceElevated
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isLive
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : sem.borderSubtle,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time column
                SizedBox(
                  width: 68,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatTime(entry.startTime),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: isLive
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        formatTime(entry.endTime),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          color: sem.onSurfaceMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: sem.onSurfaceMuted.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          '${entry.durationMinutes}m',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sem.onSurfaceMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  color: sem.borderSubtle,
                ),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displaySubject,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          decoration: !isActive
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: sem.cancelled,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          _MetaChip(
                            icon: Icons.group_rounded,
                            label: 'Div $divLabel',
                          ),
                          if (entry.room != null && entry.room!.isNotEmpty)
                            _MetaChip(
                              icon: Icons.room_rounded,
                              label: entry.room!,
                            ),
                          if (entry.batch != 'Whole Class')
                            _MetaChip(
                              icon: Icons.groups_2_rounded,
                              label: entry.batch,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge + options
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        if (isLive)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sem.conducted,
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: sem.onSurfaceMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: sem.onSurfaceMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: sem.onSurfaceMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.x5l,
        horizontal: AppSpacing.x2l,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 56,
            color: sem.onSurfaceMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No classes today',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: sem.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enjoy your free day!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: sem.onSurfaceMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x2l),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: sem.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not load classes',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: sem.error,
            ),
          ),
          Text(
            error,
            style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
