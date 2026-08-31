import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class RawFixtureRow {
  final int srNo;
  final String courseName;
  final String date;
  final String startTime;
  final String endTime;
  final String status;

  const RawFixtureRow(
    this.srNo,
    this.courseName,
    this.date,
    this.startTime,
    this.endTime,
    this.status,
  );
}

void main() {
  test('Generate 3 Golden Fixture PDFs', () async {
    final fixturesDir = Directory('test/fixtures');
    if (!fixturesDir.existsSync()) {
      fixturesDir.createSync(recursive: true);
    }

    final allRows = _getAll180Rows();

    // PDF 1: 6 pages, 94 rows. Duration: From 13.07.2026 to 05.08.2026.
    // Rows 84-89 are P, 90-94 are NU.
    final pdf1Rows = allRows.take(94).map((r) {
      if (r.srNo >= 84 && r.srNo <= 89) {
        return RawFixtureRow(
          r.srNo,
          r.courseName,
          r.date,
          r.startTime,
          r.endTime,
          'P',
        );
      } else if (r.srNo >= 90 && r.srNo <= 94) {
        return RawFixtureRow(
          r.srNo,
          r.courseName,
          r.date,
          r.startTime,
          r.endTime,
          'NU',
        );
      }
      return r;
    }).toList();

    _createPdf(
      filePath: 'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY (1).pdf',
      duration: 'From 13.07.2026 to 05.08.2026',
      rows: pdf1Rows,
      totalPages: 6,
    );

    // PDF 2: 6 pages, 94 rows. Duration: From 14.07.2025 to 05.08.2026.
    // Rows 84-94 are ALL NU.
    final pdf2Rows = allRows.take(94).map((r) {
      if (r.srNo >= 84 && r.srNo <= 94) {
        return RawFixtureRow(
          r.srNo,
          r.courseName,
          r.date,
          r.startTime,
          r.endTime,
          'NU',
        );
      }
      return r;
    }).toList();

    _createPdf(
      filePath: 'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY.pdf',
      duration: 'From 14.07.2025 to 05.08.2026',
      rows: pdf2Rows,
      totalPages: 6,
    );

    // PDF 3: 9 pages, 180 rows. Duration: From 13.07.2026 to 30.08.2026.
    // Rows 84-94 are P.
    final pdf3Rows = allRows.map((r) {
      if (r.srNo >= 84 && r.srNo <= 94) {
        return RawFixtureRow(
          r.srNo,
          r.courseName,
          r.date,
          r.startTime,
          r.endTime,
          'P',
        );
      }
      return r;
    }).toList();

    _createPdf(
      filePath: 'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf',
      duration: 'From 13.07.2026 to 30.08.2026',
      rows: pdf3Rows,
      totalPages: 9,
    );

    print('Golden Fixtures generated successfully in test/fixtures/');
  });
}

