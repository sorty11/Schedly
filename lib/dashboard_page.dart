import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'division_selection_page.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedly'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _changeDivision(context),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Division: $division',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}