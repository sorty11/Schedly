import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'user_roles.dart';
import 'add_lecture_page.dart';
import 'timetable_manager.dart';
import 'delete_lecture_page.dart';
import 'create_announcement_page.dart';

class CRPanelPage extends StatefulWidget {
  const CRPanelPage({super.key});

  @override
  State<CRPanelPage> createState() =>
      _CRPanelPageState();
}

class _CRPanelPageState
    extends State<CRPanelPage> {
  Future<void> _logoutCR(
    BuildContext context,
  ) async {
    await AppSettings.resetRole();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Logged out from CR mode',
        ),
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _addLecture() async {
    final lecture =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AddLecturePage(),
      ),
    );

    if (lecture == null) return;

    final prefs =
        await SharedPreferences.getInstance();

    final division =
        prefs.getString(
      'selected_division',
    );

    if (division == null) return;

    TimetableManager.addLecture(
      division: division,
      day: lecture['day'],
      subject: lecture['subject'],
      time: lecture['time'],
      room: lecture['room'],
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '${lecture['subject']} added to ${lecture['day']}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppSettings.currentRole !=
        UserRole.cr) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CR Panel',
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading:
                    const Icon(
                  Icons.edit,
                ),
                title: const Text(
                  'Edit Lectures',
                ),
                subtitle: const Text(
                  'Long press lectures on dashboard',
                ),
              ),
            ),

            Card(
              child: ListTile(
                leading:
                    const Icon(
                  Icons.add,
                ),
                title: const Text(
                  'Add Lecture',
                ),
                subtitle: const Text(
                  'Add lecture to timetable',
                ),
                onTap: _addLecture,
              ),
            ),

            Card(
  child: ListTile(
    leading:
        const Icon(Icons.delete),
    title: const Text(
      'Delete Lecture',
    ),
    subtitle: const Text(
      'Remove a lecture',
    ),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const DeleteLecturePage(),
        ),
      );
    },
  ),
),
Card(
  child: ListTile(
    leading: const Icon(
      Icons.campaign,
    ),
    title: const Text(
      'Create Announcement',
    ),
    subtitle: const Text(
      'Notify students',
    ),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const CreateAnnouncementPage(),
        ),
      );
    },
  ),
),

            Card(
              child: ListTile(
                leading:
                    const Icon(
                  Icons.picture_as_pdf,
                ),
                title: const Text(
                  'Upload Timetable PDF',
                ),
                subtitle: const Text(
                  'Future feature',
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed: () =>
                    _logoutCR(
                  context,
                ),
                icon: const Icon(
                  Icons.logout,
                ),
                label: const Text(
                  'Exit CR Mode',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}