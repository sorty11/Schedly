import 'package:flutter/material.dart';

import 'system_update_manager.dart';

class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key});

  @override
  State<UpdatesPage> createState() =>
      _UpdatesPageState();
}

class _UpdatesPageState
    extends State<UpdatesPage> {
  @override
  void initState() {
    super.initState();

    SystemUpdateManager.markAllRead();
  }

  Color _getColor(String type) {
    switch (type) {
      case 'cancel':
        return Colors.red;

      case 'add':
        return Colors.green;

      case 'edit':
        return Colors.orange;

      default:
        return Colors.blue;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'cancel':
        return Icons.cancel;

      case 'add':
        return Icons.add_circle;

      case 'edit':
        return Icons.edit;

      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final updates =
        SystemUpdateManager.updates;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Updates',
        ),
      ),
      body: updates.isEmpty
          ? const Center(
              child: Text(
                'No updates yet',
              ),
            )
          : ListView.builder(
              itemCount: updates.length,
              itemBuilder:
                  (context, index) {
                final update =
                    updates[index];

                return Card(
                  margin:
                      const EdgeInsets.all(
                    8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _getColor(
                        update.type,
                      ),
                      child: Icon(
                        _getIcon(
                          update.type,
                        ),
                        color:
                            Colors.white,
                      ),
                    ),
                    title: Text(
                      update.title,
                    ),
                    subtitle: Text(
                      update.description,
                    ),
                    trailing:
                        update.isRead
                            ? null
                            : const Icon(
                                Icons.fiber_manual_record,
                                color:
                                    Colors.red,
                                size: 12,
                              ),
                  ),
                );
              },
            ),
    );
  }
}