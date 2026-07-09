import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../app_settings.dart';
import '../theme/theme.dart';
import '../models/timetable_entry.dart';
import '../timetable_manager.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/animated_card.dart';

class FacultyTimetablePage extends StatefulWidget {
  const FacultyTimetablePage({super.key});

  @override
  State<FacultyTimetablePage> createState() => _FacultyTimetablePageState();
}

class _FacultyTimetablePageState extends State<FacultyTimetablePage> {
  late String _selectedDay;
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  
  bool _isLoading = false;
  List<_FacultyTimetableEntry> _lectures = [];
  bool _hasConflict = false;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('EEEE').format(DateTime.now());
    if (_days.contains(today)) {
      _selectedDay = today;
    } else {
      _selectedDay = 'Monday';
    }
    _fetchTimetable();
  }

  Future<void> _fetchTimetable() async {
    setState(() {
      _isLoading = true;
      _hasConflict = false;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final divisions = AppSettings.facultyAssignedDivisions ?? [];
      final profileSnap = await FirebaseFirestore.instance.collection('faculty_profiles').doc(uid).get();
      final subjectsMap = (profileSnap.data()?['subjects'] as Map<String, dynamic>?) ?? {};

      List<_FacultyTimetableEntry> allLectures = [];

      for (final div in divisions) {
        final mySubjects = List<String>.from(subjectsMap[div] ?? []);
        if (mySubjects.isEmpty) continue;

        final entries = await TimetableManager.getEntriesForDay(division: div, day: _selectedDay);

        for (final entry in entries) {
          if (mySubjects.contains(entry.subjectCode)) {
            allLectures.add(_FacultyTimetableEntry(
              division: div,
              entry: entry,
            ));
          }
        }
      }

      // Sort by start time
      allLectures.sort((a, b) => a.entry.startTime.compareTo(b.entry.startTime));

      // Conflict Detection
      bool conflict = false;
      for (int i = 0; i < allLectures.length - 1; i++) {
        final current = allLectures[i].entry;
        final next = allLectures[i + 1].entry;
        // If next lecture starts before current lecture ends, and they are in different divisions
        if (next.startTime < current.endTime) {
          conflict = true;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _lectures = allLectures;
          _hasConflict = conflict;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading timetable: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _notifyCRsOfConflict() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = AppSettings.facultyName ?? 'Faculty';
    final divisions = AppSettings.facultyAssignedDivisions ?? [];
    
    for (final div in divisions) {
      final Map<String, dynamic> crPayload = {
        'notificationId': 'conflict_${DateTime.now().millisecondsSinceEpoch}_$div',
        'type': 'faculty_conflict',
        'title': 'Faculty Schedule Conflict',
        'body': 'Prof. $name has reported a schedule conflict on $_selectedDay. Please check your timetables.',
        'division': div,
        'role': 'CR',
        'uid': uid ?? '',
        'priority': 'high',
        'deepLink': '/cr_dashboard', // Verify this deeplink exists or matches your structure
        'processed': false,
        'attempts': 0,
        'nextRetryAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      debugPrint('OUTBOX PAYLOAD (Notify CRs): $crPayload');
      await FirebaseFirestore.instance.collection('notification_outbox').add(crPayload);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CRs notified of conflict.')));
    }
  }

  String _formatTime(int minutesFromMidnight) {
    int hour = minutesFromMidnight ~/ 60;
    int minute = minutesFromMidnight % 60;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  int get _currentMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  bool _isToday() {
    return _selectedDay == DateFormat('EEEE').format(DateTime.now());
  }

  String _getNextClass() {
    if (!_isToday() || _lectures.isEmpty) return 'None';
    final current = _currentMinutes;
    for (final item in _lectures) {
      if (item.entry.startTime > current) {
        return '${item.entry.displaySubject} at ${_formatTime(item.entry.startTime)}';
      }
    }
    return 'None';
  }

  Widget _buildSummaryCard(ColorScheme colorScheme, AppSemanticColors sem) {
    return AnimatedCard(
      borderRadius: AppRadius.xl,
      backgroundColor: sem.surfaceElevated,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: sem.borderSubtle, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    title: 'Today\'s Classes',
                    value: _lectures.length.toString(),
                    icon: Icons.class_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                Container(width: 1, height: 40, color: sem.borderSubtle),
                Expanded(
                  child: _buildSummaryMetric(
                    title: 'Assigned Divisions',
                    value: (AppSettings.facultyAssignedDivisions?.length ?? 0).toString(),
                    icon: Icons.groups_rounded,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            if (_isToday() && _lectures.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(color: sem.borderSubtle, height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.next_plan_rounded, size: 16, color: sem.onSurfaceMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Next Class: ', style: TextStyle(color: sem.onSurfaceMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Text(
                      _getNextClass(),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({required String title, required String value, required IconData icon, required Color color}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).extension<AppSemanticColors>()!.onSurfaceMuted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x2l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consolidated Timetable',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Viewing all your classes across assigned divisions',
                    style: TextStyle(color: sem.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            
            // Summary Card
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                child: _buildSummaryCard(colorScheme, sem),
              ),

            const SizedBox(height: AppSpacing.xl),

            // Segmented Day Selector
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  final day = _days[index];
                  final isSelected = day == _selectedDay;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: GestureDetector(
                      onTap: () {
                        if (!isSelected) {
                          setState(() => _selectedDay = day);
                          _fetchTimetable();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: isSelected ? colorScheme.primary : sem.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: isSelected ? colorScheme.primary : sem.borderSubtle,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          day.substring(0, 3),
                          style: TextStyle(
                            color: isSelected ? Colors.white : colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            if (_hasConflict)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.lg, AppSpacing.x2l, 0),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: sem.cancelled.withValues(alpha: 0.1),
                    border: Border.all(color: sem.cancelled.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: sem.cancelled),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Schedule Conflict Detected!',
                          style: TextStyle(color: sem.cancelled, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: _notifyCRsOfConflict,
                        child: Text('Notify CRs', style: TextStyle(color: sem.cancelled)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // Lectures List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _lectures.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 64, color: colorScheme.primary.withValues(alpha: 0.2)),
                              const SizedBox(height: AppSpacing.lg),
                              Text('No Classes Scheduled', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                              const SizedBox(height: AppSpacing.xs),
                              Text('You have a free day on $_selectedDay.', style: TextStyle(color: sem.onSurfaceMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.sm, AppSpacing.x2l, AppSpacing.x4l),
                          itemCount: _lectures.length,
                          itemBuilder: (context, index) {
                            final item = _lectures[index];
                            final divLabel = item.division.split('_').last;
                            
                            final isLive = _isToday() && item.entry.startTime <= _currentMinutes && item.entry.endTime > _currentMinutes;
                            
                            return StaggeredListItem(
                              index: index,
                              child: AnimatedCard(
                                borderRadius: AppRadius.lg,
                                backgroundColor: isLive ? colorScheme.primary.withValues(alpha: 0.05) : sem.surfaceElevated,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isLive ? colorScheme.primary : sem.borderSubtle,
                                      width: isLive ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    boxShadow: isLive ? [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2)] : [],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    child: Row(
                                      children: [
                                        // Time Indicator
                                        Container(
                                          width: 80,
                                          padding: const EdgeInsets.all(AppSpacing.md),
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
                                              const SizedBox(height: 2),
                                              Text(
                                                'to',
                                                style: TextStyle(fontSize: 10, color: colorScheme.primary.withValues(alpha: 0.7)),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatTime(item.entry.endTime),
                                                style: TextStyle(fontWeight: FontWeight.w800, color: colorScheme.primary, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.lg),
                                        // Lecture Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.entry.displaySubject,
                                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
                                                    ),
                                                  ),
                                                  if (isLive)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: colorScheme.primary,
                                                        borderRadius: BorderRadius.circular(AppRadius.full),
                                                      ),
                                                      child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: AppSpacing.sm),
                                              Wrap(
                                                spacing: AppSpacing.md,
                                                runSpacing: AppSpacing.xs,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.class_rounded, size: 14, color: sem.onSurfaceMuted),
                                                      const SizedBox(width: 4),
                                                      Text('Div $divLabel', style: TextStyle(color: sem.onSurfaceMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                                                    ],
                                                  ),
                                                  if (item.entry.room != null && item.entry.room!.isNotEmpty)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.room_rounded, size: 14, color: sem.onSurfaceMuted),
                                                        const SizedBox(width: 4),
                                                        Text(item.entry.room!, style: TextStyle(color: sem.onSurfaceMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                              if (isLive) ...[
                                                const SizedBox(height: AppSpacing.md),
                                                Text(
                                                  'Ends in ${item.entry.endTime - _currentMinutes} minutes',
                                                  style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacultyTimetableEntry {
  final String division;
  final TimetableEntry entry;

  _FacultyTimetableEntry({required this.division, required this.entry});
}
