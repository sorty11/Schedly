import '../models/parsed_row.dart';
import '../parser_config.dart';

class RowValidator {
  /// Validates a row based on its confidence and required fields.
  /// Returns a reason string if invalid, or null if valid.
  static String? validate(ParsedRow row) {
    if (row.confidence < ParserConfig.minAcceptableConfidence) {
      return 'Low confidence (${row.confidence})';
    }

    final date = row.cells['date']?.trim() ?? '';
    if (date.isEmpty) {
      return 'Missing date';
    }

    final status = row.cells['status']?.trim() ?? row.cells['attendance']?.trim() ?? '';
    if (status.isEmpty) {
      return 'Missing status';
    }

    return null; // Valid
  }
}
