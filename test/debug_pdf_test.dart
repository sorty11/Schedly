import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Extract PDF', () async {
    final file = File(r'assets\ZSVKM_STUDENT_ATTENDANCE (14).pdf');
    final bytes = await file.readAsBytes();
    
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    
    for (int p = 0; p < 1; p++) { // Just test page 1
      final lines = extractor.extractTextLines(startPageIndex: p, endPageIndex: p);
      final words = <TextWord>[];
      for (final line in lines) {
        words.addAll(line.wordCollection);
      }
      
      final rowCandidates = <double>[];
      for (final w in words) {
        if (w.bounds.center.dy > 100) {
          rowCandidates.add(w.bounds.center.dy);
        }
      }
      rowCandidates.sort();
      
      final rowCenters = <double>[];
      for (final y in rowCandidates) {
        if (rowCenters.isEmpty || (y - rowCenters.last).abs() > 6) {
          rowCenters.add(y);
        }
      }

      print('Found ${rowCenters.length} rows.');
      double? srNoX, courseNameX, dateX, startTimeX, endTimeX, attendanceX;
      for (final word in words) {
        final t = word.text.toLowerCase();
        final cx = word.bounds.center.dx;
        
        if ((t == 'sr' || t == 'no.') && cx < 100) srNoX = cx;
        else if (t == 'course' && cx > 100 && cx < 300) courseNameX = cx;
        else if (t == 'date' && cx > 250 && cx < 400) dateX = cx;
        else if (t == 'start' && cx > 350 && cx < 500) startTimeX = cx;
        else if (t == 'end' && cx > 450 && cx < 600) endTimeX = cx;
        else if ((t == 'attenda' || t == 'nce' || t == 'attendance') && cx > 500) attendanceX = cx;
      }

      srNoX ??= 30.0;
      courseNameX ??= 150.0;
      dateX ??= 350.0;
      startTimeX ??= 450.0;
      endTimeX ??= 550.0;
      attendanceX ??= 650.0;

      print('srNoX: $srNoX, courseNameX: $courseNameX, dateX: $dateX, startTimeX: $startTimeX, endTimeX: $endTimeX, attendanceX: $attendanceX');

      final colSrNo = [0.0, (srNoX + courseNameX) / 2];
      final colCourse = [(srNoX + courseNameX) / 2, (courseNameX + dateX) / 2];
      final colDate = [(courseNameX + dateX) / 2, (dateX + startTimeX) / 2];
      final colStart = [(dateX + startTimeX) / 2, (startTimeX + endTimeX) / 2];
      final colEnd = [(startTimeX + endTimeX) / 2, (endTimeX + attendanceX) / 2];
      final colStatus = [(endTimeX + attendanceX) / 2, 9999.0];

      print('colCourse: $colCourse');
      print('colDate: $colDate');

      for (final y in rowCenters) {
        final rowWords = words.where((w) => (w.bounds.center.dy - y).abs() <= 6).toList();
        rowWords.sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));
        
        String srNo = '', course = '', dateStr = '', start = '', end = '', status = '';
        for (final w in rowWords) {
          final cx = w.bounds.center.dx;
          final t = w.text;
          
          if (cx >= colSrNo[0] && cx < colSrNo[1]) srNo += '$t ';
          else if (cx >= colCourse[0] && cx < colCourse[1]) course += '$t ';
          else if (cx >= colDate[0] && cx < colDate[1]) dateStr += '$t ';
          else if (cx >= colStart[0] && cx < colStart[1]) start += '$t ';
          else if (cx >= colEnd[0] && cx < colEnd[1]) end += '$t ';
          else if (cx >= colStatus[0] && cx < colStatus[1]) status += '$t ';
        }
        
        print('DATE: [$dateStr] COURSE: [$course] START: [$start] END: [$end] STATUS: [$status]');
      }
    }
  });
}
