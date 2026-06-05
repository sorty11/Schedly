import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'edit_lecture_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'services/app_notification_service.dart';
import 'add_lecture_page.dart';

class WeeklyTimetablePage extends StatefulWidget {
  final String division;

  const WeeklyTimetablePage({
    super.key,
    required this.division,
  });

  @override
  State<WeeklyTimetablePage> createState() =>
      _WeeklyTimetablePageState();
}

class _WeeklyTimetablePageState
    extends State<WeeklyTimetablePage> {
  String selectedDay = 'Monday';

  bool _canEditLecture(
    Map<String, dynamic> lecture,
  ) {
    if (AppSettings.currentRole ==
        UserRole.cr) {
      return true;
    }

    if (AppSettings.currentRole ==
        UserRole.sr) {
      return lecture['subject'] ==
          AppSettings.srSubject;
    }

    return false;
  }

  Future<void> _editLecture(
    String docId,
    Map<String, dynamic> lecture,
  ) async {
    final result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditLecturePage(
          lecture: {
            'id': docId,
            'subject':
                lecture['subject'] ?? '',
            'time':
                lecture['time'] ?? '',
            'room':
                lecture['room'] ?? '',
            'cancelled':
                lecture['cancelled'] == true
                    ? 'true'
                    : 'false',
          },
        ),
      ),
    );

    if (result == null) return;

    final updated =
        result as Map<String, dynamic>;

    final oldSubject =
        lecture['subject'] ?? '';

    final oldTime =
        lecture['time'] ?? '';

    final oldRoom =
        lecture['room'] ?? '';

    final oldCancelled =
        lecture['cancelled'] == true;

    await FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(selectedDay)
        .doc(docId)
        .update({
      'subject': updated['subject'],
      'time': updated['time'],
      'room': updated['room'],
      'cancelled':
          updated['cancelled'] == 'true',
    });

    if (updated['cancelled'] == 'true' &&
        !oldCancelled) {
      await AppNotificationService
          .createNotification(
        title: 'Lecture Cancelled',
        message:
            '${updated['subject']} at ${updated['time']} has been cancelled',
        division: widget.division,
        type: 'cancel',
      );
    }

    if (updated['room'] != oldRoom) {
      await AppNotificationService
          .createNotification(
        title: 'Room Changed',
        message:
            '${updated['subject']} moved from $oldRoom to ${updated['room']}',
        division: widget.division,
        type: 'room_change',
      );
    }

    if (updated['time'] != oldTime) {
      await AppNotificationService
          .createNotification(
        title: 'Lecture Rescheduled',
        message:
            '${updated['subject']} moved from $oldTime to ${updated['time']}',
        division: widget.division,
        type: 'time_change',
      );
    }

    if (updated['subject'] != oldSubject) {
      await AppNotificationService
          .createNotification(
        title: 'Lecture Updated',
        message:
            '$oldSubject changed to ${updated['subject']}',
        division: widget.division,
        type: 'edit',
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Lecture updated',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Weekly Timetable',
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection:
                  Axis.horizontal,
              children: [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
              ].map((day) {
                return Padding(
                  padding:
                      const EdgeInsets.all(
                    8,
                  ),
                  child: ChoiceChip(
                    label: Text(day),
                    selected:
                        selectedDay == day,
                    onSelected: (_) {
                      setState(() {
                        selectedDay = day;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot>(
              stream: FirebaseFirestore
                  .instance
                  .collection(
                    'timetables',
                  )
                  .doc(
                    widget.division,
                  )
                  .collection(
                    selectedDay,
                  )
                  .snapshots(),
              builder:
                  (context, snapshot) {
                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (!snapshot
                        .hasData ||
                    snapshot!
                        .data!
                        .docs
                        .isEmpty) {
                  return const Center(
                    child: Text(
                      'No lectures scheduled',
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
                    final doc = docs[index];

                    final lecture =
                        doc.data()
                            as Map<
                                String,
                                dynamic>;

                    final isCancelled =
                        lecture[
                                'cancelled'] ==
                            true;

                    return Card(
                      color: isCancelled
                          ? Colors.red.shade100
                          : null,
                      child: ListTile(
                        onLongPress:
                            _canEditLecture(
                                    lecture)
                                ? () =>
                                    _editLecture(
                                      doc.id,
                                      lecture,
                                    )
                                : null,
                        leading: Icon(
                          isCancelled
                              ? Icons.cancel
                              : Icons.book,
                        ),
                        title: Text(
                          lecture[
                                  'subject'] ??
                              '',
                        ),
                        subtitle:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              lecture[
                                      'time'] ??
                                  '',
                            ),
                            Text(
                              'Room: ${lecture['room'] ?? ''}',
                            ),
                            if (isCancelled)
                              const Text(
                                '❌ CANCELLED',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.red,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: isCancelled &&
                                AppSettings.currentRole ==
                                    UserRole.cr
                            ? IconButton(
                                icon: const Icon(
                                  Icons.swap_horiz,
                                ),
                                onPressed: () async {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AddLecturePage(),
                                    ),
                                  );
                                },
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
