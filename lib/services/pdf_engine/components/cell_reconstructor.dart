import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/parsed_row.dart';

class CellReconstructor {
  /// Reconstructs cell texts by checking if word centers fall within column zones.
  static ParsedRow reconstruct(List<TextWord> rowWords, Map<String, List<double>> zones) {
    final Map<String, String> cells = {};
    // Initialize empty strings for all known zones
    for (final key in zones.keys) {
      cells[key] = '';
    }

    for (final word in rowWords) {
      final cx = word.bounds.center.dx;
      for (final entry in zones.entries) {
        final leftBound = entry.value[0];
        final rightBound = entry.value[1];
        if (cx >= leftBound && cx <= rightBound) {
          cells[entry.key] = '${cells[entry.key]} ${word.text}'.trim();
          break; // Assigned to this zone, move to next word
        }
      }
    }

    return ParsedRow(cells);
  }
}