void _createPdf({
  required String filePath,
  required String duration,
  required List<RawFixtureRow> rows,
  required int totalPages,
}) {
  final doc = PdfDocument();
  final font = PdfStandardFont(PdfFontFamily.helvetica, 8);
  final boldFont = PdfStandardFont(
    PdfFontFamily.helvetica,
    9,
    style: PdfFontStyle.bold,
  );
  final titleFont = PdfStandardFont(
    PdfFontFamily.helvetica,
    10,
    style: PdfFontStyle.bold,
  );

  // Page 1: 14 rows (1..14)
  // Page 2: 23 rows (15..37)
  // Page 3: 23 rows (38..60)
  // Page 4: 23 rows (61..83)
  // Page 5: rows 84..94 (PDF 1&2) or 84..106 (PDF 3)
  // Page 6: footer page (PDF 1&2) or rows 107..129 (PDF 3)
  // Page 7: rows 130..152 (PDF 3)
  // Page 8: rows 153..175 (PDF 3)
  // Page 9: rows 176..180 (PDF 3) + footer

  int rowIdx = 0;

  for (int p = 1; p <= totalPages; p++) {
    final page = doc.pages.add();

    // Top: Page X of Y
    page.graphics.drawString(
      'Page $p of $totalPages',
      font,
      bounds: const Rect.fromLTWH(260, 770, 100, 15),
    );

    double currentY = 0;

    if (p == 1) {
      // Header
      page.graphics.drawString(
        "SVKM'S NMIMS Mukesh Patel Schl of Tech Mgt & Engg-Mum, Hyderaba",
        titleFont,
        bounds: const Rect.fromLTWH(50, 40, 500, 20),
      );
      page.graphics.drawString(
        "Student Name",
        font,
        bounds: const Rect.fromLTWH(30, 65, 120, 15),
      );
      page.graphics.drawString(
        "AYAAN PATEL",
        boldFont,
        bounds: const Rect.fromLTWH(180, 65, 200, 15),
      );

      page.graphics.drawString(
        "Student Number",
        font,
        bounds: const Rect.fromLTWH(30, 85, 120, 15),
      );
      page.graphics.drawString(
        "70022500789",
        boldFont,
        bounds: const Rect.fromLTWH(180, 85, 200, 15),
      );

      page.graphics.drawString(
        "Roll No.",
        font,
        bounds: const Rect.fromLTWH(30, 105, 120, 15),
      );
      page.graphics.drawString(
        "D789",
        boldFont,
        bounds: const Rect.fromLTWH(180, 105, 200, 15),
      );

      page.graphics.drawString(
        "Academic Year & Academic Session",
        font,
        bounds: const Rect.fromLTWH(30, 125, 150, 15),
      );
      page.graphics.drawString(
        "2026-2027, Semester III",
        boldFont,
        bounds: const Rect.fromLTWH(180, 125, 200, 15),
      );

      page.graphics.drawString(
        "Program Name",
        font,
        bounds: const Rect.fromLTWH(30, 145, 120, 15),
      );
      page.graphics.drawString(
        "B Tech (Computer Engineering)",
        boldFont,
        bounds: const Rect.fromLTWH(180, 145, 250, 15),
      );

      page.graphics.drawString(
        "Attendance Report Duration :",
        font,
        bounds: const Rect.fromLTWH(30, 175, 150, 15),
      );
      page.graphics.drawString(
        duration,
        boldFont,
        bounds: const Rect.fromLTWH(180, 175, 250, 15),
      );

      currentY = 205;
    } else {
      currentY = 25;
    }

    // Only draw table header if there are rows on this page
    final rowsForThisPage = _getRowsCountForPage(p, totalPages, rows.length);
    if (rowsForThisPage > 0) {
      // Table Header
      page.graphics.drawString(
        "Sr No.",
        boldFont,
        bounds: Rect.fromLTWH(30, currentY, 30, 15),
      );
      page.graphics.drawString(
        "Course Name",
        boldFont,
        bounds: Rect.fromLTWH(100, currentY, 150, 15),
      );
      page.graphics.drawString(
        "Date",
        boldFont,
        bounds: Rect.fromLTWH(335, currentY, 50, 15),
      );
      page.graphics.drawString(
        "Start Time",
        boldFont,
        bounds: Rect.fromLTWH(400, currentY, 60, 15),
      );
      page.graphics.drawString(
        "End Time",
        boldFont,
        bounds: Rect.fromLTWH(470, currentY, 60, 15),
      );
      page.graphics.drawString(
        "Attendance",
        boldFont,
        bounds: Rect.fromLTWH(540, currentY, 50, 15),
      );

      currentY += 24;

      for (int i = 0; i < rowsForThisPage && rowIdx < rows.length; i++) {
        final r = rows[rowIdx++];
        page.graphics.drawString(
          "${r.srNo}",
          font,
          bounds: Rect.fromLTWH(30, currentY, 25, 15),
        );
        page.graphics.drawString(
          r.courseName,
          font,
          bounds: Rect.fromLTWH(65, currentY, 255, 15),
        );
        page.graphics.drawString(
          r.date,
          font,
          bounds: Rect.fromLTWH(330, currentY, 60, 15),
        );
        page.graphics.drawString(
          r.startTime,
          font,
          bounds: Rect.fromLTWH(400, currentY, 60, 15),
        );
        page.graphics.drawString(
          r.endTime,
          font,
          bounds: Rect.fromLTWH(470, currentY, 65, 15),
        );
        page.graphics.drawString(
          r.status,
          font,
          bounds: Rect.fromLTWH(555, currentY, 20, 15),
        );

        currentY += 22;
      }
    }

    // Footer lines on the page where table ends or on final page
    if (rowIdx >= rows.length || p == totalPages) {
      currentY += 15;
      page.graphics.drawString(
        "P - Present : A - Absent : E - Exemption : L - Late Admission : NU - Not Updated",
        font,
        bounds: Rect.fromLTWH(40, currentY, 500, 15),
      );
      currentY += 15;
      page.graphics.drawString(
        "Above data is viewed as per attendance data in the SAP system. Please contact college admin staff for any attendance related query.",
        font,
        bounds: Rect.fromLTWH(40, currentY, 520, 25),
      );
      currentY += 30;
      page.graphics.drawString(
        "PS: This is a system-generated report and does not require a signature.",
        font,
        bounds: Rect.fromLTWH(40, currentY, 500, 15),
      );
    }
  }

  final bytes = doc.saveSync();
  doc.dispose();
  File(filePath).writeAsBytesSync(bytes);
}

