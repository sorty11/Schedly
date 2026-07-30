import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../models/attendance_log.dart';
import '../../models/batch_analytics.dart';
import 'parser_config.dart';
import 'models/parsed_row.dart';
import 'models/pdf_import_report.dart';
import 'models/pdf_import_result.dart';
import 'components/pdf_extractor.dart';
import 'components/fragment_merger.dart';
import 'components/confidence_engine.dart';
import 'components/row_validator.dart';
import 'components/subject_matcher.dart';
import 'strategies/parser_registry.dart';
import 'strategies/parser_strategy.dart';

class _IsolateArgs {
  final Uint8List bytes;
  final String division;
  final List<String> knownSubjects;
  final bool debugMode;

  _IsolateArgs({
    required this.bytes,
    required this.division,
    required this.knownSubjects,
    this.debugMode = false,
  });
}

class PdfImportService {
  /// Orchestrates the PDF parsing pipeline in a background isolate.
  static Future<PdfImportResult> parseAttendancePdf({
    required Uint8List pdfBytes,
    required String division,
    required List<SubjectAnalytics> analytics,
    bool debugMode = false,
  }) async {
    final knownSubjects = analytics.map((a) => a.subject).toList();
    final args = _IsolateArgs(
      bytes: pdfBytes,
      division: division,
      knownSubjects: knownSubjects,
      debugMode: debugMode,
    );
    return await compute(_parsePdfInIsolate, args);
  }
}

