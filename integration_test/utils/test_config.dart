class TestConfig {
  static const String studentEmail = String.fromEnvironment(
    'TEST_STUDENT_EMAIL',
    defaultValue: '',
  );
  static const String studentPassword = String.fromEnvironment(
    'TEST_STUDENT_PASSWORD',
    defaultValue: '',
  );

  static const String crEmail = String.fromEnvironment(
    'TEST_CR_EMAIL',
    defaultValue: '',
  );
  static const String crPassword = String.fromEnvironment(
    'TEST_CR_PASSWORD',
    defaultValue: '',
  );

  static const String srEmail = String.fromEnvironment(
    'TEST_SR_EMAIL',
    defaultValue: '',
  );
  static const String srPassword = String.fromEnvironment(
    'TEST_SR_PASSWORD',
    defaultValue: '',
  );

  static const String facultyEmail = String.fromEnvironment(
    'TEST_FACULTY_EMAIL',
    defaultValue: '',
  );
  static const String facultyPassword = String.fromEnvironment(
    'TEST_FACULTY_PASSWORD',
    defaultValue: '',
  );

  static const String testDivision = String.fromEnvironment(
    'TEST_DIVISION',
    defaultValue: 'SmokeTest_Division',
  );

  static bool get hasCredentials =>
      studentEmail.isNotEmpty &&
      crEmail.isNotEmpty &&
      srEmail.isNotEmpty &&
      facultyEmail.isNotEmpty;
}
