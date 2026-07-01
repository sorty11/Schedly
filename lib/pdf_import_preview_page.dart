import 'package:flutter/material.dart';
import 'services/pdf_timetable_import_service.dart';
import 'models/timetable_entry.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';

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
        message: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = timetable.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Data'),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).extension<AppSemanticColors>()!.conducted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.verified_rounded, color: Theme.of(context).extension<AppSemanticColors>()!.conducted),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data extracted successfully',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target Division: $division',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final lectures = timetable[day]!;

                if (lectures.isEmpty) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                      ...lectures.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.book_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.displaySubject} (${entry.batch})',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.access_time_rounded, size: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                                            const SizedBox(width: 4),
                                            Text(TimetableManager.formatTime(entry.startTime, entry.endTime), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.room_rounded, size: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                                            const SizedBox(width: 4),
                                            Text(entry.room ?? '', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                                          ],
                                        ),
                                        Text(entry.category.name, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
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
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 56,
          child: AnimatedButton(
            onPressed: () => _importTimetable(context),
            backgroundColor: Theme.of(context).extension<AppSemanticColors>()!.conducted,
            foregroundColor: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded),
                const SizedBox(width: 8),
                const Text('Confirm & Import Timetable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}