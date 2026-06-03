import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timetable_manager.dart';

class AddLecturePage extends StatefulWidget {
  const AddLecturePage({super.key});

  @override
  State<AddLecturePage> createState() =>
      _AddLecturePageState();
}

class _AddLecturePageState
    extends State<AddLecturePage> {
  final subjectController =
      TextEditingController();

  final roomController =
      TextEditingController();

  String selectedDay = 'Monday';

  String? selectedSlot;

  String? division;

  List<String> availableSlots = [];

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

    _refreshSlots();
  }

  void _refreshSlots() {
    if (division == null) return;

    availableSlots =
        TimetableManager.getAvailableSlots(
      division: division!,
      day: selectedDay,
    );

    if (availableSlots.isNotEmpty) {
      selectedSlot =
          availableSlots.first;
    } else {
      selectedSlot = null;
    }

    setState(() {});
  }

  @override
  void dispose() {
    subjectController.dispose();
    roomController.dispose();
    super.dispose();
  }

  void _saveLecture() {
    if (subjectController.text.isEmpty ||
        roomController.text.isEmpty ||
        selectedSlot == null) {
      return;
    }

    Navigator.pop(
      context,
      {
        'day': selectedDay,
        'subject':
            subjectController.text,
        'time': selectedSlot!,
        'room':
            roomController.text,
        'cancelled': 'false',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Add Lecture'),
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
              items: days.map((day) {
                return DropdownMenuItem(
                  value: day,
                  child: Text(day),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedDay = value;
                  _refreshSlots();
                }
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller:
                  subjectController,
              decoration:
                  const InputDecoration(
                labelText: 'Subject',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

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
                    child: Text(slot),
                  );
                },
              ).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSlot =
                      value;
                });
              },
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

            const SizedBox(height: 24),

            SizedBox(
              width:
                  double.infinity,
              child: ElevatedButton(
                onPressed:
                    _saveLecture,
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