import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/parsed_row.dart';
import '../parser_config.dart';
import '../components/row_clusterer.dart';
import '../components/header_detector.dart';
import '../components/column_mapper.dart';
import '../components/cell_reconstructor.dart';
import 'parser_strategy.dart';

class SvkmV1Strategy implements ParserStrategy {
  @override
  String get name => ParserConfig.versionSvkmV1;

  @override
  List<ParsedRow> parsePage(List<TextLine> pageLines) {
    final pageWords = pageLines.expand((l) => l.wordCollection).toList();
    final rows = RowClusterer.clusterWords(pageWords);
    final List<ParsedRow> parsedRows = [];
    
    Map<String, List<double>>? activeZones;

    for (final row in rows) {
      // 1. Check for header
      final headerCols = HeaderDetector.detectHeaders(row);
      if (headerCols != null) {
        activeZones = ColumnMapper.mapZones(headerCols);
        continue;
      }

      // 2. If we have zones, parse the row
      if (activeZones != null) {
        final parsed = CellReconstructor.reconstruct(row, activeZones);
        
        // Minor SVKM V1 specific cleanup (e.g. they sometimes prefix with '* ')
        if (parsed.cells['course'] != null && parsed.cells['course']!.startsWith('* ')) {
          parsed.cells['course'] = parsed.cells['course']!.substring(2).trim();
        }

        parsedRows.add(parsed);
      }
    }
    
    return parsedRows;
  }
}
