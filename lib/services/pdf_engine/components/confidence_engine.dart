import '../models/parsed_row.dart';
import '../parser_config.dart';

class ConfidenceEngine {
  /// Applies additive scoring to the row. Max is 100.
  static void scoreRow(ParsedRow row) {
    int score = 0;

    if (row.isHeaderMatched) score += ParserConfig.scoreHeaderMatched;
    if (row.cells['course']?.isNotEmpty == true) score += ParserConfig.scoreCourseExtracted;
    
    // Simple date regex for typical DD/MM/YYYY or DD-MM-YYYY
    final dateRaw = row.cells['date']?.trim() ?? '';
    if (RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(dateRaw)) {
      score += ParserConfig.scoreDateValid;
    }

    final start = row.cells['start']?.trim() ?? '';
    final end = row.cells['end']?.trim() ?? '';
    if (start.isNotEmpty && end.isNotEmpty) {
      score += ParserConfig.scoreTimeValid;
    }

    final status = row.cells['status']?.trim().toLowerCase() ?? 
                   row.cells['attendance']?.trim().toLowerCase() ?? '';
    if (ParserConfig.validPresentTokens.contains(status) || 
        ParserConfig.validAbsentTokens.contains(status)) {
      score += ParserConfig.scoreStatusValid;
    }
    
    if (!row.isMerged) {
      score += ParserConfig.scoreNoMergeRequired;
    }

    row.confidence = score.clamp(0, 100);
  }
}
