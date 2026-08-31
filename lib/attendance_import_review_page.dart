import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'models/attendance_import_models.dart';
import 'services/attendance_parser.dart';
import 'services/attendance_status_mapper.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/beta_badge.dart';
import 'widgets/schedly_card.dart';

class AttendanceImportReviewPage extends StatefulWidget {
  final AttendanceImportPreview preview;
  final String division;

  const AttendanceImportReviewPage({
    super.key,
    required this.preview,
    required this.division,
  });

  @override
  State<AttendanceImportReviewPage> createState() =>
      _AttendanceImportReviewPageState();
}

class _AttendanceImportReviewPageState
    extends State<AttendanceImportReviewPage> {
  bool _isImporting = false;

  Future<void> _commitImport() async {
    setState(() => _isImporting = true);
    try {
      final result = await AttendanceParserService.commitPreview(
        division: widget.division,
        preview: widget.preview,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Import Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final meta = preview.metadata;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Attendance Import'),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.x2l),
              children: [
                Row(
                  children: [
                    Text(
                      'Official Report Import',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const BetaBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Data comes from your uploaded institutional report — not verified by Schedly.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: sem.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                SchedlyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Student', meta.studentName),
                      _infoRow('Student Number', meta.studentNumber),
                      _infoRow('Roll No.', meta.rollNo),
                      _infoRow('Program', meta.programName),
                      _infoRow(
                        'Academic Year',
                        '${meta.academicYear}${meta.academicSession.isNotEmpty ? ', ${meta.academicSession}' : ''}',
                      ),
                      if (meta.reportStartDate != null ||
                          meta.reportEndDate != null)
                        _infoRow(
                          'Report Duration',
                          '${meta.reportStartDate != null ? dateFmt.format(meta.reportStartDate!) : '?'} → ${meta.reportEndDate != null ? dateFmt.format(meta.reportEndDate!) : '?'}',
                        ),
                      _infoRow('Pages Parsed', '${preview.totalPagesParsed}'),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Summary',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SchedlyCard(
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _statChip('Records Found', '${preview.totalRows}', sem),
                      _statChip(
                        'New Records',
                        '${preview.newCount}',
                        sem,
                        color: sem.conducted,
                      ),
                      _statChip(
                        'Updated Records',
                        '${preview.updateCount}',
                        sem,
                      ),
                      _statChip(
                        'Duplicates Skipped',
                        '${preview.duplicateCount}',
                        sem,
                      ),
                      _statChip(
                        'Present',
                        '${preview.presentCount}',
                        sem,
                        color: sem.conducted,
                      ),
                      _statChip(
                        'Absent',
                        '${preview.absentCount}',
                        sem,
                        color: sem.cancelled,
                      ),
                      _statChip('Exemption', '${preview.exemptionCount}', sem),
                      _statChip(
                        'Late Admission',
                        '${preview.lateAdmissionCount}',
                        sem,
                      ),
                      _statChip(
                        'Not Updated',
                        '${preview.notUpdatedCount}',
                        sem,
                        color: sem.warning,
                      ),
                      _statChip(
                        'Unresolved Courses',
                        '${preview.unmatchedCourseCount}',
                        sem,
                        color: preview.unmatchedCourseCount > 0
                            ? sem.warning
                            : null,
                      ),
                      if (preview.warnings.isNotEmpty)
                        _statChip(
                          'Warnings',
                          '${preview.warnings.length}',
                          sem,
                          color: sem.warning,
                        ),
                    ],
                  ),
                ),

                if (preview.errors.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SchedlyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: sem.cancelled),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Errors',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: sem.cancelled,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...preview.errors.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              e,
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (preview.warnings.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SchedlyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: sem.warning,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Warnings',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: sem.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...preview.warnings
                            .take(10)
                            .map(
                              (w) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  w,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                            ),
                        if (preview.warnings.length > 10)
                          Text(
                            '…and ${preview.warnings.length - 10} more',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: sem.onSurfaceMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                if (preview.unresolvedRows.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Unresolved Courses (${preview.unresolvedRows.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...preview.unresolvedRows
                      .take(8)
                      .map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            '• ${row.rawCourseName} — ${AttendanceStatusMapper.displayLabel(row.normalizedStatus)}',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(AppSpacing.x2l),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(top: BorderSide(color: sem.borderSubtle)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: AnimatedButton(
                onPressed: preview.canImport && !_isImporting
                    ? _commitImport
                    : null,
                backgroundColor: sem.conducted,
                foregroundColor: Colors.white,
                child: _isImporting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.upload_file_rounded),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Import Attendance',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: sem.onSurfaceMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(
    String label,
    String value,
    AppSemanticColors sem, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (color ?? sem.onSurfaceMuted).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (color ?? sem.borderSubtle).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: sem.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
