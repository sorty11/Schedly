import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/pdf_timetable_import_service.dart';
import 'pdf_import_preview_page.dart';
import 'models/event_category.dart';

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

      final text = await PdfTimetableImportService.extractText(bytes);
      final pdfDivision = PdfTimetableImportService.extractDivision(text);

      final previewTimetable = await PdfTimetableImportService.parseTimetable(bytes, 'L-19');
      
      final uniqueSubjects = <String>{};
      for (final entries in previewTimetable.values) {
        for (final e in entries) {
          if (e.category == EventCategory.academic) {
            uniqueSubjects.add(e.subject);
          }
        }
      }
      final subjects = uniqueSubjects.toList();

      final prefs = await SharedPreferences.getInstance();
      final selectedDivision = prefs.getString('section_id') ?? prefs.getString('selected_division');

      setState(() {
        detectedSubjects = subjects;
        division = pdfDivision;
        room = 'L-19';
        loading = false;
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfImportPreviewPage(
            timetable: previewTimetable,
            division: selectedDivision ?? pdfDivision ?? 'FY CSE A',
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Timetable'),
        scrolledUnderElevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Import PDF',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload the official college timetable PDF. We will automatically parse subjects, timings, and rooms.',
              style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), height: 1.5),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GestureDetector(
                onTap: loading ? null : _pickPdf,
                child: Container(
                  decoration: BoxDecoration(
                    color: loading ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: loading ? Theme.of(context).dividerColor.withValues(alpha: 0.1) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: Center(
                    child: loading
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 24),
                              Text('Extracting data...', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 16)),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      )
                                    ],
                                  ),
                                  child: Icon(Icons.cloud_upload_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
                                ),
                              const SizedBox(height: 24),
                              Text(
                                'Tap to select PDF',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Supports standard NMIMS format',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}