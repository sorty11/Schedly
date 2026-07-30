import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/parsed_row.dart';
import '../parser_config.dart';
import 'parser_strategy.dart';

class SvkmHybridStrategy implements ParserStrategy {
  @override
  String get name => 'SVKM_HYBRID';

  @override
  List<ParsedRow> parsePage(List<TextLine> pageLines) {
    final List<ParsedRow> parsedRows = [];

    // Regex to find dates like "Jan 7, 2026" or "07-01-2026" or "07/01/2026"
    final dateRegExp = RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},\s+\d{4}\b|\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b');
    
    // Regex for time "11:15:00 AM" or "11:15 AM"
    final timeRegExp = RegExp(r'\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM|am|pm)');

    for (final line in pageLines) {
      final text = line.text;
      if (text.isEmpty) continue;

      final dateMatch = dateRegExp.firstMatch(text);
      if (dateMatch == null) continue; // Not a data row

      final courseStr = text.substring(0, dateMatch.start).trim();
      final dateStr = dateMatch.group(0)!;
      final restOfLine = text.substring(dateMatch.end).trim();

      final timeMatches = timeRegExp.allMatches(restOfLine).toList();
      String startStr = '';
      String endStr = '';
      if (timeMatches.isNotEmpty) {
        startStr = timeMatches[0].group(0)!;
        if (timeMatches.length > 1) {
          endStr = timeMatches[1].group(0)!;
        }
      }

      // Status is typically the very last token
      final tokens = restOfLine.split(RegExp(r'\s+'));
      String statusStr = tokens.isNotEmpty ? tokens.last : '';

      final cells = {
        'course': courseStr,
        'date': dateStr,
        'start': startStr,
        'end': endStr,
        'status': statusStr,
      };

      final row = ParsedRow(cells);
      row.rawText = text;
      // We set header matched to true so ConfidenceEngine rewards it, 
      // since the regex anchor conceptually plays the same role.
      row.isHeaderMatched = true; 
      
      parsedRows.add(row);
    }

    return parsedRows;
  }
}
