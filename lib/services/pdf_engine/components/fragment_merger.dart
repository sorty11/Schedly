import '../models/parsed_row.dart';

class FragmentMerger {
  /// Intelligently merges rows that are fragments (e.g. wrapped subject text).
  /// Modifies the list in place and returns the number of merged rows.
  static int mergeFragments(List<ParsedRow> rows) {
    if (rows.isEmpty) return 0;
    
    int mergedCount = 0;
    final List<ParsedRow> mergedList = [];
    
    for (int i = 0; i < rows.length; i++) {
      final current = rows[i];
      
      // Heuristic: If current row has empty date and status, but has text in course,
      // it's likely a wrapped fragment belonging to the previous row.
      final isFragment = current.cells['date']?.isEmpty == true &&
                         current.cells['status']?.isEmpty == true &&
                         (current.cells['course']?.isNotEmpty == true || current.cells['attendance']?.isNotEmpty == true);
                         
      if (isFragment && mergedList.isNotEmpty) {
        final previous = mergedList.last;
        // Merge course text
        if (current.cells['course'] != null && current.cells['course']!.isNotEmpty) {
          previous.cells['course'] = '${previous.cells['course']} ${current.cells['course']}'.trim();
        }
        previous.isMerged = true;
        mergedCount++;
      } else {
        mergedList.add(current);
      }
    }
    
    rows.clear();
    rows.addAll(mergedList);
    return mergedCount;
  }
}
