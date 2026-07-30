import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../parser_config.dart';

class HeaderDetector {
  static String _clean(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Detects if a row is a header row by using a weighted confidence score.
  /// Returns a map of standard column keys to their horizontal centers (dx), or null if not a header.
  static Map<String, double>? detectHeaders(List<TextWord> row) {
    int confidence = 0;
    final Map<String, double> detectedColumns = {};

    final List<TextWord> sorted = List.from(row)..sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));
    
    // Normalize vertically wrapped headers by merging words that are horizontally very close
    final List<(String, double)> normalizedTokens = [];
    for (final word in sorted) {
      if (normalizedTokens.isNotEmpty) {
        final prev = normalizedTokens.last;
        // If dx is within 20 points, they are likely stacked vertically
        if ((word.bounds.center.dx - prev.$2).abs() < 20.0) {
          normalizedTokens[normalizedTokens.length - 1] = ('${prev.$1}${word.text}', prev.$2);
          continue;
        }
      }
      normalizedTokens.add((word.text, word.bounds.center.dx));
    }

    for (final token in normalizedTokens) {
      final text = _clean(token.$1);

      for (final entry in ParserConfig.headerSynonyms.entries) {
        final key = entry.key; // e.g., 'course', 'date'
        final weight = ParserConfig.headerWeights[key] ?? 0;
        
        // If we haven't found this column yet
        if (!detectedColumns.containsKey(key)) {
          for (final syn in entry.value) {
            final cleanedSyn = _clean(syn);
            if (text == cleanedSyn || text.contains(cleanedSyn)) {
              confidence += weight;
              detectedColumns[key] = token.$2;
              break; // Found matching synonym for this column
            }
          }
        }
      }
    }

    if (confidence >= ParserConfig.requiredHeaderConfidence && 
        detectedColumns.containsKey('course') && 
        detectedColumns.containsKey('status')) {
      return detectedColumns;
    }

    return null;
  }
}
