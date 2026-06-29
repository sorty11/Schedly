import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Debug Spatial Parser 3', () async {
    final file = File('assets/sample_timetable.pdf');
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final lines = extractor.extractTextLines(startPageIndex: 0, endPageIndex: 0);
    
    final words = <TextWord>[];
    for (final line in lines) {
      if (line.wordCollection != null) {
        words.addAll(line.wordCollection!);
      }
    }
    document.dispose();

    final timeRegex = RegExp(r'^\d{1,2}:\d{2}$');
    final rowCandidates = <double>[];
    
    for (final word in words) {
      if (timeRegex.hasMatch(word.text.trim())) {
        rowCandidates.add(word.bounds.center.dy);
      }
    }
    
    rowCandidates.sort();
    final rowCenters = <double>[];
    for (final y in rowCandidates) {
      if (rowCenters.isEmpty || (y - rowCenters.last).abs() > 5) {
        rowCenters.add(y);
      }
    }
    
    final slots = <_TimeSlot>[];
    for (int i = 0; i < rowCenters.length; i++) {
      final timeWordsOnRow = words
          .where((w) => timeRegex.hasMatch(w.text.trim()) && (w.bounds.center.dy - rowCenters[i]).abs() < 5)
          .toList()
        ..sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));

      if (timeWordsOnRow.length >= 2) {
        final fromTime = timeWordsOnRow[0].text;
        final toTime = timeWordsOnRow[1].text;

        final yStart = i == 0 ? rowCenters[0] - 5 : (rowCenters[i - 1] + rowCenters[i]) / 2;
        final yEnd = i == rowCenters.length - 1 ? rowCenters[i] + 5 : (rowCenters[i] + rowCenters[i + 1]) / 2;

        slots.add(_TimeSlot(
          yStart: yStart,
          yEnd: yEnd,
          timeString: fromTime + ' - ' + toTime,
        ));
      }
    }

    final dayBoundaries = [
      _DayColumn('Monday', 250, 350),
      _DayColumn('Tuesday', 350, 420),
      _DayColumn('Wednesday', 420, 510),
      _DayColumn('Thursday', 510, 590),
      _DayColumn('Friday', 590, 660),
      _DayColumn('Saturday', 660, 730),
    ];

    final timetable = <String, List<Map<String, String>>>{
      'Monday': [], 'Tuesday': [], 'Wednesday': [], 'Thursday': [], 'Friday': [], 'Saturday': [],
    };

    final ignoredWords = ['Lunch', 'Break', 'Mentor', 'Contact', 'Doubts', 'Clearing', 'Session', 'Clubs', '&', 'Activities'];

    for (final day in dayBoundaries) {
      for (int i = 0; i < slots.length; i++) {
        final slot = slots[i];
        
        final cellWords = words.where((w) {
          final cx = w.bounds.center.dx;
          if (cx < day.xStart || cx >= day.xEnd) return false;

          final wordTop = w.bounds.top;
          final wordBottom = w.bounds.bottom;
          final overlapStart = wordTop > slot.yStart ? wordTop : slot.yStart;
          final overlapEnd = wordBottom < slot.yEnd ? wordBottom : slot.yEnd;
          final overlapHeight = overlapEnd - overlapStart;
          
          return overlapHeight > (w.bounds.height * 0.3);
        }).toList();

        if (cellWords.isNotEmpty) {
          cellWords.sort((a, b) {
            if ((a.bounds.center.dy - b.bounds.center.dy).abs() > 3) {
              return a.bounds.center.dy.compareTo(b.bounds.center.dy);
            }
            return a.bounds.center.dx.compareTo(b.bounds.center.dx);
          });

          final subjectText = cellWords.map((w) => w.text).join(' ').trim();
          bool shouldIgnore = ignoredWords.any((ignore) => subjectText.contains(ignore));
          
          if (subjectText.isNotEmpty && !shouldIgnore) {
            final dayList = timetable[day.name]!;
            
            // Note: because we are processing slot by slot, if a multi-hour lab overlapped multiple slots, 
            // it will be detected in BOTH slots! So if we see the same subject string as the last one, 
            // we can merge the times.
            if (dayList.isNotEmpty && dayList.last['subject'] == subjectText) {
              final prevTime = dayList.last['time']!;
              dayList.last['time'] = prevTime.split('-')[0].trim() + ' - ' + slot.timeString.split('-')[1].trim();
            } else {
              dayList.add({
                'subject': subjectText,
                'time': slot.timeString,
                'room': 'L-20',
              });
            }
          }
        }
      }
    }
    
    print("\n==== TIMETABLE OUTPUT ====");
    for (final day in timetable.keys) {
      print(">> $day");
      for (final lecture in timetable[day]!) {
        print("   ${lecture['time']} : ${lecture['subject']}");
      }
    }
  });
}

class _TimeSlot {
  final double yStart;
  final double yEnd;
  final String timeString;
  _TimeSlot({required this.yStart, required this.yEnd, required this.timeString});
}

class _DayColumn {
  final String name;
  final double xStart;
  final double xEnd;
  _DayColumn(this.name, this.xStart, this.xEnd);
}