int _getRowsCountForPage(int page, int totalPages, int totalRows) {
  if (totalRows == 94) {
    // 6 page report
    switch (page) {
      case 1:
        return 14;
      case 2:
        return 23;
      case 3:
        return 23;
      case 4:
        return 23;
      case 5:
        return 11;
      case 6:
        return 0; // blank/footer page
      default:
        return 0;
    }
  } else {
    // 9 page report (180 rows)
    switch (page) {
      case 1:
        return 14;
      case 2:
        return 23;
      case 3:
        return 23;
      case 4:
        return 23;
      case 5:
        return 23; // 84..106
      case 6:
        return 23; // 107..129
      case 7:
        return 23; // 130..152
      case 8:
        return 23; // 153..175
      case 9:
        return 5; // 176..180
      default:
        return 0;
    }
  }
}

List<RawFixtureRow> _getAll180Rows() {
  return [
    RawFixtureRow(
      1,
      "Discrete MathematicsT4 CE Sem III",
      "Jul 13, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      2,
      "Signals and SystemsP4 CE Sem III C2",
      "Jul 13, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      3,
      "Signals and SystemsP4 CE Sem III C2",
      "Jul 13, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      4,
      "Principles of Economics and Managemen T4",
      "Jul 13, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      5,
      "Computer Organization and Architectur T4",
      "Jul 13, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      6,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Jul 13, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      7,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Jul 14, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      8,
      "Principles of Economics and Managemen T4",
      "Jul 14, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      9,
      "Discrete MathematicsT4 CE Sem III",
      "Jul 14, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      10,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Jul 14, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      11,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Jul 14, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      12,
      "Computer Organization and Architectur T4",
      "Jul 14, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      13,
      "Signals and SystemsT4 CE Sem III",
      "Jul 15, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      14,
      "Principles of Economics and Managemen T4",
      "Jul 15, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      15,
      "Computer Organization and Architectur T4",
      "Jul 15, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      16,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Jul 15, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      17,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Jul 15, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      18,
      "Signals and SystemsT4 CE Sem III",
      "Jul 16, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      19,
      "Probability and StatisticsT4 CE Sem III",
      "Jul 16, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      20,
      "Probability and StatisticsP4 CE III C2",
      "Jul 16, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      21,
      "Probability and StatisticsP4 CE III C2",
      "Jul 16, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      22,
      "Probability and StatisticsT4 CE Sem III",
      "Jul 17, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      23,
      "PROGRAMMING WITH PYTHONT4 CE Sem III",
      "Jul 17, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      24,
      "Discrete MathematicsU4 CE Sem III C2",
      "Jul 17, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      25,
      "Technical CommunicationU4 CE Sem III C2",
      "Jul 17, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      26,
      "Discrete MathematicsT4 CE Sem III",
      "Jul 20, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      27,
      "Signals and SystemsP4 CE Sem III C2",
      "Jul 20, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      28,
      "Signals and SystemsP4 CE Sem III C2",
      "Jul 20, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      29,
      "Principles of Economics and Managemen T4",
      "Jul 20, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      30,
      "Computer Organization and Architectur T4",
      "Jul 20, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      31,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Jul 20, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      32,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Jul 21, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      33,
      "Principles of Economics and Managemen T4",
      "Jul 21, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      34,
      "Discrete MathematicsT4 CE Sem III",
      "Jul 21, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      35,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Jul 21, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      36,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Jul 21, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      37,
      "Computer Organization and Architectur T4",
      "Jul 21, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      38,
      "Signals and SystemsT4 CE Sem III",
      "Jul 22, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      39,
      "Principles of Economics and Managemen T4",
      "Jul 22, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      40,
      "Computer Organization and Architectur T4",
      "Jul 22, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      41,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Jul 22, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      42,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Jul 22, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      43,
      "Signals and SystemsT4 CE Sem III",
      "Jul 23, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      44,
      "Probability and StatisticsT4 CE Sem III",
      "Jul 23, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      45,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Jul 23, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "A",
    ),
    RawFixtureRow(
      46,
      "Probability and StatisticsP4 CE III C2",
      "Jul 23, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      47,
      "Probability and StatisticsP4 CE III C2",
      "Jul 23, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      48,
      "Probability and StatisticsT4 CE Sem III",
      "Jul 24, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      49,
      "PROGRAMMING WITH PYTHONT4 CE Sem III",
      "Jul 24, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      50,
      "Discrete MathematicsU4 CE Sem III C2",
      "Jul 24, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      51,
      "Technical CommunicationU4 CE Sem III C2",
      "Jul 24, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      52,
      "Discrete MathematicsT4 CE Sem III",
      "Jul 25, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      53,
      "Signals and SystemsP4 CE Sem III C2",
      "Jul 25, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      54,
      "Signals and SystemsP4 CE Sem III C2",
      "Jul 25, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      55,
      "Computer Organization and Architectur T4",
      "Jul 25, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      56,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Jul 25, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      57,
      "Principles of Economics and Managemen T4",
      "Jul 27, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      58,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Jul 28, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      59,
      "Principles of Economics and Managemen T4",
      "Jul 28, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      60,
      "Discrete MathematicsT4 CE Sem III",
      "Jul 28, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      61,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Jul 28, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      62,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Jul 28, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      63,
      "Computer Organization and Architectur T4",
      "Jul 28, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      64,
      "Signals and SystemsT4 CE Sem III",
      "Jul 29, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      65,
      "Principles of Economics and Managemen T4",
      "Jul 29, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      66,
      "Computer Organization and Architectur T4",
      "Jul 29, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      67,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Jul 29, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      68,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Jul 29, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      69,
      "Signals and SystemsT4 CE Sem III",
      "Jul 30, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      70,
      "Probability and StatisticsT4 CE Sem III",
      "Jul 30, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      71,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Jul 30, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      72,
      "Probability and StatisticsP4 CE III C2",
      "Jul 30, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      73,
      "Probability and StatisticsP4 CE III C2",
      "Jul 30, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      74,
      "Probability and StatisticsT4 CE Sem III",
      "Jul 31, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      75,
      "PROGRAMMING WITH PYTHONT4 CE Sem III",
      "Jul 31, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      76,
      "Discrete MathematicsU4 CE Sem III C2",
      "Jul 31, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      77,
      "Technical CommunicationU4 CE Sem III C2",
      "Jul 31, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      78,
      "Discrete MathematicsT4 CE Sem III",
      "Aug 3, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      79,
      "Signals and SystemsP4 CE Sem III C2",
      "Aug 3, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      80,
      "Signals and SystemsP4 CE Sem III C2",
      "Aug 3, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      81,
      "Principles of Economics and Managemen T4",
      "Aug 3, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      82,
      "Computer Organization and Architectur T4",
      "Aug 3, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      83,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 3, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      84,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 4, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      85,
      "Principles of Economics and Managemen T4",
      "Aug 4, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      86,
      "Discrete MathematicsT4 CE Sem III",
      "Aug 4, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      87,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Aug 4, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      88,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Aug 4, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      89,
      "Computer Organization and Architectur T4",
      "Aug 4, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      90,
      "Signals and SystemsT4 CE Sem III",
      "Aug 5, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      91,
      "Principles of Economics and Managemen T4",
      "Aug 5, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      92,
      "Computer Organization and Architectur T4",
      "Aug 5, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      93,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Aug 5, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      94,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Aug 5, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      95,
      "Signals and SystemsT4 CE Sem III",
      "Aug 6, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      96,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 6, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      97,
      "PROGRAMMING WITH PYTHONT4 CE Sem III",
      "Aug 6, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      98,
      "Probability and StatisticsP4 CE III C2",
      "Aug 6, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      99,
      "Probability and StatisticsP4 CE III C2",
      "Aug 6, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      100,
      "Discrete MathematicsT4 CE Sem III",
      "Aug 7, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      101,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 7, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      102,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 7, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      103,
      "Discrete MathematicsU4 CE Sem III C2",
      "Aug 7, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      104,
      "Technical CommunicationU4 CE Sem III C2",
      "Aug 7, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      105,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 7, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      106,
      "Discrete MathematicsT4 CE Sem III",
      "Aug 10, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      107,
      "Signals and SystemsP4 CE Sem III C2",
      "Aug 10, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      108,
      "Signals and SystemsP4 CE Sem III C2",
      "Aug 10, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      109,
      "Computer Organization and Architectur T4",
      "Aug 10, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      110,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 10, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      111,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 11, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      112,
      "Discrete MathematicsT4 CE Sem III",
      "Aug 11, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      113,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Aug 11, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      114,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Aug 11, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      115,
      "Computer Organization and Architectur T4",
      "Aug 11, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      116,
      "Signals and SystemsT4 CE Sem III",
      "Aug 12, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      117,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 12, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      118,
      "Computer Organization and Architectur T4",
      "Aug 12, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      119,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Aug 12, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      120,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Aug 12, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      121,
      "Signals and SystemsT4 CE Sem III",
      "Aug 13, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      122,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 13, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      123,
      "PROGRAMMING WITH PYTHONT4 CE Sem III",
      "Aug 13, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      124,
      "Probability and StatisticsP4 CE III C2",
      "Aug 13, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      125,
      "Probability and StatisticsP4 CE III C2",
      "Aug 13, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      126,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 14, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      127,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 14, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      128,
      "Discrete MathematicsU4 CE Sem III C2",
      "Aug 14, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      129,
      "Technical CommunicationU4 CE Sem III C2",
      "Aug 14, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      130,
      "Signals and SystemsP4 CE Sem III C2",
      "Aug 17, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      131,
      "Signals and SystemsP4 CE Sem III C2",
      "Aug 17, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      132,
      "Computer Organization and Architectur T4",
      "Aug 17, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      133,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 17, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      134,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 18, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      135,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Aug 18, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      136,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Aug 18, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      137,
      "Computer Organization and Architectur T4",
      "Aug 18, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      138,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 19, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      139,
      "Computer Organization and Architectur T4",
      "Aug 19, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      140,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Aug 19, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      141,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Aug 19, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      142,
      "Prompt Engineering for ChatGPTT4 CE-III",
      "Aug 19, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      143,
      "Prompt Engineering for ChatGPTT4 CE-III",
      "Aug 19, 2026",
      "4:00:00 PM",
      "4:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      144,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 20, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      145,
      "PROGRAMMING WITH PYTHONT4 CE Sem III",
      "Aug 20, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      146,
      "Probability and StatisticsP4 CE III C2",
      "Aug 20, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      147,
      "Probability and StatisticsP4 CE III C2",
      "Aug 20, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "A",
    ),
    RawFixtureRow(
      148,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 21, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      149,
      "Signals and SystemsT4 CE Sem III",
      "Aug 21, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      150,
      "Discrete MathematicsU4 CE Sem III C2",
      "Aug 21, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      151,
      "Technical CommunicationU4 CE Sem III C2",
      "Aug 21, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      152,
      "Discrete MathematicsT4 CE Sem III",
      "Aug 24, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "A",
    ),
    RawFixtureRow(
      153,
      "Signals and SystemsP4 CE Sem III C2",
      "Aug 24, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      154,
      "Signals and SystemsP4 CE Sem III C2",
      "Aug 24, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      155,
      "Principles of Economics and Managemen T4",
      "Aug 24, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      156,
      "Computer Organization and Architectur T4",
      "Aug 24, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      157,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 24, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      158,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 25, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      159,
      "Principles of Economics and Managemen T4",
      "Aug 25, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      160,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Aug 25, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      161,
      "PROGRAMMING WITH PYTHONP4 CE Sem III C2",
      "Aug 25, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      162,
      "Computer Organization and Architectur T4",
      "Aug 25, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      163,
      "Principles of Economics and Managemen T4",
      "Aug 25, 2026",
      "4:00:00 PM",
      "4:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      164,
      "Signals and SystemsT4 CE Sem III",
      "Aug 26, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      165,
      "Principles of Economics and Managemen T4",
      "Aug 26, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      166,
      "Computer Organization and Architectur T4",
      "Aug 26, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      167,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Aug 26, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      168,
      "DATA STRUCTURES AND ALGORITHMS LABP4 C2",
      "Aug 26, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      169,
      "Prompt Engineering for ChatGPTT4 CE-III",
      "Aug 26, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      170,
      "Signals and SystemsT4 CE Sem III",
      "Aug 27, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      171,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 27, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      172,
      "PROGRAMMING WITH PYTHONT4 CE Sem III",
      "Aug 27, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      173,
      "Probability and StatisticsP4 CE III C2",
      "Aug 27, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      174,
      "Probability and StatisticsP4 CE III C2",
      "Aug 27, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      175,
      "Prompt Engineering for ChatGPTT4 CE-III",
      "Aug 27, 2026",
      "3:00:00 PM",
      "3:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      176,
      "Discrete MathematicsT4 CE Sem III",
      "Aug 28, 2026",
      "9:15:00 AM",
      "10:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      177,
      "Probability and StatisticsT4 CE Sem III",
      "Aug 28, 2026",
      "10:15:00 AM",
      "11:14:59 AM",
      "P",
    ),
    RawFixtureRow(
      178,
      "DATA STRUCTURES AND ALGORITHMST4 CE III",
      "Aug 28, 2026",
      "11:15:00 AM",
      "12:14:59 PM",
      "P",
    ),
    RawFixtureRow(
      179,
      "Discrete MathematicsU4 CE Sem III C2",
      "Aug 28, 2026",
      "1:00:00 PM",
      "1:59:59 PM",
      "P",
    ),
    RawFixtureRow(
      180,
      "Technical CommunicationU4 CE Sem III C2",
      "Aug 28, 2026",
      "2:00:00 PM",
      "2:59:59 PM",
      "P",
    ),
  ];
}
