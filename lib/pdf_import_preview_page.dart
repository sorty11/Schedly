import 'package:flutter/material.dart';
import 'services/pdf_timetable_import_service.dart';
import 'models/timetable_entry.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/schedly_card.dart';

class PdfImportPreviewPage extends StatelessWidget {
  final Map<String, List<TimetableEntry>> timetable;
  final String division;

  const PdfImportPreviewPage({
    super.key,
    required this.timetable,
    required this.division,
  });

  Future<void> _importTimetable(BuildContext context) async {
    try {
      await PdfTimetableImportService.saveImportedTimetable(
        division: division,
        timetable: timetable,
      );

      if (!context.mounted) return;

      AppDialogs.showSnackBar(
        context: context,
        message: 'Timetable Imported Successfully',
      );

      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Import Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = timetable.keys.toList();
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Data'),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          SchedlyCard(
            variant: SchedlyCardVariant.elevated,
            margin: const EdgeInsets.all(AppSpacing.x2l),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: sem.conducted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.verified_rounded, color: sem.conducted),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data extracted successfully',
                        style: TextStyle(fontFamily: 'Inter', 
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Target Division: $division',
                        style: TextStyle(fontFamily: 'Inter', 
                          color: sem.onSurfaceMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final lectures = timetable[day]!;

                if (lectures.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2l),
                  child: SchedlyCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            day,
                            style: TextStyle(fontFamily: 'Outfit', 
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Divider(height: 1, color: sem.borderSubtle),
                        ...lectures.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Icon(Icons.book_rounded, color: colorScheme.primary, size: 20),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.displaySubject} (${entry.batch})',
                                        style: TextStyle(fontFamily: 'Inter', 
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Wrap(
                                        spacing: AppSpacing.md,
                                        runSpacing: AppSpacing.xs,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.access_time_rounded, size: 14, color: sem.onSurfaceMuted),
                                              const SizedBox(width: AppSpacing.xs),
                                              Text(
                                                TimetableManager.formatTime(entry.startTime, entry.endTime),
                                                style: TextStyle(fontFamily: 'Inter', color: sem.onSurfaceMuted, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.room_rounded, size: 14, color: sem.onSurfaceMuted),
                                              const SizedBox(width: AppSpacing.xs),
                                              Text(
                                                entry.room ?? '',
                                                style: TextStyle(fontFamily: 'Inter', color: sem.onSurfaceMuted, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(AppRadius.xs),
                                            ),
                                            child: Text(
                                              entry.category.name,
                                              style: TextStyle(fontFamily: 'Inter', 
                                                color: colorScheme.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: sem.borderSubtle)),
        ),
        child: SizedBox(
          height: 56,
          child: AnimatedButton(
            onPressed: () => _importTimetable(context),
            backgroundColor: sem.conducted,
            foregroundColor: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Confirm & Import Timetable',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
