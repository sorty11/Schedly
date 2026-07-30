import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('PDF Extraction', () async {
    final file = File('assets/ZSVKM_STUDENT_ATTENDANCE (14).pdf');
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    
    final text = extractor.extractText(startPageIndex: 0, endPageIndex: 0);
    print('--- PAGE 1 EXTRACTED TEXT ---');
    print(text);
    print('-----------------------------');

    final lines = extractor.extractTextLines(startPageIndex: 0, endPageIndex: 0);
    print('\n--- PAGE 1 LINES ---');
    for (int i = 0; i < 25 && i < lines.length; i++) {
      print('Line \$i: \${lines[i].text}');
    }
  });
}
