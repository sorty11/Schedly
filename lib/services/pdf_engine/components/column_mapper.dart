class ColumnMapper {
  /// Defines column boundaries based on detected header centers.
  static Map<String, List<double>> mapZones(Map<String, double> detectedColumns) {
    final Map<String, List<double>> zones = {};
    
    // Sort columns left-to-right by their dx centers
    final sortedEntries = detectedColumns.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (int i = 0; i < sortedEntries.length; i++) {
      final current = sortedEntries[i];
      // Left bound: halfway to previous column, or 0 if first
      final double leftBound = i == 0 ? 0.0 : (current.value + sortedEntries[i - 1].value) / 2;
      // Right bound: halfway to next column, or infinity if last
      final double rightBound = i == sortedEntries.length - 1 
          ? double.infinity 
          : (current.value + sortedEntries[i + 1].value) / 2;

      zones[current.key] = [leftBound, rightBound];
    }
    return zones;
  }
}
