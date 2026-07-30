import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/attendance_log.dart';
import 'services/attendance_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';

class PdfAttendancePreviewPage extends StatefulWidget {
  final List<AttendanceLog> logs;
  final String division;

  const PdfAttendancePreviewPage({
    super.key,
    required this.logs,
    required this.division,
  });

  @override
  State<PdfAttendancePreviewPage> createState() => _PdfAttendancePreviewPageState();
}

class _PdfAttendancePreviewPageState extends State<PdfAttendancePreviewPage> {
  bool _isImporting = false;
  late final int _perfectMatches;
  late final int _normalizedMatches;
  late final int _fuzzyMatches;
  late final int _unmatched;

  @override
  void initState() {
    super.initState();
    _perfectMatches = widget.logs.where((l) => l.confidence == MatchConfidence.perfect).length;
    _normalizedMatches = widget.logs.where((l) => l.confidence == MatchConfidence.normalized).length;
    _fuzzyMatches = widget.logs.where((l) => l.confidence == MatchConfidence.fuzzy).length;
    _unmatched = widget.logs.where((l) => l.confidence == MatchConfidence.unmatched).length;
  }

  Future<void> _importAttendance() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    
    try {
      final result = await AttendanceService.batchImportAttendance(
        division: widget.division,
        logs: widget.logs,
      );

      if (!mounted) return;

      AppDialogs.showSnackBar(
        context: context,
        message: "Imported \${result['new']} new records. (\${result['duplicates']} duplicates ignored)",
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
    final total = widget.logs.length;
    final hasWarnings = _fuzzyMatches > 0 || _unmatched > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Import Preview'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        children: [
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
                  '\$total Lectures Found',
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Target Division: \${widget.division}',
                  style: TextStyle(color: sem.onSurfaceMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          
          Text('Confidence Engine Report', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          
          _StatRow(label: 'Perfect Matches', count: _perfectMatches, color: sem.conducted, icon: Icons.check_circle_rounded),
          _StatRow(label: 'Normalized Matches', count: _normalizedMatches, color: sem.conducted, icon: Icons.auto_fix_high_rounded),
          _StatRow(label: 'Fuzzy Matches (Review recommended)', count: _fuzzyMatches, color: sem.warning, icon: Icons.warning_rounded),
          _StatRow(label: 'Unmatched (Will be recorded as new)', count: _unmatched, color: sem.cancelled, icon: Icons.error_rounded),
          
          if (hasWarnings) ...[
            const SizedBox(height: AppSpacing.x2l),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: sem.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: sem.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: sem.warning, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Some subjects were not perfectly matched. They will still be imported, but you should verify their names match your timetable exactly to get full analytics.',
                      style: TextStyle(color: sem.warning, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x2l),
          child: AnimatedButton(
            onPressed: _isImporting ? () {} : _importAttendance,
            backgroundColor: sem.conducted,
            foregroundColor: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isImporting)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else
                  const Icon(Icons.cloud_upload_rounded),
                const SizedBox(width: 8),
                Text(_isImporting ? 'Merging Data...' : 'Confirm & Merge Attendance', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatRow({required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
