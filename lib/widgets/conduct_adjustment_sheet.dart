import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme.dart';
import '../models/batch_analytics.dart';
import '../models/conduct_adjustment.dart';
import '../services/analytics_service.dart';
import '../app_settings.dart';

class ConductAdjustmentSheet extends StatefulWidget {
  final SubjectAnalytics subject;

  const ConductAdjustmentSheet({super.key, required this.subject});

  @override
  State<ConductAdjustmentSheet> createState() => _ConductAdjustmentSheetState();
}

class _ConductAdjustmentSheetState extends State<ConductAdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  String _selectedBatch = '';
  final _hoursController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.subject.batches.isNotEmpty) {
      _selectedBatch = widget.subject.batches.first.batch;
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final hours = int.parse(_hoursController.text);
      final user = FirebaseAuth.instance.currentUser;

      final batchData = widget.subject.batches.firstWhere(
        (b) => b.batch == _selectedBatch,
      );

      await AnalyticsService.addConductAdjustment(
        division: AppSettings.sectionId ?? AppSettings.division ?? '',
        subject: batchData.subject,
        component: batchData.component,
        batch: _selectedBatch,
        adjustmentHours: hours,
        reason: _reasonController.text.trim(),
        createdBy: user?.displayName ?? 'CR',
        createdByUid: user?.uid ?? '',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adjustment recorded successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Adjust Conducted Hours',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Manually add or subtract hours. This will directly affect the "Adjusted" stat without altering historical logs.',
              style: TextStyle(color: sem.onSurfaceMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (widget.subject.batches.length > 1) ...[
              DropdownButtonFormField<String>(
                value: _selectedBatch,
                decoration: InputDecoration(
                  labelText: 'Batch',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                items: widget.subject.batches
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.batch,
                        child: Text(b.batch),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedBatch = v!),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            TextFormField(
              controller: _hoursController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: 'Hours (e.g. 2, -1)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter hours';
                if (int.tryParse(v) == null) return 'Must be a valid integer';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Adjustment',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Adjustment History',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (widget.subject.batches.isNotEmpty)
              StreamBuilder<List<ConductAdjustment>>(
                stream: AnalyticsService.streamAdjustmentsForSubject(
                  division: AppSettings.sectionId ?? AppSettings.division ?? '',
                  subject: widget.subject.batches
                      .firstWhere((b) => b.batch == _selectedBatch)
                      .subject,
                  component: widget.subject.batches
                      .firstWhere((b) => b.batch == _selectedBatch)
                      .component,
                  batch: _selectedBatch,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data ?? [];
                  if (docs.isEmpty) {
                    return Text(
                      'No adjustments recorded yet.',
                      style: TextStyle(color: sem.onSurfaceMuted, fontSize: 13),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final adj = docs[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${adj.adjustmentHours > 0 ? '+' : ''}${adj.adjustmentHours} hours',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${adj.reason.isNotEmpty ? adj.reason : 'No reason'} • ${adj.createdBy}',
                          style: TextStyle(
                            fontSize: 12,
                            color: sem.onSurfaceMuted,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

void showConductAdjustmentSheet(
  BuildContext context,
  SubjectAnalytics subject,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) => ConductAdjustmentSheet(subject: subject),
  );
}
