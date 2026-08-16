import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_roles.dart';
import 'services/topic_subscription_service.dart';
import 'services/notification_service.dart';

class AppSettings {
  static UserRole currentRole = UserRole.student;

  static String? srSubject;
  static String? srComponent;
  static String?
  srDivision; // Will be migrated to srSectionId eventually, but let's keep it simple for now or change to srSectionId
  static String? srSectionId;
  static String? srBatch;

  static String? studentName;
  static String? studentRollNo;
  static String? studentBatch;

  static String? academicYear;
  static String? branch;
  static String? division;
  static String? sectionId;

  // Faculty fields
  static String? facultyId;
  static int facultyIdMigrationVersion = 0;
  static String? facultyName;
  static String? facultyEmail;
  static String? facultyDepartment;
  static String? facultyDesignation;
  static String? facultyCabin;
  static bool facultySetupCompleted = false;
  static int facultyReminderTime = 5;
  static List<String>? facultyAssignedDivisions;
  // To avoid complexity, we can store simple strings or retrieve them dynamically from Firestore.
  // We'll store basic identifiers.

  static Future<void> loadRole() async {
    final prefs = await SharedPreferences.getInstance();

    final role = prefs.getString('user_role');

    switch (role) {
      case 'cr':
        currentRole = UserRole.cr;
        break;

      case 'sr':
        currentRole = UserRole.sr;
        break;

      case 'faculty':
        currentRole = UserRole.faculty;
        break;

      default:
        currentRole = UserRole.student;
    }
  }

  static Future<void> loadSRDetails() async {
    final prefs = await SharedPreferences.getInstance();

    srDivision = prefs.getString('sr_division');

    srSubject = prefs.getString('sr_subject');

    srComponent = prefs.getString('sr_component');

    srSectionId = prefs.getString('sr_section_id');

    srBatch = prefs.getString('sr_batch');
  }

  static Future<void> loadStudentDetails() async {
    final prefs = await SharedPreferences.getInstance();
    studentName = prefs.getString('student_name');
    studentRollNo = prefs.getString('student_roll_no');
    studentBatch = prefs.getString('student_batch');

    academicYear = prefs.getString('academic_year');
    branch = prefs.getString('branch');
    division = prefs.getString('division');
    sectionId = prefs.getString('section_id');
  }

  static Future<void> loadFacultyDetails() async {
    final prefs = await SharedPreferences.getInstance();
    facultyId = prefs.getString('faculty_id');
    facultyIdMigrationVersion =
        prefs.getInt('faculty_id_migration_version') ?? 0;
    facultyName = prefs.getString('faculty_name');
    facultyEmail = prefs.getString('faculty_email');
    facultyDepartment = prefs.getString('faculty_department');
    facultyDesignation = prefs.getString('faculty_designation');
    facultyCabin = prefs.getString('faculty_cabin');
    facultySetupCompleted = prefs.getBool('faculty_setup_completed') ?? false;
    facultyReminderTime = prefs.getInt('faculty_reminder_time') ?? 5;
    facultyAssignedDivisions = prefs.getStringList(
      'faculty_assigned_divisions',
    );
  }

  static Future<void> saveRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();

    currentRole = role;

