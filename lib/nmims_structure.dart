class ProgramInfo {
  final String id;
  final String name;
  final Map<String, List<String>> semestersByYear;

  const ProgramInfo({
    required this.id,
    required this.name,
    this.semestersByYear = const {},
  });
}

class SchoolInfo {
  final String id;
  final String name;
  final List<ProgramInfo> programs;
  final List<String> academicYears;

  const SchoolInfo({
    required this.id,
    required this.name,
    this.programs = const [],
    this.academicYears = const [],
  });
}

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

  static const List<String> solYears = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
  ];

  static const Map<String, List<String>> solSemestersByYear = {
    '1st Year': ['Semester I', 'Semester II'],
    '2nd Year': ['Semester III', 'Semester IV'],
    '3rd Year': ['Semester V', 'Semester VI'],
    '4th Year': ['Semester VII', 'Semester VIII'],
    '5th Year': ['Semester IX', 'Semester X'],
    // Alias mappings for 'Third Year' style naming
    'First Year': ['Semester I', 'Semester II'],
    'Second Year': ['Semester III', 'Semester IV'],
    'Third Year': ['Semester V', 'Semester VI'],
    'Fourth Year': ['Semester VII', 'Semester VIII'],
    'Fifth Year': ['Semester IX', 'Semester X'],
  };

  static final List<SchoolInfo> schools = [
    SchoolInfo(
      id: 'STME',
      name: 'School of Technology Management & Engineering',
      academicYears: academicYears,
      programs: branches.map((b) => ProgramInfo(id: b, name: b)).toList(),
    ),
    const SchoolInfo(
      id: 'SOL',
      name: 'School of Law',
      academicYears: solYears,
      programs: [
        ProgramInfo(
          id: 'BALLB',
          name: 'B.A. LL.B. (Hons.)',
          semestersByYear: solSemestersByYear,
        ),
        ProgramInfo(
          id: 'BBALLB',
          name: 'B.B.A. LL.B. (Hons.)',
          semestersByYear: solSemestersByYear,
        ),
      ],
    ),
    const SchoolInfo(
      id: 'SPTM',
      name: 'School of Pharmacy & Technology Management',
      academicYears: academicYears,
      programs: [],
    ),
    const SchoolInfo(
      id: 'SBM',
      name: 'School of Business Management',
      academicYears: ['First Year', 'Second Year'],
      programs: [],
    ),
    const SchoolInfo(
      id: 'SOC',
      name: 'School of Commerce',
      academicYears: ['First Year', 'Second Year', 'Third Year'],
      programs: [],
    ),
  ];

  static SchoolInfo getSchool(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) {
      return schools.first;
    }
    final upper = schoolId.trim().toUpperCase();
    return schools.firstWhere(
      (s) => s.id.toUpperCase() == upper,
      orElse: () => schools.first,
    );
  }

  /// Centrally generates a collision-safe sectionId while strictly preserving legacy STME format.
  static String generateSectionId({
    String? school,
    required String year,
    required String branchOrProgram,
    String? semester,
    required String division,
  }) {
    final cleanYear = year.trim().replaceAll(' ', '');
    final cleanDiv = division.trim();
    final effectiveSchool = (school == null || school.trim().isEmpty) ? 'STME' : school.trim().toUpperCase();

    if (effectiveSchool == 'STME') {
      final cleanBranch = branchOrProgram.trim().replaceAll(' ', '');
      return '${cleanYear}_${cleanBranch}_$cleanDiv';
    }

    final cleanProg = _sanitizeProgramCode(branchOrProgram);
    if (semester != null && semester.trim().isNotEmpty) {
      final cleanSem = semester.trim().replaceAll(' ', '');
      return '${effectiveSchool}_${cleanYear}_${cleanProg}_${cleanSem}_$cleanDiv';
    }
    return '${effectiveSchool}_${cleanYear}_${cleanProg}_$cleanDiv';
  }

  static String _sanitizeProgramCode(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('B.B.A. LL.B') || upper.contains('BBALLB') || upper.contains('BBA LLB')) return 'BBALLB';
    if (upper.contains('B.A. LL.B') || upper.contains('BALLB') || upper.contains('BA LLB')) return 'BALLB';
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return cleaned.isNotEmpty ? cleaned : 'PROG';
  }
}

