import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'subject_data.dart';
import 'user_roles.dart';

class SRLoginPage extends StatefulWidget {
  const SRLoginPage({super.key});

  @override
  State<SRLoginPage> createState() =>
      _SRLoginPageState();
}

class _SRLoginPageState
    extends State<SRLoginPage> {
  final passwordController =
      TextEditingController();

  String selectedDivision =
      'SY CSE A';

  String? selectedSubject;

  @override
  void initState() {
    super.initState();

    selectedSubject =
        SubjectData.divisionSubjects[
            selectedDivision]
        ?.first;
  }

  Future<void> login() async {
    if (passwordController.text !=
        "sr123") {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Wrong Password"),
        ),
      );
      return;
    }

    await AppSettings.saveRole(
      UserRole.sr,
    );

    await AppSettings.saveSRDetails(
      division: selectedDivision,
      subject: selectedSubject!,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          'Logged in as ${selectedSubject!} SR',
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final subjects =
        SubjectData.divisionSubjects[
                selectedDivision] ??
            [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SR Login',
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<
                String>(
              value: selectedDivision,
              decoration:
                  const InputDecoration(
                labelText:
                    'Division',
              ),
              items:
                  SubjectData
                      .divisionSubjects
                      .keys
                      .map(
                (division) {
                  return DropdownMenuItem(
                    value:
                        division,
                    child: Text(
                      division,
                    ),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  selectedDivision =
                      value;

                  selectedSubject =
                      SubjectData
                          .divisionSubjects[
                              value]
                          ?.first;
                });
              },
            ),

            const SizedBox(
              height: 16,
            ),

            DropdownButtonFormField<
                String>(
              value:
                  selectedSubject,
              decoration:
                  const InputDecoration(
                labelText:
                    'Subject',
              ),
              items:
                  subjects.map(
                (subject) {
                  return DropdownMenuItem(
                    value:
                        subject,
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

            TextField(
              controller:
                  passwordController,
              obscureText: true,
              decoration:
                  const InputDecoration(
                labelText:
                    'SR Password',
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            SizedBox(
              width:
                  double.infinity,
              child: ElevatedButton(
                onPressed: login,
                child: const Text(
                  'Login',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}