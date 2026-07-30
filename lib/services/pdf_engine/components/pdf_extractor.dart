import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractor {
  static List<TextLine> extractLines(Uint8List bytes, int pageIndex) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final lines = extractor.extractTextLines(startPageIndex: pageIndex);
    return lines;
  }
  
  static int getPageCount(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    return document.pages.count;
  }
}
