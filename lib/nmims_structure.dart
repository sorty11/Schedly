class NMIMSStructure {
  static const List<String> academicYears = [
    'First Year',
    'Second Year',
    'Third Year',
    'Fourth Year',
  ];

  static const List<String> branches = [
    'CE',
    'CSDS',
    'IT',
    'AI',
    'Data Science',
    'MBA Tech CE',
    'MBA Tech AI',
  ];

  /// Returns suggested divisions based on the branch
  static List<String> getDivisionsForBranch(String branch) {
    switch (branch) {
      case 'CE':
        return ['C', 'D'];
      case 'CSDS':
        return ['A', 'B'];
      case 'IT':
        return ['E'];
      case 'AI':
        return ['F'];
      case 'Data Science':
        return ['G'];
      case 'MBA Tech CE':
        return ['M1'];
      case 'MBA Tech AI':
        return ['M2'];
      default:
        return ['A', 'B', 'C', 'D', 'E'];
    }
  }

  /// Automatically infers the branch given a division
  static String? getBranchForDivision(String division) {
    switch (division) {
      case 'A':
      case 'B':
        return 'CSDS';
      case 'C':
      case 'D':
        return 'CE';
      case 'E':
        return 'IT';
      case 'F':
        return 'AI';
      case 'G':
        return 'Data Science';
      case 'M1':
        return 'MBA Tech CE';
      case 'M2':
        return 'MBA Tech AI';
      default:
        return null;
    }
  }
}
