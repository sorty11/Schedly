import 'package:flutter/material.dart';

import 'announcement_manager.dart';
import 'models/announcement.dart';

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
    extends State<
        CreateAnnouncementPage> {
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

  void _publish() {
    if (titleController.text.isEmpty ||
        messageController.text.isEmpty) {
      return;
    }

    AnnouncementManager
        .announcements
        .insert(
      0,
      Announcement(
        id: DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
        title:
            titleController.text,
        message:
            messageController.text,
        priority: priority,
        createdAt:
            DateTime.now(),
      ),
    );

    Navigator.pop(context);
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