import 'package:flutter/material.dart';

import 'timetable_data.dart';
import 'edit_lecture_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';

class WeeklyTimetablePage
    extends StatefulWidget {
  final String division;

  const WeeklyTimetablePage({
    super.key,
    required this.division,
  });

  @override
  State<WeeklyTimetablePage>
      createState() =>
          _WeeklyTimetablePageState();
}

class _WeeklyTimetablePageState
    extends State<
        WeeklyTimetablePage> {
  String selectedDay = 'Monday';

  bool _canEditLecture(
    Map<String, String> lecture,
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
    int index,
    List<Map<String, String>>
        lectures,
  ) async {
    final updatedLecture =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditLecturePage(
          lecture: lectures[index],
        ),
      ),
    );

    if (updatedLecture != null) {
      setState(() {
        lectures[index] =
            Map<String, String>.from(
          updatedLecture,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Lecture Updated',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final divisionData =
        TimetableData.timetable[
                widget.division] ??
            <String,
                List<
                    Map<String,
                        String>>>{};

    final lectures =
        divisionData[selectedDay] ??
            <Map<String, String>>[];

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
                      const EdgeInsets
                          .all(8),
                  child: ChoiceChip(
                    label: Text(day),
                    selected:
                        selectedDay ==
                            day,
                    onSelected: (_) {
                      setState(() {
                        selectedDay =
                            day;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: lectures.isEmpty
                ? const Center(
                    child: Text(
                      'No lectures scheduled',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        lectures.length,
                    itemBuilder:
                        (
                      context,
                      index,
                    ) {
                      final lecture =
                          lectures[
                              index];

                      final isCancelled =
                          lecture[
                                  'cancelled'] ==
                              'true';

                      return Card(
                        color: isCancelled
                            ? Colors.red
                                .shade100
                            : null,
                        child:
                            ListTile(
                          onLongPress:
                              _canEditLecture(
                                      lecture)
                                  ? () =>
                                      _editLecture(
                                        index,
                                        lectures,
                                      )
                                  : null,
                          leading:
                              Icon(
                            isCancelled
                                ? Icons
                                    .cancel
                                : Icons
                                    .book,
                          ),
                          title: Text(
                            lecture['subject'] ??
                                '',
                          ),
                          subtitle:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                lecture['time'] ??
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
                                    color: Colors
                                        .red,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}