import 'package:flutter/material.dart';
import 'package:schedly/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_notification_service.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'services/network_service.dart';


import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/schedly_card.dart';
import 'widgets/schedly_text_field.dart';

class CreateAnnouncementPage extends StatefulWidget {
  const CreateAnnouncementPage({
    super.key,
  });

  @override
  State<CreateAnnouncementPage>
      createState() =>
          _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState
    extends State<CreateAnnouncementPage> {
  final titleController =
      TextEditingController();

  final messageController =
      TextEditingController();

  String priority = 'Normal';
  bool _isPublishing = false;
  final Set<String> _selectedDivisions = {};

  @override
  void initState() {
    super.initState();
    if (AppSettings.currentRole != UserRole.faculty) {
      _loadCRDivision();
    }
  }
  
  Future<void> _loadCRDivision() async {
    final prefs = await SharedPreferences.getInstance();
    final sectionId = prefs.getString('section_id') ?? prefs.getString('selected_division');
    if (sectionId != null && mounted) {
      setState(() => _selectedDivisions.add(sectionId));
    }
    
    final draftTitle = prefs.getString('draft_announcement_title');
    final draftMessage = prefs.getString('draft_announcement_message');
    if (draftTitle != null && draftMessage != null && mounted) {
      titleController.text = draftTitle;
      messageController.text = draftMessage;
      
      prefs.remove('draft_announcement_title');
      prefs.remove('draft_announcement_message');
      
      AppDialogs.showSnackBar(
        context: context,
        message: 'Draft restored.',
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    try {
      if (titleController.text.isEmpty ||
          messageController.text.isEmpty) {
        return;
      }

      final isOnline = await NetworkService.isOnline();
      if (!isOnline) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('draft_announcement_title', titleController.text);
        await prefs.setString('draft_announcement_message', messageController.text);
        
        if (mounted) {
          AppDialogs.showError(
            context: context,
            title: 'Network Required',
            message: 'You are offline. Your draft has been saved locally. Please try publishing again when online.',
          );
        }
        return;
      }

      if (_selectedDivisions.isEmpty) {
        AppDialogs.showSnackBar(
          context: context,
          message: 'Select at least one division',
        );
        return;
      }

      setState(() => _isPublishing = true);

      for (final sectionId in _selectedDivisions) {
        await AppNotificationService.dispatch(
          title: titleController.text,
          message: messageController.text,
          priority: priority,
          division: sectionId,
          type: 'announcement',
        );
      }
      if (!mounted) return;

      AppDialogs.showSnackBar(
        context: context,
        message: 'Announcement published successfully',
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('ANNOUNCEMENT ERROR: $e');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Announcement', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20)),
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchedlyCard(
              variant: SchedlyCardVariant.elevated,
              padding: const EdgeInsets.all(AppSpacing.x2l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Announcement Details',
                    style: TextStyle(fontFamily: 'Outfit', 
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'This will be sent as a push notification to all students in the selected divisions.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: sem.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2l),

                  SchedlyTextField(
                    controller: titleController,
                    labelText: 'Title',
                    hintText: 'e.g. Extra Class Tomorrow',
                    prefixIcon: Icons.title_rounded,
                    maxLength: 50,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SchedlyTextField(
                    controller: messageController,
                    labelText: 'Message',
                    hintText: 'Provide details about the announcement...',
                    prefixIcon: Icons.message_rounded,
                    maxLines: 5,
                    minLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      prefixIcon: Icon(Icons.priority_high_rounded, color: sem.onSurfaceMuted, size: 20),
                      fillColor: sem.surfaceElevated2,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: sem.borderFocus, width: 1.5),
                      ),
                      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: sem.onSurfaceMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    ),
                    icon: Icon(Icons.expand_more_rounded, color: sem.onSurfaceMuted),
                    dropdownColor: isDark ? sem.surfaceElevated : Theme.of(context).colorScheme.surface,
                    items: ['Low', 'Normal', 'High'].map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          priority = value;
                        });
                      }
                    },
                  ),

                  if (AppSettings.currentRole == UserRole.faculty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Target Divisions',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14, color: sem.onSurfaceMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: (AppSettings.facultyAssignedDivisions ?? []).map((div) {
                        final isSelected = _selectedDivisions.contains(div);
                        return FilterChip(
                          label: Text(div.replaceAll('_', ' ')),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) _selectedDivisions.add(div);
                              else _selectedDivisions.remove(div);
                            });
                          },
                          backgroundColor: sem.surfaceElevated2,
                          selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          checkmarkColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Theme.of(context).colorScheme.primary : sem.onSurfaceMuted,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            side: BorderSide(
                              color: isSelected ? Theme.of(context).colorScheme.primary : sem.borderSubtle,
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x3l),
            SizedBox(
              height: 56,
              child: AnimatedButton(
                onPressed: _isPublishing ? null : _publish,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                child: _isPublishing 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Publish Announcement', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
