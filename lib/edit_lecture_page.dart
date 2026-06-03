import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'user_roles.dart';

class EditLecturePage extends StatefulWidget {
  final Map<String, String> lecture;

  const EditLecturePage({
    super.key,
    required this.lecture,
  });

  @override
  State<EditLecturePage> createState() =>
      _EditLecturePageState();
}

class _EditLecturePageState
    extends State<EditLecturePage> {
  late TextEditingController subjectController;
  late TextEditingController timeController;
  late TextEditingController roomController;

  bool cancelled = false;

  bool get isSR =>
      AppSettings.currentRole ==
      UserRole.sr;

  @override
  void initState() {
    super.initState();

    subjectController =
        TextEditingController(
      text: widget.lecture['subject'],
    );

    timeController =
        TextEditingController(
      text: widget.lecture['time'],
    );

    roomController =
        TextEditingController(
      text: widget.lecture['room'],
    );

    cancelled =
        widget.lecture['cancelled'] ==
            'true';
  }

  @override
  void dispose() {
    subjectController.dispose();
    timeController.dispose();
    roomController.dispose();
    super.dispose();
  }

  void _saveLecture() {
    Navigator.pop(
      context,
      {
        'id':
            widget.lecture['id'] ?? '',
        'subject':
            subjectController.text,
        'time':
            timeController.text,
        'room':
            roomController.text,
        'cancelled':
            cancelled.toString(),
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Lecture',
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller:
                  subjectController,
              enabled: !isSR,
              decoration:
                  InputDecoration(
                labelText:
                    'Subject',
                border:
                    const OutlineInputBorder(),
                helperText: isSR
                    ? 'Only CR can change subject'
                    : null,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller:
                  timeController,
              decoration:
                  const InputDecoration(
                labelText: 'Time',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller:
                  roomController,
              decoration:
                  const InputDecoration(
                labelText: 'Room',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text(
                'Lecture Cancelled',
              ),
              value: cancelled,
              onChanged: (value) {
                setState(() {
                  cancelled = value;
                });
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width:
                  double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _saveLecture,
                icon: const Icon(
                  Icons.save,
                ),
                label: const Text(
                  'Save Changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}