import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    String docId,
    String subject,
  ) async {
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

    if (!shouldDelete ||
        division == null) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(selectedDay)
        .doc(docId)
        .delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '$subject deleted',
        ),
      ),
    );
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
              child: StreamBuilder<
                  QuerySnapshot>(
                stream: FirebaseFirestore
                    .instance
                    .collection(
                      'timetables',
                    )
                    .doc(division)
                    .collection(
                      selectedDay,
                    )
                    .snapshots(),
                builder:
                    (context, snapshot) {
                  if (!snapshot
                          .hasData ||
                      snapshot!
                          .data!
                          .docs
                          .isEmpty) {
                    return const Center(
                      child: Text(
                        'No lectures found',
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

                      return Card(
                        child: ListTile(
                          title: Text(
                            lecture[
                                    'subject'] ??
                                '',
                          ),
                          subtitle: Text(
                            '${lecture['time']} • ${lecture['room']}',
                          ),
                          trailing:
                              IconButton(
                            icon:
                                const Icon(
                              Icons.delete,
                              color:
                                  Colors.red,
                            ),
                            onPressed:
                                () =>
                                    _deleteLecture(
                              doc.id,
                              lecture[
                                      'subject'] ??
                                  '',
                            ),
                          ),
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