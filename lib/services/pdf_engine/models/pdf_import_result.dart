import '../../../models/attendance_log.dart';
import 'pdf_import_report.dart';

class PdfImportResult {
  final List<AttendanceLog> logs;
  final PdfImportReport report;

  PdfImportResult({
    required this.logs,
    required this.report,
  });
}
