import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:schedly/services/pdf_attendance_import_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final file = File('assets/ZSVKM_STUDENT_ATTENDANCE (14).pdf');
  final bytes = await file.readAsBytes();
  
  print('Starting import...');
  
  try {
    final result = await PdfAttendanceImportService.parseAttendancePdf(
      pdfBytes: bytes,
      division: 'A',
      canonicals: [], // empty known subjects to just test extraction
    );
    
    print('--- FINAL RESULT ---');
    if (result.studentInfo != null) {
      print('Student: \${result.studentInfo!.name} (\${result.studentInfo!.program})');
    }
    print('Lectures Extracted: \${result.logs.length}');
  } catch (e) {
    print('Error: \$e');
  }
}
