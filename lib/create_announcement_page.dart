import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_notification_service.dart';
import 'services/announcement_service.dart';

class CreateAnnouncementPage
    extends StatefulWidget {
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

      final division = prefs.getString('selected_division');

      if (division == null) {
        return;
      }

      await AnnouncementService.createAnnouncement(
        title: titleController.text,
        message: messageController.text,
        priority: priority,
        division: division,
      );
       print('CREATING ANNOUNCEMENT NOTIFICATION');
      await AppNotificationService.createNotification(
        title: 'New Announcement',
        message: messageController.text,
        division: division,
        type: 'announcement',
      );print('ANNOUNCEMENT NOTIFICATION CREATED');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Announcement published for $division',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('ANNOUNCEMENT ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Announcement',
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller:
                  titleController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Title',
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            TextField(
              controller:
                  messageController,
              maxLines: 4,
              decoration:
                  const InputDecoration(
                labelText:
                    'Message',
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            DropdownButtonFormField<
                String>(
              value: priority,
              items: const [
                DropdownMenuItem(
                  value: 'Low',
                  child: Text(
                    'Low',
                  ),
                ),
                DropdownMenuItem(
                  value: 'Normal',
                  child: Text(
                    'Normal',
                  ),
                ),
                DropdownMenuItem(
                  value: 'High',
                  child: Text(
                    'High',
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    priority =
                        value;
                  });
                }
              },
            ),

            const SizedBox(
              height: 24,
            ),

            SizedBox(
              width:
                  double.infinity,
              child: ElevatedButton(
                onPressed:
                    _publish,
                child: const Text(
                  'Publish',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
