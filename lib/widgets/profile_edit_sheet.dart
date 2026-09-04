import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/profile_service.dart';
import '../theme/theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/schedly_bottom_sheet.dart';
import '../widgets/schedly_text_field.dart';

/// Modal bottom sheet for editing user profile information (Name and SAP ID).
class ProfileEditSheet extends StatefulWidget {
  final String currentName;
  final String currentSapId;
  final bool isFaculty;

  const ProfileEditSheet({
    super.key,
    required this.currentName,
    required this.currentSapId,
    required this.isFaculty,
  });

  /// Displays the edit sheet as a modal bottom sheet.
  /// Returns `true` if changes were saved successfully.
  static Future<bool?> show(
    BuildContext context, {
    required String currentName,
    required String currentSapId,
    required bool isFaculty,
  }) {
    return SchedlyBottomSheet.show<bool>(
      context,
      title: 'Edit Profile',
      subtitle: 'Update your display name and university SAP ID',
      child: ProfileEditSheet(
        currentName: currentName,
        currentSapId: currentSapId,
        isFaculty: isFaculty,
      ),
    );
  }

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _sapIdController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _sapIdController = TextEditingController(text: widget.currentSapId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sapIdController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final trimmedName = _nameController.text.trim();
    final trimmedSapId = _sapIdController.text.trim();

    // Check if nothing changed
    if (trimmedName == widget.currentName.trim() &&
        trimmedSapId.toUpperCase() == widget.currentSapId.trim().toUpperCase()) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ProfileService.updateProfileInfo(
        name: trimmedName,
        sapId: trimmedSapId,
        isFaculty: widget.isFaculty,
      );

      if (!mounted) return;
      AppDialogs.showSnackBar(
        context: context,
        message: 'Profile updated successfully.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final cleanMessage = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('AppException: ', '');
      setState(() {
        _errorMessage = cleanMessage;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>()!;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error alert container if any
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: sem.cancelled.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: sem.cancelled.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: sem.cancelled,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: sem.cancelled,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Name field
          Text(
            'Full Name',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SchedlyTextField(
            controller: _nameController,
            hintText: 'Enter your full name',
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: ProfileService.validateName,
          ),
          const SizedBox(height: AppSpacing.lg),

          // SAP ID field
          Text(
            widget.isFaculty
                ? 'Faculty SAP ID / Employee ID'
                : 'SAP ID / Roll Number',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SchedlyTextField(
            controller: _sapIdController,
            hintText: widget.isFaculty
                ? 'e.g. 70022500123 or FAC01'
                : 'e.g. 70022500123 or A137',
            prefixIcon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.characters,
            validator: ProfileService.validateSapId,
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    side: BorderSide(
                      color: sem.borderSubtle,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
