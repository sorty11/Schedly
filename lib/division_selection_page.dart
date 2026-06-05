import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'role_verification_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';

class DivisionSelectionPage
    extends StatelessWidget {
  final String role;

  const DivisionSelectionPage({
    super.key,
    required this.role,
  });

  Future<void> _selectDivision(
    BuildContext context,
    String division,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'selected_division',
      division,
    );

    if (!context.mounted) return;

    if (role == 'Student') {
      await AppSettings.saveRole(
        UserRole.student,
      );

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            division: division,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RoleVerificationPage(
            division: division,
            role: role,
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Division ($role)',
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection(
                  'divisions',
                )
                .where(
                  'active',
                  isEqualTo: true,
                )
                .snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot
                  .data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No divisions found',
              ),
            );
          }

          final divisions =
              snapshot.data!.docs;

          return ListView.builder(
            padding:
                const EdgeInsets.all(
              16,
            ),
            itemCount:
                divisions.length,
            itemBuilder: (
              context,
              index,
            ) {
              final division =
                  divisions[index].id;

              return Card(
                margin:
                    const EdgeInsets.symmetric(
                  vertical: 8,
                ),
                child: ListTile(
                  title: Text(
                    division,
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  trailing:
                      const Icon(
                    Icons
                        .arrow_forward_ios,
                  ),
                  onTap: () =>
                      _selectDivision(
                    context,
                    division,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}