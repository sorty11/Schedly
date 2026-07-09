import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_settings.dart';
import '../theme/theme.dart';
import '../models/timetable_entry.dart';
import '../models/faculty_request.dart';
import '../timetable_manager.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/animated_button.dart';
import 'faculty_request_sheet.dart';
import '../create_announcement_page.dart';
import '../models/faculty_lecture_context.dart';
import '../services/local_notification_service.dart';

class FacultyDashboardPage extends StatefulWidget {
  const FacultyDashboardPage({super.key});

  @override
  State<FacultyDashboardPage> createState() => _FacultyDashboardPageState();
}

class _FacultyDashboardPageState extends State<FacultyDashboardPage> {
  late Future<List<FacultyLectureContext>> _todayLecturesFuture;
  late Stream<List<FacultyRequest>> _pendingRequestsStream;

  @override
  void initState() {
    super.initState();
    _todayLecturesFuture = _fetchTodayLectures();
    _pendingRequestsStream = _streamPendingRequests();
  }
  
  void _refresh() {
    setState(() {
      _todayLecturesFuture = _fetchTodayLectures();
    });
  }

  Stream<List<FacultyRequest>> _streamPendingRequests() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return Stream.value([]);
    
    // We must query across all assigned divisions. For simplicity in Flutter,
    // if a faculty has 1-10 divisions, we can just merge streams or use a single query if structured differently.
    // Since we put requests in sections/{div}/faculty_requests, we need multiple streams.
    
    final divisions = AppSettings.facultyAssignedDivisions ?? [];
    if (divisions.isEmpty) return Stream.value([]);
    
    // Merge streams from multiple collections
    // Since Firebase doesn't support logical OR across subcollections without collectionGroup,
    // and collectionGroup would need an index, let's just use collectionGroup filtering by facultyId.
    return FirebaseFirestore.instance
        .collectionGroup('faculty_requests')
        .where('facultyId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => FacultyRequest.fromFirestore(d)).toList());
  }

  Future<List<FacultyLectureContext>> _fetchTodayLectures() async {
    final divisions = AppSettings.facultyAssignedDivisions ?? [];
    final String today = DateFormat('EEEE').format(DateTime.now());
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    // Fetch faculty subjects
    final profileSnap = await FirebaseFirestore.instance.collection('faculty_profiles').doc(uid).get();
    final profileData = profileSnap.data() ?? {};
    final subjectsMap = (profileData['subjects'] as Map<String, dynamic>?) ?? {};

    List<FacultyLectureContext> allLectures = [];

    for (final div in divisions) {
      final mySubjects = List<String>.from(subjectsMap[div] ?? []);
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
    
    // Sort by startTime
    allLectures.sort((a, b) => a.entry.startTime.compareTo(b.entry.startTime));
    
    // Auto-schedule reminders for today's lectures
    await LocalNotificationService.scheduleFacultyReminders(
      allLectures,
      AppSettings.facultyReminderTime,
    );
    
    return allLectures;
  }

  String _formatTime(int minutesFromMidnight) {
    int hour = minutesFromMidnight ~/ 60;
    int minute = minutesFromMidnight % 60;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  Widget _buildLectureCard(FacultyLectureContext item) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final divLabel = item.division.split('_').last; 
    
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          _showLectureOptions(context, item);
        },
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatTime(item.entry.startTime),
                      style: TextStyle(fontWeight: FontWeight.w800, color: colorScheme.primary, fontSize: 13),
                    ),
                    Text(
                      '${item.entry.durationMinutes}m',
                      style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.primary.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.entry.displaySubject,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.group_rounded, size: 14, color: sem.onSurfaceMuted),
                        const SizedBox(width: 4),
                        Text('Div $divLabel', style: TextStyle(color: sem.onSurfaceMuted, fontSize: 12)),
                        if (item.entry.room != null && item.entry.room!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.room_rounded, size: 14, color: sem.onSurfaceMuted),
                          const SizedBox(width: 4),
                          Text(item.entry.room!, style: TextStyle(color: sem.onSurfaceMuted, fontSize: 12)),
                        ]
                      ],
                    )
                  ],
                ),
              ),
              Icon(Icons.more_vert_rounded, color: sem.onSurfaceMuted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = AppSettings.facultyName ?? 'Faculty';
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.x2l, AppSpacing.x2l, AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good Morning,',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Pending Requests Banner
              SliverToBoxAdapter(
                child: StreamBuilder<List<FacultyRequest>>(
                  stream: _pendingRequestsStream,
                  builder: (context, snapshot) {
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.md),
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_empty_rounded, color: Colors.orange[800]),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'You have ${requests.length} pending lecture request(s) awaiting CR approval.',
                                style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.lg, AppSpacing.x2l, AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Classes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        DateFormat('MMM d').format(DateTime.now()),
                        style: TextStyle(color: sem.onSurfaceMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: FutureBuilder<List<FacultyLectureContext>>(
                  future: _todayLecturesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.x3l),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.x3l),
                        child: Center(child: Text('Error loading classes: ${snapshot.error}')),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4l),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.event_available_rounded, size: 48, color: sem.onSurfaceMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: AppSpacing.md),
                            Text('No classes scheduled for today!', style: TextStyle(color: sem.onSurfaceMuted)),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final lecture = snapshot.data![index];
                        return StaggeredListItem(
                          index: index,
                          child: _buildLectureCard(lecture),
                        );
                      },
                    );
                  },
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.xl, AppSpacing.x2l, AppSpacing.sm),
                  child: Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const FacultyRequestSheet(requestType: FacultyRequestType.addExtra),
                            );
                          },
                          backgroundColor: isDark ? sem.surfaceElevated2 : const Color(0xFFF5F5F7),
                          foregroundColor: colorScheme.primary,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_circle_outline_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Add Extra Class'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AnimatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateAnnouncementPage(),
                              ),
                            );
                          },
                          backgroundColor: isDark ? sem.surfaceElevated2 : const Color(0xFFF5F5F7),
                          foregroundColor: colorScheme.secondary,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.campaign_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Announce'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x4l)),
            ],
          ),
        ),
      ),
    );
  }

  void _showLectureOptions(BuildContext context, FacultyLectureContext item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Options for ${item.entry.displaySubject}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Request Cancellation', style: TextStyle(color: Colors.red)),
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
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }
}


