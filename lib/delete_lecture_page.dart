import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timetable_data.dart';

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

    division =
        prefs.getString(
      'selected_division',
    );

    setState(() {});
  }

  Future<void> _deleteLecture(
    int index,
  ) async {
    if (division == null) return;

    final lectures =
        TimetableData
            .timetable[division!]?[selectedDay];

    if (lectures == null) return;

    final subject =
        lectures[index]['subject'] ?? '';

    final shouldDelete =
        await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text(
                    'Delete Lecture',
                  ),
                  content: Text(
                    'Are you sure you want to delete "$subject"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          false,
                        );
                      },
                      child: const Text(
                        'Cancel',
                      ),
                    ),
                    ElevatedButton(
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.red,
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          true,
                        );
                      },
                      child: const Text(
                        'Delete',
                      ),
                    ),
                  ],
                );
              },
            ) ??
            false;

    if (!shouldDelete) return;

    lectures.removeAt(index);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '$subject deleted',
        ),
      ),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lectures =
        division == null
            ? []
            : TimetableData
                    .timetable[division!]
                ?[selectedDay] ??
                [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Lecture',
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedDay,
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
              child: lectures.isEmpty
                  ? const Center(
                      child: Text(
                        'No lectures found',
                      ),
                    )
                  : ListView.builder(
                      itemCount:
                          lectures.length,
                      itemBuilder:
                          (context, index) {
                        final lecture =
                            lectures[index];

                        return Card(
                          child: ListTile(
                            title: Text(
                              lecture['subject'] ??
                                  '',
                            ),
                            subtitle: Text(
                              '${lecture['time']} • ${lecture['room']}',
                            ),
                            trailing:
                                IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color:
                                    Colors.red,
                              ),
                              onPressed:
                                  () =>
                                      _deleteLecture(
                                index,
                              ),
                            ),
                          ),
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