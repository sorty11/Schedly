import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/app_notification_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/animated_list_tile.dart';
import 'widgets/animations/animated_icon_button.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/animations/floating_empty_state.dart';

class DeleteLecturePage extends StatefulWidget {
  const DeleteLecturePage({super.key});

  @override
  State<DeleteLecturePage> createState() =>
      _DeleteLecturePageState();
}

class _DeleteLecturePageState
    extends State<DeleteLecturePage> {
  String selectedDay = 'Monday';

  String? division;
  Stream<QuerySnapshot>? _lecturesStream;
  bool _isDeleting = false;

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _loadDivision();
  }

  Future<void> _loadDivision() async {
    final prefs =
        await SharedPreferences.getInstance();

    division = prefs.getString('selected_division');
    if (division != null) {
      _updateStream();
    }
    setState(() {});
  }

  void _updateStream() {
    if (division == null) return;
    _lecturesStream = FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(selectedDay)
        .snapshots();
  }

  Future<void> _deleteLecture(
    String docId,
    String subject,
  ) async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    
    final shouldDelete = await AppDialogs.showConfirm(
      context: context,
      title: 'Delete Lecture',
      message: 'Are you sure you want to delete "$subject"?',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (!shouldDelete || division == null) {
      setState(() => _isDeleting = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('timetables')
          .doc(division)
          .collection(selectedDay)
          .doc(docId)
          .delete();

      // Notify all students in this division that the lecture was removed
      await AppNotificationService.createNotification(
        title: 'Lecture Cancelled',
        message: '$subject has been removed from $selectedDay.',
        division: division!,
        type: 'cancel',
      );

      HapticFeedback.mediumImpact();
      if (!mounted) return;

      AppDialogs.showSnackBar(
        context: context,
        message: '$subject deleted',
        isError: true, // using error style for delete action
      );
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Delete Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (division == null) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Lecture',
        ),
      ),
      body: Padding(
        padding:
            EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedDay,
              decoration:
                  const InputDecoration(
                labelText: 'Day',
                border:
                    OutlineInputBorder(),
              ),
              items: days.map((day) {
                return DropdownMenuItem(
                  value: day,
                  child: Text(day),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedDay = value;
                  });
                }
              },
            ),

            const SizedBox(
              height: 16,
            ),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot>(
                stream: _lecturesStream,
                builder:
                    (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: FloatingEmptyState(
                        icon: Icons.event_busy_rounded,
                        title: 'No Lectures',
                        subtitle: 'No lectures scheduled for this day.',
                      ),
                    );
                  }

                  final docs =
                      snapshot.data!.docs;

                  return ListView.builder(
                    itemCount:
                        docs.length,
                    itemBuilder:
                        (
                      context,
                      index,
                    ) {
                      final doc =
                          docs[index];

                      final lecture =
                          doc.data()
                              as Map<
                                  String,
                                  dynamic>;

                      return AnimatedListTile(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        title: Text(lecture['subject'] ?? ''),
                        subtitle: Text('${lecture['time']} • ${lecture['room']}'),
                        trailing: AnimatedIconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Theme.of(context).extension<AppSemanticColors>()!.cancelled,
                          ),
                          onPressed: () => _deleteLecture(doc.id, lecture['subject'] ?? ''),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
