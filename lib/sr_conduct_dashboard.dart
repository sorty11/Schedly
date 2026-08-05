import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'widgets/animations/floating_empty_state.dart';

import 'models/conduct_log.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/analytics_service.dart';
import 'timetable_manager.dart';
import 'services/local_notification_service.dart';
import 'models/event_category.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/schedly_card.dart';
import 'onboarding/widgets/tutorial_target.dart';
import 'widgets/app_dialogs.dart';

class SrConductDashboard extends StatefulWidget {
  final String division;
  final String subject;

  const SrConductDashboard({
    super.key,
    required this.division,
    required this.subject,
  });

  @override
  State<SrConductDashboard> createState() => _SrConductDashboardState();
}

class _SrConductDashboardState extends State<SrConductDashboard> {
  final DateFormat _dateFormat = DateFormat('EEE, MMM d');
  late Stream<List<ConductLog>> _pendingLogsStream;

  @override
  void initState() {
    super.initState();
    _pendingLogsStream = AnalyticsService.streamPendingLogs(widget.division, widget.subject, null, null);
  }

  void _showMarkingSheet(ConductLog log, Map<String, String> batchNames) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.x2l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verify Lecture',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${log.originalSlot.displaySubject} (${batchNames[log.originalSlot.batch] ?? log.originalSlot.batch})\n${log.date} at ${TimetableManager.formatTime(log.originalSlot.startTime, log.originalSlot.endTime)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x2l),
                _buildOptionBtn(context, log, 'conducted', 'Conducted', Icons.check_circle_rounded, Theme.of(context).extension<AppSemanticColors>()!.conducted, batchNames),
                const SizedBox(height: AppSpacing.md),
                _buildOptionBtn(context, log, 'cancelled', 'Cancelled', Icons.cancel_rounded, Theme.of(context).extension<AppSemanticColors>()!.cancelled, batchNames),
                const SizedBox(height: AppSpacing.md),
                _buildOptionBtn(context, log, 'rescheduled', 'Rescheduled', Icons.schedule_rounded, Theme.of(context).extension<AppSemanticColors>()!.rescheduled, batchNames),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionBtn(BuildContext context, ConductLog log, String statusCode, String statusLabel, IconData icon, Color color, Map<String, String> batchNames) {
    return AnimatedButton(
      onPressed: () async {
        Navigator.pop(context);
        
        if (statusCode == 'rescheduled') {
          _showSubjectSelectionSheet(log, batchNames);
          return;
        }

        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
        await AnalyticsService.updateLectureStatus(
          log: log,
          division: widget.division,
          newStatus: statusCode,
          markedBy: 'Subject Rep',
          markedByUid: currentUid,
        );
        if (!context.mounted) return;
        AppDialogs.showSnackBar(
          context: context,
          message: 'Marked as $statusLabel',
        );
      },
      backgroundColor: color,
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      borderRadius: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Mark $statusLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showSubjectSelectionSheet(ConductLog log, Map<String, String> batchNames) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.x2l, right: AppSpacing.x2l, top: AppSpacing.x2l, bottom: MediaQuery.of(context).viewInsets.bottom + 24
            ),
            child: FutureBuilder<List<SrIdentity>>(
              future: TimetableManager.getUniqueSrIdentities(division: widget.division),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
                }
                
                final subjects = snapshot.data ?? [];
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Select Actual Subject',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Which subject was taught instead of ${log.originalSlot.subject}?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.x2l),
                    if (subjects.isEmpty)
                      const FloatingEmptyState(
                        icon: Icons.menu_book_rounded,
                        title: 'No Subjects',
                        subtitle: 'No subjects found.',
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: subjects.length,
                          itemBuilder: (context, index) {
                            final subj = subjects[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AnimatedButton(
                                onPressed: () async {
                                  final reqDur = await TimetableManager.getSubjectRequiredDuration(division: widget.division, subject: subj.subject);
                                  
                                  if (reqDur >= 120 && log.durationMinutes < 120) {
                                      if (!context.mounted) return;
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('Invalid Replacement', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface)),
                                          content: Text('This replacement requires a 2-hour continuous slot, but the selected lecture occupies only a ${log.durationMinutes}-minute period.', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
                                          ],
                                        )
                                      );
                                      return;
                                  }

                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
                                  await AnalyticsService.updateLectureStatus(
                                    log: log,
                                    division: widget.division,
                                    newStatus: 'rescheduled',
                                    markedBy: 'Subject Rep',
                                    markedByUid: currentUid,
                                    actualSubject: subj.subject,
                                    actualComponent: subj.component,
                                    actualBatch: subj.batch,
                                    actualCategory: EventCategory.academic,
                                  );
                                  if (!context.mounted) return;
                                  AppDialogs.showSnackBar(
                                    context: context,
                                    message: 'Marked as Rescheduled to ${subj.subject} ${subj.component}',
                                  );
                                },
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                                child: Text('${subj.subject} ${subj.component} (${batchNames[subj.batch] ?? subj.batch})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject} Dashboard'),
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('sections').doc(widget.division).snapshots(),
        builder: (context, sectionSnapshot) {
          Map<String, String> batchNames = {};
          if (sectionSnapshot.hasData && sectionSnapshot.data!.exists) {
            final data = sectionSnapshot.data!.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('batchNames')) {
              batchNames = Map<String, String>.from(data['batchNames'] as Map);
            }
          }

          return StreamBuilder<List<ConductLog>>(
            stream: _pendingLogsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
          }

          final logs = snapshot.data ?? [];

          WidgetsBinding.instance.addPostFrameCallback((_) {
            LocalNotificationService.schedulePendingReminder(logs.length);
          });

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.x2l),
                    decoration: BoxDecoration(
                      color: Theme.of(context).extension<AppSemanticColors>()!.conducted.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.done_all_rounded,
                      size: 48,
                      color: Theme.of(context).extension<AppSemanticColors>()!.conducted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2l),
                  Text(
                    'All Caught Up!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No pending lectures to verify.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          final groupedLogs = <String, List<ConductLog>>{};
          for (var log in logs) {
            groupedLogs.putIfAbsent(log.date, () => []).add(log);
          }

          final sortedDates = groupedLogs.keys.toList()..sort();

          return ListView.builder(
            padding: EdgeInsets.all(AppSpacing.x2l),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateStr = sortedDates[index];
              final dateLogs = groupedLogs[dateStr]!;

              DateTime? parsedDate;
              try {
                final parts = dateStr.split('-');
                parsedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
              } catch (_) {}

              final displayDate = parsedDate != null ? _dateFormat.format(parsedDate) : dateStr;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      displayDate,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  ...dateLogs.asMap().entries.map((e) => _buildLogCard(e.value, batchNames, isFirst: index == 0 && e.key == 0)),
                  const SizedBox(height: AppSpacing.lg),
                ],
              );
            },
          );
        },
      );
      },
      ),
    );
  }

  Widget _buildLogCard(ConductLog log, Map<String, String> batchNames, {bool isFirst = false}) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Check if the log is older than 1 day (warning state)
    DateTime? parsedDate;
    try {
      final parts = log.date.split('-');
      parsedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {}
    
    final isWarning = parsedDate != null && DateTime.now().difference(parsedDate).inDays > 1;

    Widget card = SchedlyCard(
      variant: isWarning ? SchedlyCardVariant.tinted : SchedlyCardVariant.elevated,
      padding: EdgeInsets.zero,
      onTap: () => _showMarkingSheet(log, batchNames),
      child: Container(
        decoration: isWarning 
            ? BoxDecoration(
                border: Border(left: BorderSide(color: sem.error, width: 4)),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              )
            : null,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isWarning ? sem.error.withValues(alpha: 0.1) : sem.pending.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                isWarning ? Icons.warning_rounded : Icons.pending_actions_rounded,
                color: isWarning ? sem.error : sem.pending,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.originalSlot.displaySubject} (${batchNames[log.originalSlot.batch] ?? log.originalSlot.batch})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: sem.onSurfaceMuted),
                      const SizedBox(width: 4),
                      Text(
                        TimetableManager.formatTime(log.originalSlot.startTime, log.originalSlot.endTime),
                        style: TextStyle(fontSize: 13, color: sem.onSurfaceMuted),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Icon(Icons.room_rounded, size: 12, color: sem.onSurfaceMuted),
                      const SizedBox(width: 4),
                      Text(
                        log.originalSlot.room ?? 'TBD',
                        style: TextStyle(fontSize: 13, color: sem.onSurfaceMuted),
                      ),
                    ],
                  ),
                  if (isWarning) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Action overdue',
                      style: TextStyle(fontSize: 12, color: sem.error, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: sem.onSurfaceFaint,
            ),
          ],
        ),
      ),
    );

    if (isFirst) {
      return TutorialTarget(
        id: 'verify_lecture_btn',
        child: card,
      );
    }
    return card;
  }
}