    await prefs.setString('user_role', role.name);
  }

  static Future<void> saveSRDetails({
    required String division,
    required String subject,
    String? component,
    String? batch,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    srDivision = division;
    srSubject = subject;
    srComponent = component;
    srBatch = batch;
    srSectionId = '${academicYear}_${branch}_$division'.replaceAll(
      ' ',
      '',
    ); // basic fallback if needed, but we'll pass sectionId explicitly later

    await prefs.setString('sr_division', division);

    await prefs.setString('sr_subject', subject);

    if (component != null) {
      await prefs.setString('sr_component', component);
    }

    if (batch != null) {
      await prefs.setString('sr_batch', batch);
    } else {
      await prefs.remove('sr_batch');
    }
  }

  static Future<void> saveSRSection({required String sectionId}) async {
    final prefs = await SharedPreferences.getInstance();
    srSectionId = sectionId;
    await prefs.setString('sr_section_id', sectionId);
  }

  static Future<void> saveStudentDetails({
    required String name,
    required String rollNo,
    String? batch,
    required String acYear,
    required String br,
    required String div,
    required String secId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    studentName = name;
    studentRollNo = rollNo;
    studentBatch = batch;
    academicYear = acYear;
    branch = br;
    division = div;
    sectionId = secId;

    await prefs.setString('student_name', name);
    await prefs.setString('student_roll_no', rollNo);
    if (batch != null) {
      await prefs.setString('student_batch', batch);
    } else {
      await prefs.remove('student_batch');
    }
    await prefs.setString('academic_year', acYear);
    await prefs.setString('branch', br);
    await prefs.setString('division', div);
    await prefs.setString('section_id', secId);
  }

  static Future<void> saveStudentBatch(String batch) async {
    final prefs = await SharedPreferences.getInstance();
    studentBatch = batch;
    await prefs.setString('student_batch', batch);
  }

  static Future<void> saveFacultyDetails({
    required String name,
    required String email,
    required String department,
    required String designation,
    required String cabin,
    List<String> assignedDivisions = const [],
    String? id,
    int? migrationVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (id != null) {
      facultyId = id;
      await prefs.setString('faculty_id', id);
    }

    if (migrationVersion != null) {
      facultyIdMigrationVersion = migrationVersion;
      await prefs.setInt('faculty_id_migration_version', migrationVersion);
    }

    facultyName = name;
    facultyEmail = email;
    facultyDepartment = department;
    facultyDesignation = designation;
    facultyCabin = cabin;
    facultyAssignedDivisions = assignedDivisions;

    await prefs.setString('faculty_name', name);
    await prefs.setString('faculty_email', email);
    await prefs.setString('faculty_department', department);
    await prefs.setString('faculty_designation', designation);
    await prefs.setString('faculty_cabin', cabin);
    await prefs.setBool('faculty_setup_completed', facultySetupCompleted);
    await prefs.setStringList('faculty_assigned_divisions', assignedDivisions);
  }

  static Future<void> completeFacultySetup() async {
    final prefs = await SharedPreferences.getInstance();
    facultySetupCompleted = true;
    await prefs.setBool('faculty_setup_completed', true);
  }

  static Future<void> setFacultyReminderTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('faculty_reminder_time', minutes);
    facultyReminderTime = minutes;
  }

  static Future<void> clearFacultyDetails() async {
    final prefs = await SharedPreferences.getInstance();
    facultyId = null;
    facultyIdMigrationVersion = 0;
    facultyName = null;
    facultyEmail = null;
    facultyDepartment = null;
    facultyDesignation = null;
    facultyCabin = null;
    facultySetupCompleted = false;
    facultyAssignedDivisions = null;

    await prefs.remove('faculty_id');
    await prefs.remove('faculty_id_migration_version');
    await prefs.remove('faculty_name');
    await prefs.remove('faculty_email');
    await prefs.remove('faculty_department');
    await prefs.remove('faculty_designation');
    await prefs.remove('faculty_cabin');
    await prefs.remove('faculty_setup_completed');
    await prefs.remove('faculty_assigned_divisions');
  }

  static Future<void> resetRole() async {
    final prefs = await SharedPreferences.getInstance();

    await TopicSubscriptionService.clearAllSubscriptions();

    await prefs.remove('user_role');
    await prefs.remove('student_name');
    await prefs.remove('student_roll_no');
    await prefs.remove('student_batch');
    await prefs.remove('academic_year');
    await prefs.remove('sr_division');
    await prefs.remove('sr_subject');
    await prefs.remove('sr_component');
    await prefs.remove('sr_section_id');
    await prefs.remove('sr_batch');
    await prefs.remove('faculty_id');
    await prefs.remove('faculty_id_migration_version');
    await prefs.remove('faculty_name');
    await prefs.remove('faculty_email');
    await prefs.remove('faculty_department');
    await prefs.remove('faculty_designation');
    await prefs.remove('faculty_cabin');
    await prefs.remove('faculty_setup_completed');
    await prefs.remove('faculty_assigned_divisions');

    currentRole = UserRole.student;

    srDivision = null;
    srSubject = null;
    srComponent = null;
    srSectionId = null;

    facultyName = null;
    facultyEmail = null;
    facultyDepartment = null;
    facultyDesignation = null;
    facultyCabin = null;
    facultySetupCompleted = false;
    facultyAssignedDivisions = [];

    NotificationService.reRegisterToken();
  }
}
