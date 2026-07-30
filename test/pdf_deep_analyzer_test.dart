import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Deep PDF Analysis', () async {
    final file = File('assets/ZSVKM_STUDENT_ATTENDANCE (14).pdf');
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    
    print('==================================================');
    print('PDF DEEP ANALYZER REPORT');
    print('Total Pages: ${document.pages.count}');
    print('==================================================\n');
    
    // Analyze First Page Header & Structure
    print('--- PAGE 1 STRUCTURE ---');
    final firstPageLines = extractor.extractTextLines(startPageIndex: 0, endPageIndex: 0);
    for (int i = 0; i < 20 && i < firstPageLines.length; i++) {
      final line = firstPageLines[i];
      print('L$i [Y:${line.bounds.top.toStringAsFixed(1)}]: ${line.text}');
    }

    // Analyze Random Middle Page for Multi-page behaviour
    if (document.pages.count > 1) {
      final middlePage = document.pages.count ~/ 2;
      print('\n--- PAGE $middlePage STRUCTURE (Checking for Repeating Headers) ---');
      final middlePageLines = extractor.extractTextLines(startPageIndex: middlePage, endPageIndex: middlePage);
      for (int i = 0; i < 15 && i < middlePageLines.length; i++) {
        final line = middlePageLines[i];
        print('L$i [Y:${line.bounds.top.toStringAsFixed(1)}]: ${line.text}');
      }
    }

    // Analyze Last Page for Footers & Overall Percentages
    final lastPageIdx = document.pages.count - 1;
    print('\n--- LAST PAGE STRUCTURE (Checking for Footers/Summaries) ---');
    final lastPageLines = extractor.extractTextLines(startPageIndex: lastPageIdx, endPageIndex: lastPageIdx);
    final startIdx = lastPageLines.length > 20 ? lastPageLines.length - 20 : 0;
    for (int i = startIdx; i < lastPageLines.length; i++) {
      final line = lastPageLines[i];
      print('L$i [Y:${line.bounds.top.toStringAsFixed(1)}]: ${line.text}');
    }

    // Analyze all text to find patterns
    print('\n--- PATTERN DETECTION ---');
    int totalLectures = 0;
    int presentCount = 0;
    int absentCount = 0;
    final subjects = <String>{};

    final dateRegex = RegExp(r'^[A-Z][a-z]{2}\s\d{1,2},\s\d{4}$');
    
    for (int p = 0; p < document.pages.count; p++) {
      final lines = extractor.extractTextLines(startPageIndex: p, endPageIndex: p);
      for (int i = 0; i < lines.length; i++) {
        final text = lines[i].text.trim();
        
        // Find Date Anchor
        if (dateRegex.hasMatch(text)) {
          totalLectures++;
          
          if (i > 0) subjects.add(lines[i-1].text.trim());
          if (i + 3 < lines.length) {
            final status = lines[i+3].text.trim();
            if (status == 'P') presentCount++;
            else if (status == 'A') absentCount++;
          }
        }
      }
    }

    print('Total Lectures Found via Date Anchor: $totalLectures');
    print('Present: $presentCount');
    print('Absent: $absentCount');
    print('Unique Subjects Extracted:');
    for (final s in subjects) {
      print(' - $s');
    }
    
    print('\n==================================================');
  });
}
