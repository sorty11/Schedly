import 'parsed_row.dart';

class PdfImportReport {
  final String versionDetected;
  final String strategyUsed;
  final int processingTimeMs;
  final int pagesProcessed;
  
  final int totalRows;
  final int parsedSuccessfully;
  final int rejectedRows;
  final int mergedRows;
  final int duplicateRows;
  final int unknownSubjects;

  final double averageConfidence;
  final int lowestConfidence;
  final int highestConfidence;
  final double successRate;

  final List<String> warnings;
  final List<ParsedRow> rejectedRowDetails; // Added to store detailed rejection logs

  PdfImportReport({
    required this.versionDetected,
    required this.strategyUsed,
    required this.processingTimeMs,
    required this.pagesProcessed,
    required this.totalRows,
    required this.parsedSuccessfully,
    required this.rejectedRows,
    required this.mergedRows,
    required this.duplicateRows,
    required this.unknownSubjects,
    required this.averageConfidence,
    required this.lowestConfidence,
    required this.highestConfidence,
    required this.successRate,
    required this.warnings,
    this.rejectedRowDetails = const [],
  });
}
