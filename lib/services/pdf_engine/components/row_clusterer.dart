import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../parser_config.dart';

class RowClusterer {
  /// Clusters words into rows using an adaptive threshold based on average text height.
  static List<List<TextWord>> clusterWords(List<TextWord> words) {
    if (words.isEmpty) return [];

    // 1. Calculate Adaptive Threshold
    double totalHeight = 0;
    for (final w in words) {
      totalHeight += w.bounds.height;
    }
    double avgHeight = totalHeight / words.length;
    double threshold = avgHeight * ParserConfig.textHeightMultiplier;
    
    // Fallback if height calculation fails (e.g. height is 0)
    if (threshold <= 0) threshold = ParserConfig.fallbackClusterThreshold;

    // 2. Sort vertically
    words.sort((a, b) => a.bounds.center.dy.compareTo(b.bounds.center.dy));

    final List<List<TextWord>> rows = [];
    List<TextWord> currentRow = [words.first];

    for (int i = 1; i < words.length; i++) {
      final word = words[i];
      final prevWord = currentRow.last;

      if ((word.bounds.center.dy - prevWord.bounds.center.dy).abs() < threshold) {
        currentRow.add(word);
      } else {
        rows.add(currentRow);
        currentRow = [word];
      }
    }
    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }

    // 3. Sort each row horizontally
    for (final row in rows) {
      row.sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));
    }

    return rows;
  }
}
