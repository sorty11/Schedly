import 'package:flutter/material.dart';
import 'package:schedly/services/feedback_service.dart';
import 'package:schedly/theme/theme.dart';

class OtherFeedbackSheet extends StatefulWidget {
  const OtherFeedbackSheet({super.key});

  @override
  State<OtherFeedbackSheet> createState() => _OtherFeedbackSheetState();
}

class _OtherFeedbackSheetState extends State<OtherFeedbackSheet> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackService = FeedbackService();

  String _category = 'General';
  String _title = '';
  String _description = '';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'General',
    'Experience',
    'Timetable & Attendance',
    'UI & Animations',
    'Faculty / CR Workflow',
    'Other',
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    try {
      await _feedbackService.submitGeneralFeedback(
        category: _category,
        title: _title,
        description: _description,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Text('Thanks! Your feedback has been submitted.'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Text('Failed to submit feedback. Saved offline.'),
            ],
          ),
          backgroundColor: Theme.of(
            context,
          ).extension<AppSemanticColors>()?.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600
        ? (screenWidth - 500) / 2
        : AppSpacing.lg;

    return Container(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: semanticColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: semanticColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'General Feedback',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Tell us what you think or how we can improve',
                          style: TextStyle(
                            fontSize: 13,
                            color: semanticColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Topic / Title',
                  hintText: 'Brief summary of your feedback',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
                onSaved: (val) => _title = val!.trim(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Details',
                  hintText: 'Share your thoughts, suggestions, or comments...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                maxLines: 4,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter your feedback'
                    : null,
                onSaved: (val) => _description = val!.trim(),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
