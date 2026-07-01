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
  final _dateFormat = DateFormat('EEEE, MMM d, yyyy');

  void _showMarkingSheet(ConductLog log) {
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
                const SizedBox(height: 8),
                Text(
                  '${log.originalSlot.displaySubject} (${log.originalSlot.batch})\n${log.date} at ${TimetableManager.formatTime(log.originalSlot.startTime, log.originalSlot.endTime)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildOptionBtn(context, log, 'conducted', 'Conducted', Icons.check_circle_rounded, Theme.of(context).extension<AppSemanticColors>()!.conducted),
                const SizedBox(height: 12),
                _buildOptionBtn(context, log, 'cancelled', 'Cancelled', Icons.cancel_rounded, Theme.of(context).extension<AppSemanticColors>()!.cancelled),
                const SizedBox(height: 12),
                _buildOptionBtn(context, log, 'rescheduled', 'Rescheduled', Icons.schedule_rounded, Theme.of(context).extension<AppSemanticColors>()!.rescheduled),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionBtn(BuildContext context, ConductLog log, String statusCode, String statusLabel, IconData icon, Color color) {
    return AnimatedButton(
      onPressed: () async {
        Navigator.pop(context);
        
        if (statusCode == 'rescheduled') {
          _showSubjectSelectionSheet(log);
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
          const SizedBox(width: 8),
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

  void _showSubjectSelectionSheet(ConductLog log) {
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
                    const SizedBox(height: 8),
                    Text(
                      'Which subject was taught instead of ${log.originalSlot.subject}?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
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
                                child: Text('${subj.subject} ${subj.component} (${subj.batch})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      body: StreamBuilder<List<ConductLog>>(
        stream: AnalyticsService.streamPendingLogs(widget.division, widget.subject, null, null),
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
                  const SizedBox(height: 24),
                  Text(
                    'All Caught Up!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  ...dateLogs.asMap().entries.map((e) => _buildLogCard(e.value, isFirst: index == 0 && e.key == 0)),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLogCard(ConductLog log, {bool isFirst = false}) {
    Widget card = AnimatedCard(
      onTap: () => _showMarkingSheet(log),
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      borderRadius: 20,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [

              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).extension<AppSemanticColors>()!.pending.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  color: Theme.of(context).extension<AppSemanticColors>()!.pending,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.originalSlot.displaySubject} (${log.originalSlot.batch})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          TimetableManager.formatTime(log.originalSlot.startTime, log.originalSlot.endTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.room_rounded, size: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          log.originalSlot.room ?? 'TBD',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              ),
            ],
          ),
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
