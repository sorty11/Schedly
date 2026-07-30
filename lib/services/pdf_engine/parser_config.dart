class ParserConfig {
  // Adaptive Clustering
  static const double textHeightMultiplier = 1.2;
  static const double fallbackClusterThreshold = 6.0;

  // Header Detection
  static const int requiredHeaderConfidence = 60;
  static const Map<String, int> headerWeights = {
    'course': 30,
    'date': 20,
    'start': 15,
    'end': 15,
    'attendance': 20,
    'status': 20,
  };

  // Synonyms Dictionary
  static const Map<String, List<String>> headerSynonyms = {
    'course': ['course', 'subject', 'paper', 'module', 'course name', 'subject name'],
    'date': ['date', 'lecture date', 'session date'],
    'start': ['start', 'start time', 'from'],
    'end': ['end', 'end time', 'to'],
    'attendance': ['attendance', 'status', 'present', 'result'],
  };

  // Confidence Engine (Additive System: Max 100)
  static const int scoreHeaderMatched = 15;
  static const int scoreCourseExtracted = 15;
  static const int scoreDateValid = 20;
  static const int scoreTimeValid = 20;
  static const int scoreStatusValid = 15;
  static const int scoreSubjectPerfectMatch = 15;
  static const int scoreNoMergeRequired = 10;
  
  static const int minAcceptableConfidence = 50;

  // Validation
  static const List<String> validPresentTokens = ['p', 'present'];
  static const List<String> validAbsentTokens = ['a', 'absent'];

  // Strategies
  static const String versionSvkmV1 = 'SVKM_V1';
  static const String versionGeneric = 'GENERIC_ROW';
}
