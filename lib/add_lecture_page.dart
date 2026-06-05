import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timetable_manager.dart';
import 'services/firestore_service.dart';

class AddLecturePage extends StatefulWidget {
  const AddLecturePage({super.key});

  @override
  State<AddLecturePage> createState() =>
      _AddLecturePageState();
}

class _AddLecturePageState
    extends State<AddLecturePage> {
  final roomController =
      TextEditingController();

  String selectedDay = 'Monday';

  String? selectedSlot;

  String? division;

  String? selectedSubject;

  List<String> availableSlots = [];

  List<String> subjects = [];

  bool loadingSlots = true;

  bool loadingSubjects = true;

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

    if (division == null) return;

    subjects =
        await FirestoreService
            .getSubjects(
      division!,
    );

    if (subjects.isNotEmpty) {
      selectedSubject =
          subjects.first;
    }

    setState(() {
      loadingSubjects = false;
    });

    await _refreshSlots();
  }

  Future<void> _refreshSlots() async {
    if (division == null) return;

    setState(() {
      loadingSlots = true;
    });

    availableSlots =
        await TimetableManager
            .getAvailableSlots(
      division: division!,
      day: selectedDay,
    );

    if (availableSlots.isNotEmpty) {
      selectedSlot =
          availableSlots.first;
    } else {
      selectedSlot = null;
    }

    setState(() {
      loadingSlots = false;
    });
  }

  @override
  void dispose() {
    roomController.dispose();
    super.dispose();
  }

  void _saveLecture() {
    if (selectedSubject == null ||
        selectedSlot == null ||
        roomController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Fill all fields',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      {
        'day': selectedDay,
        'subject': selectedSubject!,
        'time': selectedSlot!,
        'room': roomController.text,
        'cancelled': 'false',
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
          'Add Lecture',
        ),
      ),
      body: SingleChildScrollView(
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
              items: days
                  .map(
                    (day) =>
                        DropdownMenuItem(
                      value: day,
                      child: Text(day),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;

                selectedDay = value;

                await _refreshSlots();
              },
            ),

            const SizedBox(
              height: 16,
            ),

            if (loadingSubjects)
              const Center(
                child:
                    CircularProgressIndicator(),
              )
            else
              DropdownButtonFormField<String>(
                value: selectedSubject,
                decoration:
                    const InputDecoration(
                  labelText: 'Subject',
                  border:
                      OutlineInputBorder(),
                ),
                items:
                    subjects.map(
                  (subject) {
                    return DropdownMenuItem(
                      value: subject,
                      child:
                          Text(subject),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSubject =
                        value;
                  });
                },
              ),

            const SizedBox(
              height: 16,
            ),

            if (loadingSlots)
              const Center(
                child:
                    CircularProgressIndicator(),
              )
            else
              DropdownButtonFormField<String>(
                value: selectedSlot,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Available Slot',
                  border:
                      OutlineInputBorder(),
                ),
                items:
                    availableSlots.map(
                  (slot) {
                    return DropdownMenuItem(
                      value: slot,
                      child:
                          Text(slot),
                    );
                  },
                ).toList(),
                onChanged:
                    availableSlots.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              selectedSlot =
                                  value;
                            });
                          },
              ),

            const SizedBox(
              height: 16,
            ),

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

            const SizedBox(
              height: 24,
            ),

            if (availableSlots.isEmpty &&
                !loadingSlots)
              const Padding(
                padding:
                    EdgeInsets.only(
                  bottom: 16,
                ),
                child: Text(
                  'No free slots available for this day',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),

            SizedBox(
              width:
                  double.infinity,
              child: ElevatedButton(
                onPressed:
                    availableSlots
                            .isEmpty
                        ? null
                        : _saveLecture,
                child: const Text(
                  'Save Lecture',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}