import 'package:flutter/material.dart';
import 'package:schedly/services/feedback_service.dart';
import 'package:schedly/theme/theme.dart';

class FeatureRequestSheet extends StatefulWidget {
  const FeatureRequestSheet({super.key});

  @override
  State<FeatureRequestSheet> createState() => _FeatureRequestSheetState();
}

class _FeatureRequestSheetState extends State<FeatureRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackService = FeedbackService();

  String _category = 'General';
  String _title = '';
  String _description = '';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Timetable',
    'Attendance',
    'Analytics',
    'Faculty',
    'Student',
    'Notifications',
    'General',
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    try {
      await _feedbackService.submitFeatureRequest(
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
              Text('Failed to submit suggestion. Saved offline.'),
            ],
          ),
          backgroundColor: Theme.of(
            context,
          ).extension<AppSemanticColors>()?.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Still close the sheet since the data is saved offline
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

    // Support Web / Tablets by constraining width
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600
        ? (screenWidth - 500) / 2
        : AppSpacing.lg;

    return Container(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x4l,
      ),
      decoration: BoxDecoration(
        color: isDark ? semanticColors.surfaceElevated2 : colorScheme.surface,
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
                    color: semanticColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Suggest a Feature',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Category
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Brief summary of the feature',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a title'
                    : null,
                onSaved: (val) => _title = val!.trim(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Description
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'How would this feature help you?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a description'
                    : null,
                onSaved: (val) => _description = val!.trim(),
              ),
              const SizedBox(height: AppSpacing.x2l),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Suggestion',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
