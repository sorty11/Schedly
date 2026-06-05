import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcements',
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot>(
        stream: Stream.fromFuture(
          SharedPreferences.getInstance(),
        ).asyncExpand(
          (prefs) {
            final division =
                prefs.getString(
              'selected_division',
            );

            return FirebaseFirestore.instance
                .collection(
                  'announcements',
                )
                .where(
                  'division',
                  isEqualTo: division,
                )
                .orderBy(
                  'createdAt',
                  descending: true,
                )
                .snapshots();
          },
        ),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading announcements',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No announcements yet',
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder:
                (context, index) {
              final data =
                  docs[index].data()
                      as Map<
                        String,
                        dynamic
                      >;

              return Card(
                margin:
                    const EdgeInsets.all(
                  8,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _priorityColor(
                      data['priority'] ??
                          'Normal',
                    ),
                  ),
                  title: Text(
                    data['title'] ?? '',
                  ),
                  subtitle: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        data['message'] ??
                            '',
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        data['priority'] ??
                            'Normal',
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
          );
        },
      ),
    );
  }
}
