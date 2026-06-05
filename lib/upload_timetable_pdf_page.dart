import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/pdf_timetable_import_service.dart';
import 'pdf_import_preview_page.dart';

class UploadTimetablePdfPage
    extends StatefulWidget {
  const UploadTimetablePdfPage({
    super.key,
  });

  @override
  State<UploadTimetablePdfPage>
      createState() =>
          _UploadTimetablePdfPageState();
}

class _UploadTimetablePdfPageState
    extends State<
        UploadTimetablePdfPage> {
  bool loading = false;

  List<String> detectedSubjects = [];

  String? division;
  String? room;

  Future<void> _pickPdf() async {
    setState(() {
      loading = true;
    });

    try {
      final result =
          await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null) {
        setState(() {
          loading = false;
        });
        return;
      }

      final Uint8List bytes =
          result.files.first.bytes!;

      final text =
          await PdfTimetableImportService
              .extractText(bytes);

      final subjects =
          PdfTimetableImportService
              .extractSubjects(text);

      final pdfDivision =
          PdfTimetableImportService
              .extractDivision(text);

      final pdfRoom =
          PdfTimetableImportService
              .extractRoom(text);

      final prefs =
          await SharedPreferences.getInstance();

      final selectedDivision =
          prefs.getString(
        'selected_division',
      );

      if (selectedDivision != null) {
        await PdfTimetableImportService
            .saveSubjects(
          division: selectedDivision,
          subjects: subjects,
        );
      }

      setState(() {
        detectedSubjects = subjects;
        division = pdfDivision;
        room = pdfRoom;
        loading = false;
      });

      if (!mounted) return;

      final previewTimetable = {
        'Monday': [
          {
            'subject': 'CAL',
            'time':
                '9:15 AM - 10:15 AM',
            'room':
                pdfRoom ?? 'L-19',
          },
          {
            'subject': 'EGD',
            'time':
                '10:15 AM - 11:15 AM',
            'room':
                pdfRoom ?? 'L-19',
          },
          {
            'subject': 'PHY',
            'time':
                '11:15 AM - 12:15 PM',
            'room':
                pdfRoom ?? 'L-19',
          },
        ],
        'Tuesday': [
          {
            'subject': 'CAL',
            'time':
                '10:15 AM - 11:15 AM',
            'room':
                pdfRoom ?? 'L-19',
          },
          {
            'subject': 'CTPS',
            'time':
                '2:00 PM - 3:00 PM',
            'room':
                pdfRoom ?? 'L-19',
          },
        ],
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfImportPreviewPage(
            timetable:
                previewTimetable,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Import failed: $e',
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
        title: const Text(
          'Upload Timetable PDF',
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed:
                    loading
                        ? null
                        : _pickPdf,
                icon: const Icon(
                  Icons.upload_file,
                ),
                label: const Text(
                  'Select PDF',
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            if (loading)
              const CircularProgressIndicator(),

            if (division != null)
              Card(
                child: ListTile(
                  leading:
                      const Icon(
                    Icons.groups,
                  ),
                  title: Text(
                    'Division: $division',
                  ),
                ),
              ),

            if (room != null)
              Card(
                child: ListTile(
                  leading:
                      const Icon(
                    Icons.room,
                  ),
                  title: Text(
                    'Room: $room',
                  ),
                ),
              ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Detected Subjects',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Expanded(
              child: ListView.builder(
                itemCount:
                    detectedSubjects
                        .length,
                itemBuilder:
                    (context, index) {
                  return Card(
                    child: ListTile(
                      leading:
                          const Icon(
                        Icons.book,
                      ),
                      title: Text(
                        detectedSubjects[
                            index],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}