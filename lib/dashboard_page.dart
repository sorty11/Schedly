import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'division_selection_page.dart';
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

  @override
  Widget build(BuildContext context) {
    final timetable =
        TimetableData.timetable[division] ?? [];

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
                      'SVKM\'s NMIMS',
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
              child: ListView.builder(
                itemCount: timetable.length,
                itemBuilder: (context, index) {
                  final lecture = timetable[index];

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.book),
                      title: Text(
                        lecture['subject']!,
                      ),
                      subtitle: Text(
                        lecture['time']!,
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