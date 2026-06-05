import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfImportPreviewPage extends StatelessWidget {
  final Map<String, List<Map<String, String>>> timetable;

  const PdfImportPreviewPage({
    super.key,
    required this.timetable,
  });

  Future<void> _importTimetable(
    BuildContext context,
  ) async {
    const division = 'FY CSE A';

    final db =
        FirebaseFirestore.instance;

    for (final day
        in timetable.keys) {
      final dayCollection =
          db
              .collection(
                'timetables',
              )
              .doc(division)
              .collection(day);

      final existing =
          await dayCollection.get();

      for (final doc
          in existing.docs) {
        await doc.reference.delete();
      }

      for (final lecture
          in timetable[day]!) {
        await dayCollection.add({
          'subject':
              lecture['subject'],
          'time':
              lecture['time'],
          'room':
              lecture['room'],
          'cancelled': false,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      }
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Timetable Imported Successfully',
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final days =
        timetable.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Timetable Preview',
        ),
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () =>
            _importTimetable(
          context,
        ),
        icon: const Icon(
          Icons.check,
        ),
        label: const Text(
          'IMPORT',
        ),
      ),

      body: ListView.builder(
        padding:
            const EdgeInsets.all(16),
        itemCount: days.length,
        itemBuilder: (
          context,
          index,
        ) {
          final day =
              days[index];

          final lectures =
              timetable[day]!;

          return Card(
            margin:
                const EdgeInsets.only(
              bottom: 16,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    day,
                    style:
                        const TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  ...lectures.map(
                    (
                      lecture,
                    ) {
                      return ListTile(
                        leading:
                            const Icon(
                          Icons.book,
                        ),
                        title: Text(
                          lecture[
                                  'subject'] ??
                              '',
                        ),
                        subtitle: Text(
                          '${lecture['time']}'
                          '\nRoom: ${lecture['room']}',
                        ),
                      );
                    },
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