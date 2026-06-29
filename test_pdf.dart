import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  final file = File('assets/sample_timetable.pdf');
  final bytes = await file.readAsBytes();
  final document = PdfDocument(inputBytes: bytes);
  
  String text = '';
  for (int i = 0; i < document.pages.count; i++) {
    text += PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
    text += '\n';
  }
  document.dispose();
  
  print("==== PDF TEXT ====");
  print(text);
  print("==== END TEXT ====");
}
