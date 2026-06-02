import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class DivisionSelectionPage extends StatelessWidget {
  const DivisionSelectionPage({super.key});

  Future<void> _selectDivision(
    BuildContext context,
    String division,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_division', division);

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          division: division,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> divisions = [
      'FY CSE A',
      'FY CSE B',
      'SY CSE A',
      'SY CSE B',
      'TY CSE A',
      'TY CSE B',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Division'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: divisions.length,
        itemBuilder: (context, index) {
          final division = divisions[index];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text(
                division,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _selectDivision(
                context,
                division,
              ),
            ),
          );
        },
      ),
    );
  }
}