Future<PdfImportResult> _parsePdfInIsolate(_IsolateArgs args) async {
  final startTime = DateTime.now();
  final pagesCount = PdfExtractor.getPageCount(args.bytes);
  final List<String> warnings = [];

  // Extract lines page by page to avoid memory spikes
  final List<List<TextLine>> pagesLines = [];
  for (int i = 0; i < pagesCount; i++) {
    pagesLines.add(PdfExtractor.extractLines(args.bytes, i));
  }

  // Self-Healing Strategy Execution
  List<ParsedRow>? bestRows;
  ParserStrategy? bestStrategy;
  double bestScore = -1.0;

  for (final strategy in ParserRegistry.strategies) {
    if (args.debugMode) print('[Registry] Trying strategy: ${strategy.name}');
    
    final List<ParsedRow> candidateRows = [];
    for (final page in pagesLines) {
      candidateRows.addAll(strategy.parsePage(page));
    }

    // Quick score heuristic
    int totalConf = 0;
    for (final r in candidateRows) {
      // Very basic scoring before deep evaluation
      if (r.cells['date']?.isNotEmpty == true && r.cells['course']?.isNotEmpty == true) {
        totalConf += 50;
      }
    }
    double avgConf = candidateRows.isEmpty ? 0 : totalConf / candidateRows.length;

    if (avgConf > bestScore) {
      bestScore = avgConf;
      bestRows = candidateRows;
      bestStrategy = strategy;
    }
    
    // If it's a solid match, no need to fallback
    if (avgConf > 40) break;
  }

  final rowsToProcess = bestRows ?? [];
  final strategyName = bestStrategy?.name ?? ParserConfig.versionGeneric;

  if (args.debugMode) print('[Pipeline] Selected strategy: $strategyName with ${rowsToProcess.length} raw rows');

  // Fragment Merger
  final mergedCount = FragmentMerger.mergeFragments(rowsToProcess);
  if (args.debugMode) print('[FragmentMerger] Merged $mergedCount fragments');

  // Deep Validation & Matcher
  final matcher = SubjectMatcher(args.knownSubjects);
  final Set<String> intraPdfDedupeSet = {};
  
  final List<AttendanceLog> logs = [];
  int parsedSuccessfully = 0;
  int rejectedRows = 0;
  int duplicateRows = 0;
  int unknownSubjects = 0;
  
  int totalConfidence = 0;
  int lowestConfidence = 100;
  int highestConfidence = 0;
  
  final List<ParsedRow> rejectedRowDetails = [];

  for (final row in rowsToProcess) {
    ConfidenceEngine.scoreRow(row);
    
    final validationError = RowValidator.validate(row);
    if (validationError != null) {
      rejectedRows++;
      row.rejectionReason = validationError;
      warnings.add('Row rejected: $validationError');
      rejectedRowDetails.add(row);
      continue;
    }

    final dateStr = row.cells['date']!.trim();
    final courseStr = row.cells['course']!.trim();
    final startStr = row.cells['start']?.trim() ?? '';
    final statusStr = row.cells['status']?.trim() ?? row.cells['attendance']?.trim() ?? '';

    // Match Subject
    final matchResult = matcher.findBestMatch(courseStr);
    final matchedSub = matchResult.$1;
    final matchPenalty = matchResult.$2;

    row.confidence -= matchPenalty;
    if (row.confidence < ParserConfig.minAcceptableConfidence) {
      rejectedRows++;
      row.rejectionReason = 'Low confidence after subject match for $courseStr';
      warnings.add('Row rejected: ${row.rejectionReason}');
      rejectedRowDetails.add(row);
      continue;
    }

    if (matchedSub == null) {
      unknownSubjects++;
      row.matchedSubjectCode = courseStr; // Save original string
    } else {
      row.matchedSubjectCode = matchedSub;
    }
    
    row.matchedSubjectComponent = 'Theory';

    // Deduplication Key (Intra-PDF)
    final dedupeKey = '${args.division}_${dateStr}_${startStr}_${row.matchedSubjectCode}_Theory';
    if (intraPdfDedupeSet.contains(dedupeKey)) {
      duplicateRows++;
      warnings.add('Row ignored: Duplicate lecture found for ${row.matchedSubjectCode} on $dateStr');
      continue;
    }
    intraPdfDedupeSet.add(dedupeKey);

    // Build final log
    final statusNorm = ParserConfig.validPresentTokens.contains(statusStr.toLowerCase()) ? 'present' : 'absent';
    
    logs.add(AttendanceLog(
      id: dedupeKey,
      date: DateTime.now(), // Fallback, normally parsed from dateStr
      subjectCode: row.matchedSubjectCode!,
      rawSubjectText: courseStr,
      source: 'PDF',
      component: 'Theory',
      status: statusNorm,
      confidence: row.confidence >= 90 ? MatchConfidence.perfect 
                : row.confidence >= 70 ? MatchConfidence.normalized
                : matchedSub == null ? MatchConfidence.unmatched
                : MatchConfidence.fuzzy,
      startTime: 0,
      endTime: 0,
    ));

    parsedSuccessfully++;
    totalConfidence += row.confidence;
    if (row.confidence < lowestConfidence) lowestConfidence = row.confidence;
    if (row.confidence > highestConfidence) highestConfidence = row.confidence;
  }

  final processingTime = DateTime.now().difference(startTime).inMilliseconds;
  final avgConf = parsedSuccessfully == 0 ? 0.0 : totalConfidence / parsedSuccessfully;
  final successRate = rowsToProcess.isEmpty ? 0.0 : parsedSuccessfully / rowsToProcess.length;

  final report = PdfImportReport(
    versionDetected: strategyName,
    strategyUsed: strategyName,
    processingTimeMs: processingTime,
    pagesProcessed: pagesCount,
    totalRows: rowsToProcess.length + mergedCount, // Original pre-merge count
    parsedSuccessfully: parsedSuccessfully,
    rejectedRows: rejectedRows,
    mergedRows: mergedCount,
    duplicateRows: duplicateRows,
    unknownSubjects: unknownSubjects,
    averageConfidence: avgConf,
    lowestConfidence: parsedSuccessfully == 0 ? 0 : lowestConfidence,
    highestConfidence: parsedSuccessfully == 0 ? 0 : highestConfidence,
    successRate: successRate,
    warnings: warnings,
    rejectedRowDetails: rejectedRowDetails,
  );

  return PdfImportResult(logs: logs, report: report);
}
