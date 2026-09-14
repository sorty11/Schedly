import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/assignment_submission.dart';
import '../../services/assignment_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_dialogs.dart';

class AssignmentReminderSettingsSheet extends StatefulWidget {
  const AssignmentReminderSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AssignmentReminderSettingsSheet(),
    );
  }

  @override
  State<AssignmentReminderSettingsSheet> createState() =>
      _AssignmentReminderSettingsSheetState();
}

class _AssignmentReminderSettingsSheetState
    extends State<AssignmentReminderSettingsSheet> {
  bool _isLoading = true;
  AssignmentReminderPreference _pref = const AssignmentReminderPreference();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pref = await AssignmentService.loadReminderPreferences();
    if (mounted) {
      setState(() {
        _pref = pref;
        _isLoading = false;
      });
    }
  }

  Future<void> _update(AssignmentReminderPreference newPref) async {
    setState(() => _pref = newPref);
    await AssignmentService.saveReminderPreferences(newPref);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<AppSemanticColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x2l,
        AppSpacing.lg,
        AppSpacing.x2l,
        AppSpacing.x2l,
      ),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated2 : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.x2l),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sem.borderSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Deadline Reminders',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose when you want to receive push notifications for active deadlines.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: sem.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.x2l),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _buildToggleTile(
                title: '24 Hours Before',
                subtitle: 'Day-before heads up for upcoming assignments',
                value: _pref.remind24h,
                onChanged: (val) => _update(_pref.copyWith(remind24h: val)),
                theme: theme,
                sem: sem,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildToggleTile(
                title: '6 Hours Before',
                subtitle: 'Mid-day reminder before final evening deadline',
                value: _pref.remind6h,
                onChanged: (val) => _update(_pref.copyWith(remind6h: val)),
                theme: theme,
                sem: sem,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildToggleTile(
                title: '1 Hour Before',
                subtitle: 'Urgent final warning before deadline closes',
                value: _pref.remind1h,
                onChanged: (val) => _update(_pref.copyWith(remind1h: val)),
                theme: theme,
                sem: sem,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
    required AppSemanticColors sem,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: sem.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: sem.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: sem.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
