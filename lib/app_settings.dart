import 'package:shared_preferences/shared_preferences.dart';

import 'user_roles.dart';

class AppSettings {
  static UserRole currentRole =
      UserRole.student;

  static String? srSubject;
  static String? srComponent;
  static String? srDivision; // Will be migrated to srSectionId eventually, but let's keep it simple for now or change to srSectionId
  static String? srSectionId;
  static String? srBatch;
  
  static String? studentName;
  static String? studentRollNo;
  
  static String? academicYear;
  static String? branch;
  static String? division;
  static String? sectionId;

  static Future<void> loadRole() async {
    final prefs =
        await SharedPreferences.getInstance();

    final role =
        prefs.getString('user_role');

    switch (role) {
      case 'cr':
        currentRole = UserRole.cr;
        break;

      case 'sr':
        currentRole = UserRole.sr;
        break;

      default:
        currentRole = UserRole.student;
    }
  }

  static Future<void> loadSRDetails() async {
    final prefs =
        await SharedPreferences.getInstance();

    srDivision =
        prefs.getString('sr_division');

    srSubject =
        prefs.getString('sr_subject');

    srComponent =
        prefs.getString('sr_component');
        
    srSectionId =
        prefs.getString('sr_section_id');

    srBatch =
        prefs.getString('sr_batch');
  }

  static Future<void> loadStudentDetails() async {
    final prefs = await SharedPreferences.getInstance();
    studentName = prefs.getString('student_name');
    studentRollNo = prefs.getString('student_roll_no');
    
    academicYear = prefs.getString('academic_year');
    branch = prefs.getString('branch');
    division = prefs.getString('division');
    sectionId = prefs.getString('section_id');
  }

  static Future<void> saveRole(
    UserRole role,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    currentRole = role;

    await prefs.setString(
      'user_role',
      role.name,
    );
  }

  static Future<void> saveSRDetails({
    required String division,
    required String subject,
    String? component,
    String? batch,
  }) async {
    final prefs =
        await SharedPreferences.getInstance();

    srDivision = division;
    srSubject = subject;
    srComponent = component;
    srBatch = batch;
    srSectionId = '${academicYear}_${branch}_$division'.replaceAll(' ', ''); // basic fallback if needed, but we'll pass sectionId explicitly later

    await prefs.setString(
      'sr_division',
      division,
    );

    await prefs.setString(
      'sr_subject',
      subject,
    );

    if (component != null) {
      await prefs.setString(
        'sr_component',
        component,
      );
    }
    
    if (batch != null) {
      await prefs.setString('sr_batch', batch);
    } else {
      await prefs.remove('sr_batch');
    }
  }

  static Future<void> saveSRSection({
    required String sectionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    srSectionId = sectionId;
    await prefs.setString('sr_section_id', sectionId);
  }

  static Future<void> saveStudentDetails({
    required String name,
    required String rollNo,
    required String acYear,
    required String br,
    required String div,
    required String secId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    studentName = name;
    studentRollNo = rollNo;
    academicYear = acYear;
    branch = br;
    division = div;
    sectionId = secId;
    
    await prefs.setString('student_name', name);
    await prefs.setString('student_roll_no', rollNo);
    await prefs.setString('academic_year', acYear);
    await prefs.setString('branch', br);
    await prefs.setString('division', div);
    await prefs.setString('section_id', secId);
  }

  static Future<void> resetRole() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove('user_role');
    await prefs.remove('sr_division');
    await prefs.remove('sr_subject');
    await prefs.remove('sr_component');
    await prefs.remove('sr_section_id');
    await prefs.remove('sr_batch');

    currentRole = UserRole.student;

    srDivision = null;
    srSubject = null;
    srComponent = null;
    srSectionId = null;
  }
}