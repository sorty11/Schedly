import 'package:cloud_firestore/cloud_firestore.dart';

class CourseComponent {
  final String componentId; // The immutable document ID (previously `id`)
  final String componentType; // e.g., 'Theory', 'Lab', 'Combined', 'Tutorial'
  final String courseName; // Derived during migration, explicitly stored
  final String courseCode;
  final int targetHours; // Total hours to teach
  final int credits;
  final String facultyId;
  final DateTime createdAt;
  final String? semesterId;
  final String sectionId;
  final int cancelledHours;

  // Backward compatibility getter for code that used 'subjectName' directly
  String get subjectName => componentId;
  
  // Dynamic check for components that might act as labs for UI/icons
  bool get isLab => componentType.toLowerCase().contains('lab');

  CourseComponent({
    required this.componentId,
    required this.componentType,
    required this.courseName,
    this.courseCode = '',
    required this.targetHours,
    this.credits = 0,
    this.facultyId = '',
    required this.createdAt,
    this.semesterId,
    required this.sectionId,
    this.cancelledHours = 0,
  });

  factory CourseComponent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Automatic fallback during migration phase if fields are missing:
    final fallbackSubjectName = data['subjectName'] as String? ?? doc.id;
    final fallbackType = (data['isLab'] == true) ? 'Lab' : 'Theory';

    return CourseComponent(
      componentId: doc.id,
      componentType: data['componentType'] ?? fallbackType,
      courseName: data['courseName'] ?? fallbackSubjectName,
      courseCode: data['courseCode'] ?? '',
      targetHours: data['targetHours'] ?? data['totalHours'] ?? 0, // Fallback to legacy totalHours
      credits: data['credits'] ?? 0,
      facultyId: data['facultyId'] ?? data['faculty'] ?? '', // Fallback to legacy faculty field
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      semesterId: data['semesterId'],
      sectionId: data['sectionId'] ?? '',
      cancelledHours: data['cancelledHours'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // We keep legacy fields to ensure backward compatibility for old clients temporarily
      'subjectName': subjectName, 
      'totalHours': targetHours,
      'faculty': facultyId,
      'isLab': isLab,
      
      // New strictly defined fields
      'componentType': componentType,
      'courseName': courseName,
      'courseCode': courseCode,
      'targetHours': targetHours,
      'credits': credits,
      'facultyId': facultyId,
      
      'createdAt': Timestamp.fromDate(createdAt),
      if (semesterId != null) 'semesterId': semesterId,
      'sectionId': sectionId,
      'cancelledHours': cancelledHours,
    };
  }
}
