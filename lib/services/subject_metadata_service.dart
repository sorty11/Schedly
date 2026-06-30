import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/subject_metadata.dart';
import '../timetable_manager.dart';

class SubjectMetadataService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  static Future<void> saveMetadata(String division, List<SubjectMetadata> metadata) async {
    final batch = _db.batch();
    
    for (var meta in metadata) {
      final docRef = meta.id.isEmpty 
          ? _db.collection('sections').doc(division).collection('subjects').doc()
          : _db.collection('sections').doc(division).collection('subjects').doc(meta.id);
          
      // Ensure we use the proper ID if generating new
      final data = meta.toFirestore();
      batch.set(docRef, data, SetOptions(merge: true));
    }
    
    await batch.commit();
    await _clearCache(division);
  }

  static Future<List<SubjectMetadata>> getMetadata(String division, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'subject_metadata_$division';

    if (!forceRefresh) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        try {
          final List<dynamic> decoded = json.decode(cached);
          // Reconstruct roughly from json cache, but date will be string
          // To make it simple, we just parse it
          return decoded.map((e) => SubjectMetadata(
            id: e['id'],
            subjectName: e['subjectName'],
            courseCode: e['courseCode'] ?? '',
            totalHours: e['totalHours'] ?? 0,
            credits: e['credits'] ?? 0,
            faculty: e['faculty'] ?? '',
            isLab: e['isLab'] ?? false,
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
    final list = snapshot.docs.map((d) => SubjectMetadata.fromFirestore(d)).toList();

    // Update cache
    final cacheData = list.map((m) => {
      'id': m.id,
      'subjectName': m.subjectName,
      'courseCode': m.courseCode,
      'totalHours': m.totalHours,
      'credits': m.credits,
      'faculty': m.faculty,
      'isLab': m.isLab,
      'createdAt': m.createdAt.toIso8601String(),
      'semesterId': m.semesterId,
      'sectionId': m.sectionId,
    }).toList();
    
    await prefs.setString(cacheKey, json.encode(cacheData));
    
    return list;
  }
  
  static Stream<List<SubjectMetadata>> streamMetadata(String division) {
    return _db.collection('sections').doc(division).collection('subjects').snapshots().map(
      (snap) => snap.docs.map((d) => SubjectMetadata.fromFirestore(d)).toList()
    );
  }

  static Future<bool> isSetupComplete(String division) async {
    try {
      final uniqueSubjects = await TimetableManager.getUniqueSubjects(division: division);
      if (uniqueSubjects.isEmpty) return true; // nothing to setup
      
      final metadata = await getMetadata(division);
      final metaNames = metadata.map((e) => e.subjectName).toSet();
      
      // If any unique subject is missing from metadata, it's not complete
      return uniqueSubjects.every((s) => metaNames.contains(s));
    } catch (_) {
      return false;
    }
  }

  static Future<void> _clearCache(String division) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('subject_metadata_$division');
  }
}
