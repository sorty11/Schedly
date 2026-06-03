import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'user_roles.dart';

class CRLoginPage extends StatefulWidget {
  const CRLoginPage({super.key});

  @override
  State<CRLoginPage> createState() =>
      _CRLoginPageState();
}

class _CRLoginPageState
    extends State<CRLoginPage> {
  final passwordController =
      TextEditingController();

  Future<void> login() async {
    if (passwordController.text ==
        "schedly123") {
      await AppSettings.saveRole(
        UserRole.cr,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Logged in as CR"),
        ),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Wrong Password"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("CR Login"),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller:
                  passwordController,
              obscureText: true,
              decoration:
                  const InputDecoration(
                labelText:
                    "CR Password",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: login,
              child:
                  const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}