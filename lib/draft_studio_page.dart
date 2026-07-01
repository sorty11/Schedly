import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'user_roles.dart';
import 'models/section_config.dart';
import 'models/period_config.dart';
import 'models/timetable_entry.dart';
import 'timetable_manager.dart';
import 'widgets/timetable_studio_sheet.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/animations/floating_empty_state.dart';

class DraftStudioPage extends StatefulWidget {
  final String division;

  const DraftStudioPage({super.key, required this.division});

  @override
  State<DraftStudioPage> createState() => _DraftStudioPageState();
}

class _DraftStudioPageState extends State<DraftStudioPage> {
  SectionConfig? _config;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final sectionId = AppSettings.sectionId;
      if (sectionId == null) throw Exception("No section attached.");

      final doc = await FirebaseFirestore.instance.collection('sections').doc(sectionId).get();
      if (doc.exists) {
        setState(() {
          _config = SectionConfig.fromJson(doc.data()!, doc.id);
          _loading = false;
        });
      } else {
        throw Exception("Configuration not found.");
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Error Loading Config',
        message: e.toString().replaceAll('Exception: ', ''),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _publishTimetable() async {
    // Phase 1 MVP: Dummy publish to show intent
    AppDialogs.showSnackBar(
      context: context,
      message: 'Validating & Publishing... (Coming Soon)',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_config == null || _config!.workingDays.isEmpty) {
      return Scaffold(body: Center(child: FloatingEmptyState(
        icon: Icons.calendar_today_rounded,
        title: 'No Working Days',
        subtitle: 'No working days have been configured for this section.',
      )));
    }

    final isCR = AppSettings.currentRole == UserRole.cr;
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return DefaultTabController(
      length: _config!.workingDays.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Timetable Studio', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            if (isCR)
              FilledButton.icon(
                onPressed: _publishTimetable,
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: const Text('Publish'),
                style: FilledButton.styleFrom(
                  backgroundColor: sem.conducted,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            const SizedBox(width: 16),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _config!.workingDays.map((day) => Tab(text: day)).toList(),
          ),
        ),
        body: TabBarView(
          children: _config!.workingDays.map((day) {
            return _DayView(
              division: widget.division,
              day: day,
              periods: _config!.periods,
              isCR: isCR,
              config: _config!,
            );
          }).toList(),
        ),
        floatingActionButton: isCR
            ? FloatingActionButton.extended(
                onPressed: () {
                  // Trigger Quick Add Mode
                  AppDialogs.showSnackBar(
                    context: context,
                    message: 'Quick Add Mode enabled! Tap any period to add.',
                  );
                },
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Quick Add'),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  final String division;
  final String day;
  final List<PeriodConfig> periods;
  final bool isCR;
  final SectionConfig config;

  const _DayView({
    required this.division,
    required this.day,
    required this.periods,
    required this.isCR,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    // The source collection depends on the role (CR edits Drafts, Students view Published)
    // For now, in MVP we'll just read from the standard collection so it doesn't break everything,
    // and we'll implement drafts next.
    final collection = isCR ? '${division}_draft' : division;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('timetables')
          .doc(division)
          .collection(day) // Fallback to live timetable for now to keep things visual while we migrate
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final lectures = snapshot.data!.docs.map((d) => TimetableEntry.fromFirestore(d)).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: periods.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final period = periods[index];
            
            // Find lectures that match this period's start time
            final periodLectures = lectures.where((l) => l.startTime == period.startTime).toList();

            return _PeriodCard(
              division: division,
              day: day,
              period: period,
              lectures: periodLectures,
              isCR: isCR,
              config: config,
            );
          },
        );
      },
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final String division;
  final String day;
  final PeriodConfig period;
  final List<TimetableEntry> lectures;
  final bool isCR;
  final SectionConfig config;

  const _PeriodCard({
    required this.division,
    required this.day,
    required this.period,
    required this.lectures,
    required this.isCR,
    required this.config,
  });

  String _formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _openStudio(BuildContext context, {TimetableEntry? entry}) {
    if (!isCR) return;
    
    // In Phase 3, we will modify TimetableStudioSheet to accept PeriodConfig directly.
    // For now, we open it with the day and time pre-filled implicitly by existing entry.
    TimetableStudioSheet.show(
      context,
      division: division,
      initialDay: day,
      existingEntry: entry,
    );
  }

  void _showLectureOptions(BuildContext context, TimetableEntry entry) {
    if (!isCR) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _openStudio(context, entry: entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(ctx);
                // Duplicate logic
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                FirebaseFirestore.instance
                  .collection('timetables')
                  .doc(division)
                  .collection(day)
                  .doc(entry.id)
                  .delete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    if (period.isBreak) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: sem.borderSubtle.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.coffee_rounded, size: 16, color: sem.onSurfaceMuted),
            const SizedBox(width: 8),
            Text(
              '${period.name} • ${_formatTime(period.startTime)} - ${_formatTime(period.endTime)}',
              style: TextStyle(color: sem.onSurfaceMuted, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (lectures.isEmpty) {
      return AnimatedCard(
        onTap: isCR ? () => _openStudio(context) : null,
        backgroundColor: colorScheme.surface,
        borderRadius: AppRadius.lg,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: sem.borderSubtle, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    period.name.replaceAll('Period ', 'P'),
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Empty Period',
                    style: TextStyle(color: sem.onSurfaceMuted, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTime(period.startTime)} - ${_formatTime(period.endTime)}',
                    style: TextStyle(color: sem.onSurfaceMuted, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              if (isCR)
                Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: lectures.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedCard(
            onTap: isCR ? () => _openStudio(context, entry: entry) : null,
            onLongPress: isCR ? () => _showLectureOptions(context, entry) : null,
            backgroundColor: colorScheme.surface,
            borderRadius: AppRadius.lg,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        period.name.replaceAll('Period ', 'P'),
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displaySubject,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 12, color: sem.onSurfaceMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatTime(period.startTime)} - ${_formatTime(period.endTime)}',
                              style: TextStyle(color: sem.onSurfaceMuted, fontSize: 12),
                            ),
                            if (entry.room != null && entry.room!.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.room_rounded, size: 12, color: sem.onSurfaceMuted),
                              const SizedBox(width: 4),
                              Text(
                                entry.room!,
                                style: TextStyle(color: sem.onSurfaceMuted, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        if (entry.batch != 'Whole Class') ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sem.borderSubtle.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(entry.batch, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sem.onSurfaceMuted)),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
