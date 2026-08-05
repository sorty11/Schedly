import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/course_component.dart';
import '../models/course.dart';
import '../timetable_manager.dart';

class CourseConfigurationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  static Future<void> saveMetadata(String division, List<CourseComponent> metadata) async {
    final batch = _db.batch();
    
    for (var meta in metadata) {
      final docRef = meta.componentId.isEmpty 
          ? _db.collection('sections').doc(division).collection('subjects').doc()
          : _db.collection('sections').doc(division).collection('subjects').doc(meta.componentId);
          
      // Ensure we use the proper ID if generating new
      final data = meta.toFirestore();
      batch.set(docRef, data, SetOptions(merge: true));
    }
    
    await batch.commit();
    await _clearCache(division);
  }

  static Future<List<CourseComponent>> getMetadata(String division, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'course_metadata_$division';

    if (!forceRefresh) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        try {
          final List<dynamic> decoded = json.decode(cached);
          return decoded.map((e) => CourseComponent(
            componentId: e['componentId'] ?? e['id'] ?? '', // Fallback to 'id' for cache transition
            componentType: e['componentType'] ?? ((e['isLab'] == true) ? 'Lab' : 'Theory'),
            courseName: e['courseName'] ?? e['subjectName'] ?? '',
            courseCode: e['courseCode'] ?? '',
            targetHours: e['targetHours'] ?? e['totalHours'] ?? 0,
            credits: e['credits'] ?? 0,
            facultyId: e['facultyId'] ?? e['faculty'] ?? '',
            createdAt: DateTime.tryParse(e['createdAt'] ?? '') ?? DateTime.now(),
            semesterId: e['semesterId'],
            sectionId: e['sectionId'] ?? division,
          )).toList();
        } catch (e) {
          // Cache invalid, fetch from network
        }
      }
    }

    final snapshot = await _db.collection('sections').doc(division).collection('subjects').get();
    final list = snapshot.docs.map((d) => CourseComponent.fromFirestore(d)).toList();

    // Update cache
    final cacheData = list.map((m) {
      final data = m.toFirestore();
      data['createdAt'] = m.createdAt.toIso8601String();
      return data;
    }).toList();
    
    await prefs.setString(cacheKey, json.encode(cacheData));
    
    return list;
  }
  
  /// Helper method to fetch all components and group them into Course models.
  static Future<List<Course>> getCourses(String division, {bool forceRefresh = false}) async {
    final components = await getMetadata(division, forceRefresh: forceRefresh);
    
    final Map<String, List<CourseComponent>> grouped = {};
    for (var comp in components) {
      grouped.putIfAbsent(comp.courseName, () => []).add(comp);
    }
    
    return grouped.entries.map((e) {
      final comps = e.value;
      // Get the courseCode from the first component that has one
      final courseCode = comps.firstWhere((c) => c.courseCode.isNotEmpty, orElse: () => comps.first).courseCode;
      
      return Course(
        courseName: e.key,
        courseCode: courseCode,
        components: comps,
      );
    }).toList();
  }
  
  static Stream<List<CourseComponent>> streamMetadata(String division) {
    return _db.collection('sections').doc(division).collection('subjects').snapshots().map(
      (snap) => snap.docs.map((d) => CourseComponent.fromFirestore(d)).toList()
    );
  }

  static Future<bool> isSetupComplete(String division) async {
    try {
      final uniqueSubjects = await TimetableManager.getUniqueSubjects(division: division);
      if (uniqueSubjects.isEmpty) return true; // nothing to setup
      
      final metadata = await getMetadata(division);
      final metaIds = metadata.map((e) => e.componentId).toSet();
      
      // If any unique subject is missing from metadata, it's not complete
      return uniqueSubjects.every((s) => metaIds.contains(s));
    } catch (_) {
      return false;
    }
  }

  static Future<void> _clearCache(String division) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('course_metadata_$division');
    await prefs.remove('subject_metadata_$division'); // Clear legacy cache too
  }
}
