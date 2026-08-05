import 'course_component.dart';

class Course {
  final String courseName;
  final String courseCode;
  final List<CourseComponent> components;

  Course({
    required this.courseName,
    this.courseCode = '',
    required this.components,
  });

  int get totalCredits => components.fold(0, (sum, c) => sum + c.credits);
  int get totalHours => components.fold(0, (sum, c) => sum + c.targetHours);
  
  // Backwards compatibility for UI rendering
  bool get hasLab => components.any((c) => c.isLab);
  String get primaryFaculty => components.isNotEmpty ? components.first.facultyId : '';
}
