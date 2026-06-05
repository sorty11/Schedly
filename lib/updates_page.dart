import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key});

  @override
  State<UpdatesPage> createState() =>
      _UpdatesPageState();
}

class _UpdatesPageState
    extends State<UpdatesPage> {
  Future<String?> _getDivision() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(
      'selected_division',
    );
  }

  Color _getColor(String type) {
    switch (type) {
      case 'cancel':
        return Colors.red;

      case 'add':
        return Colors.green;

      case 'room_change':
        return Colors.blue;

      case 'time_change':
        return Colors.orange;

      case 'announcement':
        return Colors.purple;

      default:
        return Colors.grey;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'cancel':
        return Icons.cancel;

      case 'add':
        return Icons.add_circle;

      case 'room_change':
        return Icons.meeting_room;

      case 'time_change':
        return Icons.access_time;

      case 'announcement':
        return Icons.campaign;

      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Updates',
        ),
      ),
      body: FutureBuilder<String?>(
        future: _getDivision(),
        builder: (
          context,
          divisionSnapshot,
        ) {
          if (!divisionSnapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final division =
              divisionSnapshot.data;

          if (division == null) {
            return const Center(
              child: Text(
                'No division selected',
              ),
            );
          }

          return StreamBuilder<
              QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection(
                      'notifications',
                    )
                    .where(
                      'division',
                      isEqualTo:
                          division,
                    )
                    .orderBy(
                      'createdAt',
                      descending: true,
                    )
                    .snapshots(),
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot
                      .connectionState ==
                  ConnectionState
                      .waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                  ),
                );
              }

              if (!snapshot.hasData ||
                  snapshot
                      .data!
                      .docs
                      .isEmpty) {
                return const Center(
                  child: Text(
                    'No updates yet',
                  ),
                );
              }

              final docs =
                  snapshot.data!.docs;

              return ListView.builder(
                itemCount:
                    docs.length,
                itemBuilder:
                    (
                      context,
                      index,
                    ) {
                  final data =
                      docs[index]
                          .data()
                          as Map<
                              String,
                              dynamic>;

                  final type =
                      data['type'] ??
                          '';

                  return Card(
                    margin:
                        const EdgeInsets.all(
                      8,
                    ),
                    child: ListTile(
                      leading:
                          CircleAvatar(
                        backgroundColor:
                            _getColor(
                          type,
                        ),
                        child: Icon(
                          _getIcon(
                            type,
                          ),
                          color: Colors
                              .white,
                        ),
                      ),
                      title: Text(
                        data['title'] ??
                            '',
                      ),
                      subtitle: Text(
                        data['message'] ??
                            '',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}