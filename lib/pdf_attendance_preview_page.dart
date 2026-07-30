import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/attendance_log.dart';
import 'services/attendance_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';
import 'services/pdf_attendance_import_service.dart';

class PdfAttendancePreviewPage extends StatefulWidget {
  final PdfImportResult importResult;
  final String division;

  const PdfAttendancePreviewPage({
    super.key,
    required this.importResult,
    required this.division,
  });

  @override
  State<PdfAttendancePreviewPage> createState() => _PdfAttendancePreviewPageState();
}

class _PdfAttendancePreviewPageState extends State<PdfAttendancePreviewPage> {
  bool _isImporting = false;

  Future<void> _importAttendance() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    
    try {
      final result = await AttendanceService.batchImportAttendance(
        division: widget.division,
        logs: widget.importResult.logs,
      );

      if (!mounted) return;

      AppDialogs.showSnackBar(
        context: context,
        message: "Imported ${result['new']} new records. (${result['duplicates']} duplicates ignored)",
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Import Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final total = widget.importResult.logs.length;
    final skipped = widget.importResult.skippedCount;
    final warnings = widget.importResult.warnings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Import Preview'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        children: [
          // BETA Warning Label
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xl),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: sem.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: sem.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.science, color: sem.warning, size: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BETA FEATURE',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: sem.warning),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PDF Import is in Beta. Please verify imported attendance before relying on analytics.',
                        style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(AppSpacing.x2l),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.analytics_rounded, size: 48, color: sem.conducted),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$total Lectures Found',
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                if (skipped > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$skipped Malformed Rows Skipped',
                    style: GoogleFonts.inter(fontSize: 14, color: sem.warning, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          if (widget.importResult.studentInfo != null) ...[
            Text('Student Identity Found', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border.all(color: sem.borderSubtle),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Name', value: widget.importResult.studentInfo!.name),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Roll No', value: widget.importResult.studentInfo!.rollNumber),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Program', value: widget.importResult.studentInfo!.program),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
          ],

          if (warnings.isNotEmpty) ...[
            Text('Parsing Warnings', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border.all(color: sem.warning.withValues(alpha: 0.3)),
                color: sem.warning.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: warnings.take(5).map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: sem.warning),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(w, style: GoogleFonts.inter(fontSize: 13, color: sem.onSurfaceMuted))),
                    ],
                  ),
                )).toList()
                ..addAll(warnings.length > 5 ? [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text('...and ${warnings.length - 5} more warnings.', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: sem.onSurfaceMuted)),
                  )
                ] : []),
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x2l),
          child: AnimatedButton(
            onPressed: _importAttendance,
            isLoading: _isImporting,
            child: const Text('Confirm Import'),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  
  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: sem.onSurfaceMuted, fontSize: 14)),
        Text(value, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
