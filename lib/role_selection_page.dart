import 'package:flutter/material.dart';

import 'division_selection_page.dart';

class RoleSelectionPage
    extends StatelessWidget {
  const RoleSelectionPage({
    super.key,
  });

  void _openDivisionSelection(
    BuildContext context,
    String role,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DivisionSelectionPage(
          role: role,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Select Role'),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading:
                    const Icon(
                  Icons.person,
                ),
                title: const Text(
                  'Student',
                ),
                subtitle: const Text(
                  'Regular Student Access',
                ),
                onTap: () =>
                    _openDivisionSelection(
                  context,
                  'Student',
                ),
              ),
            ),

            Card(
              child: ListTile(
                leading:
                    const Icon(
                  Icons.star,
                ),
                title: const Text(
                  'CR',
                ),
                subtitle: const Text(
                  'Class Representative',
                ),
                onTap: () =>
                    _openDivisionSelection(
                  context,
                  'CR',
                ),
              ),
            ),

            Card(
              child: ListTile(
                leading:
                    const Icon(
                  Icons.book,
                ),
                title: const Text(
                  'SR',
                ),
                subtitle: const Text(
                  'Subject Representative',
                ),
                onTap: () =>
                    _openDivisionSelection(
                  context,
                  'SR',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}