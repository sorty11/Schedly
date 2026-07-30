class ParsedRow {
  final Map<String, String> cells;
  int confidence = 0; // Starts at 0, additive scoring
  bool isMerged = false;
  bool isHeaderMatched = false; // Flag to indicate if this row was mapped to valid headers
  
  String? rejectionReason;
  String? rawText; // The original text line, for debugging

  // For subject matching tracking
  String? matchedSubjectCode;
  String? matchedSubjectComponent;

  ParsedRow(this.cells);
}
