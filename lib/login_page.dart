import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'role_selection_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _startSetup(
    BuildContext context,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      'has_logged_in',
      true,
    );

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const RoleSelectionPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school,
                size: 120,
              ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                'Schedly',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Smart College Timetable & Notifications',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),

              const SizedBox(
                height: 50,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 50,
                child:
                    ElevatedButton(
                  onPressed: () =>
                      _startSetup(
                    context,
                  ),
                  child: const Text(
                    'Get Started',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}