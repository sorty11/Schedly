import 'package:flutter/material.dart';
import 'package:schedly/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_notification_service.dart';
import 'services/announcement_service.dart';

import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';

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

      final prefs = await SharedPreferences.getInstance();

      final sectionId = prefs.getString('section_id') ?? prefs.getString('selected_division');

      if (sectionId == null) {
        return;
      }

      await AnnouncementService.createAnnouncement(
        title: titleController.text,
        message: messageController.text,
        priority: priority,
        sectionId: sectionId,
      );
      await AppNotificationService.createNotification(
        title: 'New Announcement',
        message: messageController.text,
        division: sectionId,
        type: 'announcement',
      );
      if (!mounted) return;

      AppDialogs.showSnackBar(
        context: context,
        message: 'Announcement published for $sectionId',
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('ANNOUNCEMENT ERROR: $e');
    }
  }
  InputDecoration _modernDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Announcement'),
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.x2l),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.05), width: 1.5),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                    decoration: _modernDecoration('Title', Icons.title_rounded),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: _modernDecoration('Message', Icons.message_rounded).copyWith(
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: _modernDecoration('Priority', Icons.priority_high_rounded),
                    icon: Icon(Icons.expand_more_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
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
                ],
              ),
            ),
            const SizedBox(height: 32),
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
                        const SizedBox(width: 8),
                        const Text('Publish Announcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
