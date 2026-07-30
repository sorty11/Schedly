import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/parsed_row.dart';

abstract class ParserStrategy {
  String get name;
  
  /// Parses the text lines of a single page into structured rows.
  List<ParsedRow> parsePage(List<TextLine> pageLines);
}
