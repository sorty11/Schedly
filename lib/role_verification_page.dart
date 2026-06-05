import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';

class RoleVerificationPage
    extends StatefulWidget {
  final String division;
  final String role;

  const RoleVerificationPage({
    super.key,
    required this.division,
    required this.role,
  });

  @override
  State<RoleVerificationPage>
      createState() =>
          _RoleVerificationPageState();
}

class _RoleVerificationPageState
    extends State<
        RoleVerificationPage> {
  final passwordController =
      TextEditingController();

  bool loading = false;

  Future<void> _verify() async {
    setState(() {
      loading = true;
    });

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('divisions')
              .doc(widget.division)
              .get();

      if (!doc.exists) {
        throw Exception(
          'Role configuration not found',
        );
      }

      final data = doc.data()!;

      final savedPassword =
          widget.role == 'CR'
              ? data['crPassword']
              : data['srPassword'];

      if (passwordController.text !=
          savedPassword) {
        throw Exception(
          'Incorrect Password',
        );
      }

      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setString(
        'selected_division',
        widget.division,
      );

      if (widget.role == 'CR') {
  await AppSettings.saveRole(
    UserRole.cr,
  );
} else {
  await AppSettings.saveRole(
    UserRole.sr,
  );
}

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            division:
                widget.division,
          ),
        ),
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(e.toString()),
        ),
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.role} Verification',
        ),
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
                    'Password',
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton(
                onPressed: loading
                    ? null
                    : _verify,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Verify',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}