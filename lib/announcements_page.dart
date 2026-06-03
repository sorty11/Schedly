
import 'package:flutter/material.dart';

import 'announcement_manager.dart';

class AnnouncementsPage
    extends StatefulWidget {
  const AnnouncementsPage({
    super.key,
  });

  @override
  State<AnnouncementsPage>
      createState() =>
          _AnnouncementsPageState();
}

class _AnnouncementsPageState
    extends State<
        AnnouncementsPage> {
  Color _priorityColor(
    String priority,
  ) {
    switch (priority) {
      case 'High':
        return Colors.red;

      case 'Low':
        return Colors.green;

      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcements =
        AnnouncementManager
            .announcements;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcements',
        ),
      ),
      body: announcements.isEmpty
          ? const Center(
              child: Text(
                'No announcements yet',
              ),
            )
          : ListView.builder(
              itemCount:
                  announcements.length,
              itemBuilder:
                  (context, index) {
                final item =
                    announcements[
                        index];

                return Card(
                  margin:
                      const EdgeInsets.all(
                    8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _priorityColor(
                        item.priority,
                      ),
                    ),
                    title:
                        Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          item.message,
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          item.priority,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}