import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('print headers', () async {
    final file = File(r'assets\ZSVKM_STUDENT_ATTENDANCE (14).pdf');
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final words = extractor
        .extractTextLines(startPageIndex: 0)
        .expand((l) => l.wordCollection)
        .toList();

    for (final w in words) {
      if (w.bounds.center.dy > 250 && w.bounds.center.dy < 400) {
        print(
          'WORD: ${w.text} at cx=${w.bounds.center.dx}, dy=${w.bounds.center.dy}',
        );
      }
    }
  });
}
