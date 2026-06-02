import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'division_selection_page.dart';
import 'weekly_timetable_page.dart';
import 'timetable_data.dart';

class DashboardPage extends StatelessWidget {
  final String division;

  const DashboardPage({
    super.key,
    required this.division,
  });

  Future<void> _changeDivision(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_division');

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const DivisionSelectionPage(),
      ),
    );
  }

  IconData _getIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return Icons.calculate;

      case 'programming':
      case 'oop':
      case 'java':
        return Icons.computer;

      case 'beee':
        return Icons.electrical_services;

      case 'physics':
        return Icons.science;

      case 'chemistry':
        return Icons.biotech;

      case 'dbms':
        return Icons.storage;

      case 'lade':
        return Icons.menu_book;

      default:
        return Icons.book;
    }
  }

  @override
  Widget build(BuildContext context) {
    final divisionData =
        TimetableData.timetable[division] ??
            <String, List<Map<String, String>>>{};

    final todayLectures =
        divisionData['Monday'] ??
            <Map<String, String>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedly'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Change Division',
            onPressed: () => _changeDivision(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/nmims_logo.png',
                      height: 90,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "SVKM's NMIMS",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      division,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text(
                'View Weekly Timetable',
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeeklyTimetablePage(
                      division: division,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            const Text(
              "Today's Timetable",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: todayLectures.isEmpty
                  ? const Center(
                      child: Text(
                        'No lectures scheduled',
                      ),
                    )
                  : ListView.builder(
                      itemCount: todayLectures.length,
                      itemBuilder: (context, index) {
                        final lecture =
                            todayLectures[index];

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              _getIcon(
                                lecture['subject'] ?? '',
                              ),
                            ),
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
      ),
    );
  }
}