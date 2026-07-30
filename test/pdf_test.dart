import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/services/pdf_attendance_import_service.dart';

void main() {
  test('PDF Parser Test', () async {
    final file = File('assets/ZSVKM_STUDENT_ATTENDANCE (14).pdf');
    final bytes = await file.readAsBytes();
    
    print('Starting import...');
    
    final result = await PdfAttendanceImportService.parseAttendancePdf(
      pdfBytes: bytes,
      division: 'A',
      canonicals: [], 
    );
    
    print('--- FINAL RESULT ---');
    if (result.studentInfo != null) {
      print('Student: \${result.studentInfo!.name} (\${result.studentInfo!.program})');
    }
    print('Lectures Extracted: \${result.logs.length}');
  });
}
