import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  final file = File(r'assets\ZSVKM_STUDENT_ATTENDANCE (14).pdf');
  final bytes = await file.readAsBytes();
  final document = PdfDocument(inputBytes: bytes);
  final extractor = PdfTextExtractor(document);
  final words = extractor.extractTextLines(startPageIndex: 0).expand((l) => l.wordCollection).toList();
  
  for (final w in words) {
    if (w.bounds.center.dy < 120) {
      print('HEADER WORD: \${w.text} at cx=\${w.bounds.center.dx}');
    }
  }
}
