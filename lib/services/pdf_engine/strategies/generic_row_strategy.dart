import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/parsed_row.dart';
import '../parser_config.dart';
import '../components/row_clusterer.dart';
import '../components/header_detector.dart';
import '../components/column_mapper.dart';
import '../components/cell_reconstructor.dart';
import 'parser_strategy.dart';

class GenericRowStrategy implements ParserStrategy {
  @override
  String get name => ParserConfig.versionGeneric;

  @override
  List<ParsedRow> parsePage(List<TextLine> pageLines) {
    // The generic strategy uses the exact same pipeline but can be extended later 
    // to handle missing headers or fallback column guesses.
    final pageWords = pageLines.expand((l) => l.wordCollection).toList();
    final rows = RowClusterer.clusterWords(pageWords);
    final List<ParsedRow> parsedRows = [];
    
    Map<String, List<double>>? activeZones;

    for (final row in rows) {
      final headerCols = HeaderDetector.detectHeaders(row);
      if (headerCols != null) {
        activeZones = ColumnMapper.mapZones(headerCols);
        continue;
      }

      if (activeZones != null) {
        parsedRows.add(CellReconstructor.reconstruct(row, activeZones));
      }
    }
    
    return parsedRows;
  }
}
