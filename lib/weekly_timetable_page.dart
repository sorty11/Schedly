import 'package:flutter/material.dart';
import 'timetable_data.dart';

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

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, String>>> divisionData =
        TimetableData.timetable[widget.division] ??
            <String, List<Map<String, String>>>{};

    final List<Map<String, String>> lectures =
        divisionData[selectedDay] ??
            <Map<String, String>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Timetable'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
              ].map((day) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: ChoiceChip(
                    label: Text(day),
                    selected: selectedDay == day,
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
            child: lectures.isEmpty
                ? const Center(
                    child: Text('No lectures scheduled'),
                  )
                : ListView.builder(
                    itemCount: lectures.length,
                    itemBuilder: (context, index) {
                      final lecture = lectures[index];

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.book),
                          title: Text(
                            lecture['subject'] ?? '',
                          ),
                          subtitle: Text(
                            lecture['time'] ?? '',
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