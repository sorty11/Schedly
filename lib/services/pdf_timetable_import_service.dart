import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import '../timetable_manager.dart';

class PdfTimetableImportService {
  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static Future<String> extractText(Uint8List pdfBytes) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    String text = '';
    for (int i = 0; i < document.pages.count; i++) {
      text += PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      text += '\n';
    }
    document.dispose();
    return text;
  }

  static String? extractDivision(String text) {
    final match = RegExp(r'Div-([A-Z0-9]+)').firstMatch(text);
    if (match == null) return null;
    return match.group(1);
  }

  static Future<Map<String, List<TimetableEntry>>> parseTimetable(
    Uint8List pdfBytes,
    String defaultRoom,
  ) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    final extractor = PdfTextExtractor(document);
    
    final lines = extractor.extractTextLines(startPageIndex: 0, endPageIndex: 0);
    final words = <TextWord>[];
    for (final line in lines) {
      words.addAll(line.wordCollection);
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
          timeString: '${_formatTime(fromTime)} - ${_formatTime(toTime)}',
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

    final rawTimetable = <String, List<Map<String, String>>>{
      'Monday': [], 'Tuesday': [], 'Wednesday': [], 'Thursday': [], 'Friday': [], 'Saturday': [],
    };

    for (final day in dayBoundaries) {
      rawTimetable[day.name] = [];
    }

    // Pass 1: Identify Lunch Break slots
    final isLunchSlot = List<bool>.filled(slots.length, false);
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final subjectsInSlot = <String>[];
      
      for (final day in dayBoundaries) {
        final cellWords = words.where((w) {
          final cx = w.bounds.center.dx;
          if (cx < day.xStart || cx >= day.xEnd) return false;
          final wordTop = w.bounds.top;
          final wordBottom = w.bounds.bottom;
          final overlapStart = wordTop > slot.yStart ? wordTop : slot.yStart;
          final overlapEnd = wordBottom < slot.yEnd ? wordBottom : slot.yEnd;
          return (overlapEnd - overlapStart) > (w.bounds.height * 0.3);
        }).toList();
        
        if (cellWords.isNotEmpty) {
           subjectsInSlot.add(cellWords.map((w) => w.text).join(' ').trim().toLowerCase());
        }
      }
      
      final cleanSubjects = subjectsInSlot
          .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((s) => s.isNotEmpty && s != 'free slot')
          .toList();
          
      if (cleanSubjects.isNotEmpty) {
         bool isMergedBreak = cleanSubjects.every((s) => 
            s.contains('library') || s.contains('lunch') || s.contains('break')
         );
         if (isMergedBreak) {
             isLunchSlot[i] = true;
         }
      }
    }

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

        String subjectText = '';
        if (isLunchSlot[i]) {
          subjectText = 'Lunch Break';
        } else if (cellWords.isNotEmpty) {
          cellWords.sort((a, b) {
            if ((a.bounds.center.dy - b.bounds.center.dy).abs() > 3) {
              return a.bounds.center.dy.compareTo(b.bounds.center.dy);
            }
            return a.bounds.center.dx.compareTo(b.bounds.center.dx);
          });
          subjectText = cellWords.map((w) => w.text).join(' ').trim();
        }

        if (subjectText.isEmpty) subjectText = 'Free Slot';
        
        final dayList = rawTimetable[day.name]!;
        bool isFragment(String text) {
          final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
          if (t.isEmpty || t == 'free slot') return false;
          final cleaned = t
              .replaceAll('lab', '').replaceAll('practical', '').replaceAll('tutorial', '').replaceAll('batch', '')
              .replaceAll(RegExp(r'[a-d][1-9]'), '')
              .replaceAll(RegExp(r'[\(\)/,&-]'), '').trim();
          return cleaned.isEmpty || cleaned.length <= 2; 
        }

        if (dayList.isNotEmpty) {
          final prevSubject = dayList.last['subject']!;
          bool shouldMerge = false;
          String mergedSubject = subjectText;
          
          if (prevSubject == subjectText) {
            shouldMerge = true;
          } else if (isFragment(subjectText) && prevSubject != 'Free Slot') {
            shouldMerge = true;
            final newParts = subjectText.split(' ');
            String finalSubject = prevSubject;
            for (var part in newParts) {
              if (!finalSubject.toLowerCase().contains(part.toLowerCase())) {
                finalSubject += ' $part';
              }
            }
            mergedSubject = finalSubject.trim();
          } else if (prevSubject == 'Free Slot' && subjectText == 'Free Slot') {
            shouldMerge = true;
          }

          if (shouldMerge) {
            final prevTime = dayList.last['time']!;
            dayList.last['time'] = '${prevTime.split('-')[0].trim()} - ${slot.timeString.split('-')[1].trim()}';
            dayList.last['subject'] = mergedSubject;
          } else {
            dayList.add({'subject': subjectText, 'time': slot.timeString, 'room': defaultRoom});
          }
        } else {
          dayList.add({'subject': subjectText, 'time': slot.timeString, 'room': defaultRoom});
        }
      }
    }

    // Convert to strongly typed TimetableEntry models
    final structuredTimetable = <String, List<TimetableEntry>>{};
    
    for (final day in rawTimetable.keys) {
      structuredTimetable[day] = [];
      for (final raw in rawTimetable[day]!) {
        final entries = buildEntriesFromText(raw['subject']!, raw['time']!, raw['room']!);
        structuredTimetable[day]!.addAll(entries);
      }
    }

    return structuredTimetable;
  }

  static List<TimetableEntry> buildEntriesFromText(String text, String timeString, String room) {
    text = text.trim();
    if (text.isEmpty || text.toLowerCase() == 'free slot') return [];

    final l = text.toLowerCase();
    EventCategory category = EventCategory.academic;
    
    // Strict non-academic classification
    if (l.contains('lunch') || l.contains('break')) {
      category = EventCategory.lunch;
    } else if (l.contains('mentor') || l.contains('doubts clearing')) {
      category = EventCategory.mentoring;
    } else if (l.contains('sport')) {
      category = EventCategory.sports;
    } else if (l.contains('library')) {
      category = EventCategory.library;
    } else if (l.contains('activity') || l.contains('club')) {
      category = EventCategory.activity;
    } else if (l.contains('holiday')) {
      category = EventCategory.holiday;
    } else if (l.contains('event') || l.contains('industrial visit') || l.contains('workshop') || l.contains('seminar') || l.contains('admin')) {
      category = EventCategory.event;
    }

    String subjectPart = text;
    String batchPart = 'Whole Class';
    
    // Support optional space before parenthesis
    final batchMatch = RegExp(r'\s*\((.*?)\)').firstMatch(text);
    if (batchMatch != null) {
      batchPart = batchMatch.group(1) ?? 'Whole Class';
      subjectPart = text.replaceAll(batchMatch.group(0)!, '').trim();
    }

    final subjects = subjectPart.split(RegExp(r'[/,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    
    if (category == EventCategory.academic && subjects.length > 1) {
      final lastSubj = subjects.last.toLowerCase();
      if (lastSubj.contains('lab') && !subjects.first.toLowerCase().contains('lab')) {
        for (int i = 0; i < subjects.length - 1; i++) {
           if (!subjects[i].toLowerCase().contains('lab')) {
             subjects[i] = '${subjects[i]} LAB';
           }
        }
      }
      if ((lastSubj.endsWith('_t') || lastSubj.contains('tutorial')) && !subjects.first.toLowerCase().contains('tutorial') && !subjects.first.toLowerCase().endsWith('_t')) {
        for (int i = 0; i < subjects.length - 1; i++) {
           if (!subjects[i].toLowerCase().endsWith('_t') && !subjects[i].toLowerCase().contains('tutorial')) {
             subjects[i] = '${subjects[i]}_T';
           }
        }
      }
    }

    final batches = batchPart.split(RegExp(r'[/,]')).map((b) => b.trim()).where((b) => b.isNotEmpty).toList();

    final entries = <TimetableEntry>[];
    
    final startMins = TimetableManager.parseTime(timeString.split('-')[0].trim());
    final endMins = TimetableManager.parseTime(timeString.split('-')[1].trim());
    int duration = endMins - startMins;
    if (duration < 0) duration += 24 * 60;
    
    final maxLen = subjects.length > batches.length ? subjects.length : batches.length;
    
    for (int i = 0; i < maxLen; i++) {
       String s = subjects.isNotEmpty ? subjects[i % subjects.length] : 'Unknown';
       final b = batches.isNotEmpty ? batches[i % batches.length] : 'Whole Class';
       
       String component = 'Theory';
       if (category == EventCategory.academic) {
         final ls = s.toLowerCase();
         if (ls.contains('lab') || ls.contains('practical')) {
           component = 'Lab';
           s = s.replaceAll(RegExp(r'\bLAB\b', caseSensitive: false), '').replaceAll(RegExp(r'\bPRACTICAL\b', caseSensitive: false), '').trim();
         } else if (ls.endsWith('_t') || ls.contains('tutorial')) {
           component = 'Tutorial';
           s = s.replaceAll(RegExp(r'_T\b', caseSensitive: false), '').replaceAll(RegExp(r'\bTUTORIAL\b', caseSensitive: false), '').trim();
         }
         // Clean up trailing underscores or hyphens left behind
         s = s.replaceAll(RegExp(r'[_:\-]+$'), '').trim();
       }
       
       entries.add(TimetableEntry(
         id: db.collection('timetables').doc().id, // Random auto-id
         subject: s,
         component: component,
         category: category,
         batch: b,
         startTime: startMins,
         endTime: endMins,
         durationMinutes: duration,
         room: room,
         status: 'active',
       ));
    }
    return entries;
  }

  static String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hour = int.tryParse(parts[0]) ?? 0;
    if (hour >= 8 && hour <= 11) {
      return '$time AM';
    } else {
      return '$time PM';
    }
  }

  static Future<void> saveImportedTimetable({
    required String division,
    required Map<String, List<TimetableEntry>> timetable,
  }) async {
    for (final day in timetable.keys) {
      final dayCollection = db.collection('timetables').doc(division).collection(day);
      final existing = await dayCollection.get();
      
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }

      for (final entry in timetable[day]!) {
        await dayCollection.doc(entry.id).set(entry.toFirestore());
      }
    }
  }
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