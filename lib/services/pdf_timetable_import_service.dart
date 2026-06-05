import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfTimetableImportService {
  static final FirebaseFirestore db =
      FirebaseFirestore.instance;

  static Future<String> extractText(
    Uint8List pdfBytes,
  ) async {
    final document =
        PdfDocument(inputBytes: pdfBytes);

    String text = '';

    for (int i = 0;
        i < document.pages.count;
        i++) {
      text += PdfTextExtractor(document)
          .extractText(
        startPageIndex: i,
        endPageIndex: i,
      );

      text += '\n';
    }

    document.dispose();

    return text;
  }

  static String? extractDivision(
    String text,
  ) {
    final match = RegExp(
      r'Div-([A-Z])',
    ).firstMatch(text);

    if (match == null) return null;

    return match.group(1);
  }

  static String? extractRoom(
    String text,
  ) {
    final match = RegExp(
      r'L-\d+',
    ).firstMatch(text);

    if (match == null) return null;

    return match.group(0);
  }

  static List<String> extractSubjects(
    String text,
  ) {
    const subjects = [
      'CAL',
      'PHY',
      'EOB',
      'CTPS',
      'EE',
      'EGD',
      'EEP',
      'IKS',
      'ES',
    ];

    final found = <String>{};

    final upper =
        text.toUpperCase();

    for (final subject in subjects) {
      if (upper.contains(subject)) {
        found.add(subject);
      }
    }

    return found.toList()
      ..sort();
  }

  static Future<void> saveSubjects({
    required String division,
    required List<String> subjects,
  }) async {
    await db
        .collection('divisions')
        .doc(division)
        .set({
      'subjects': subjects,
    }, SetOptions(merge: true));
  }

  static Future<void> importDemoTimetable({
    required String division,
    required String room,
  }) async {
    final timetable = {
      'Monday': [
        ['CAL', '9:00 AM - 10:00 AM'],
        ['EGD', '10:00 AM - 11:00 AM'],
        ['PHY', '11:00 AM - 12:00 PM'],
        ['EOB', '2:00 PM - 3:00 PM'],
      ],
      'Tuesday': [
        ['CAL', '10:00 AM - 11:00 AM'],
        ['CTPS', '2:00 PM - 3:00 PM'],
        ['PHY', '3:00 PM - 4:00 PM'],
      ],
      'Wednesday': [
        ['EE', '9:00 AM - 10:00 AM'],
        ['CAL', '10:00 AM - 11:00 AM'],
        ['EOB', '11:00 AM - 12:00 PM'],
      ],
      'Thursday': [
        ['CAL', '9:00 AM - 10:00 AM'],
        ['CTPS', '2:00 PM - 3:00 PM'],
      ],
      'Friday': [
        ['ES', '9:00 AM - 10:00 AM'],
        ['CAL', '3:00 PM - 4:00 PM'],
      ],
    };

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
          'subject': lecture[0],
          'time': lecture[1],
          'room': room,
          'cancelled': false,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      }
    }
  }
}