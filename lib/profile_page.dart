import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'cr_login_page.dart';
import 'sr_login_page.dart';
import 'user_roles.dart';

class ProfilePage extends StatefulWidget {
  final String division;

  const ProfilePage({
    super.key,
    required this.division,
  });

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState
    extends State<ProfilePage> {
  Future<void> _refresh() async {
    await AppSettings.loadRole();
    await AppSettings.loadSRDetails();

    if (mounted) {
      setState(() {});
    }
  }

  String get roleText {
    switch (AppSettings.currentRole) {
      case UserRole.cr:
        return "CR";

      case UserRole.sr:
        return "SR";

      default:
        return "Student";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Profile",
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    24,
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        child: Icon(
                          Icons.school,
                          size: 40,
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      Text(
                        widget.division,
                        style:
                            const TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        "Role: $roleText",
                        style:
                            const TextStyle(
                          fontSize: 18,
                        ),
                      ),

                      if (AppSettings
                              .currentRole ==
                          UserRole.sr) ...[
                        const SizedBox(
                          height: 10,
                        ),

                        Text(
                          "Subject: ${AppSettings.srSubject}",
                        ),

                        Text(
                          "Division: ${AppSettings.srDivision}",
                        ),
                      ],

                      if (AppSettings
                              .currentRole ==
                          UserRole.cr)
                        const Padding(
                          padding:
                              EdgeInsets.only(
                            top: 10,
                          ),
                          child: Chip(
                            label: Text(
                              "👑 CR",
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              ElevatedButton.icon(
                icon: const Icon(
                  Icons.admin_panel_settings,
                ),
                label: const Text(
                  "CR Login",
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const CRLoginPage(),
                    ),
                  );

                  _refresh();
                },
              ),

              const SizedBox(
                height: 12,
              ),

              ElevatedButton.icon(
                icon: const Icon(
                  Icons.book,
                ),
                label: const Text(
                  "SR Login",
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const SRLoginPage(),
                    ),
                  );

                  _refresh();
                },
              ),

              const SizedBox(
                height: 12,
              ),

              ElevatedButton.icon(
                icon:
                    const Icon(Icons.logout),
                label:
                    const Text("Logout"),
                onPressed: () async {
                  await AppSettings
                      .resetRole();

                  await _refresh();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}