import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/timetable_entry.dart';
import '../data/course_aliases.dart';

class FacultySrConnectionService {
  // In-memory cache for canonical section IDs: e.g. 'ce_c' -> 'SecondYear_CE_C'
  static final Map<String, String> _sectionIdCache = {};

  /// Resolves any division string (e.g. 'CE_C', 'CE C', 'SecondYear_CE_C')
  /// to the exact document ID in the `sections` Firestore collection.
  static Future<String> resolveCanonicalSectionId(String rawDivision) async {
    final trimmed = rawDivision.trim();
    if (trimmed.isEmpty) return '';
    final lowerKey = trimmed.toLowerCase().replaceAll(' ', '_');

    if (_sectionIdCache.containsKey(lowerKey)) {
      return _sectionIdCache[lowerKey]!;
    }

    try {
      // 1. Direct match check
      final directDoc = await FirebaseFirestore.instance
          .collection('sections')
          .doc(trimmed)
          .get();
      if (directDoc.exists) {
        _sectionIdCache[lowerKey] = trimmed;
        return trimmed;
      }

      // 2. Query all sections to locate the matching document ID
      final sectionsSnap = await FirebaseFirestore.instance
          .collection('sections')
          .get();

      for (final doc in sectionsSnap.docs) {
        final docId = doc.id;
        final docLower = docId.toLowerCase();
        final docNorm = docLower.replaceAll(' ', '_');

        // Exact normalized match
        if (docNorm == lowerKey) {
          _sectionIdCache[lowerKey] = docId;
          return docId;
        }

        // Suffix match (e.g. 'SecondYear_CE_C' ends with 'CE_C')
        final cleanUnderscore = lowerKey.replaceAll('-', '_');
        if (docNorm.endsWith(cleanUnderscore) ||
            docNorm.contains(cleanUnderscore) ||
            cleanUnderscore.endsWith(docNorm)) {
          _sectionIdCache[lowerKey] = docId;
          return docId;
        }

        // Structural check against division and branch fields in section doc
        final data = doc.data();
        final divField = data['division']?.toString().toLowerCase();
        final branchField = data['branch']?.toString().toLowerCase();
        if (divField != null && branchField != null) {
          final composite = '${branchField}_$divField';
          if (composite == cleanUnderscore ||
              cleanUnderscore.endsWith(composite)) {
            _sectionIdCache[lowerKey] = docId;
            return docId;
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[FacultySrConnectionService] Error resolving sectionId for $rawDivision: $e',
      );
    }

    // Fallback to original trimmed string
    _sectionIdCache[lowerKey] = trimmed;
    return trimmed;
  }

  /// Checks if two subject representations refer to the same subject.
  /// Handles acronyms (e.g. 'COA' <-> 'Computer Organization and Architecture'),
  /// component stripping ('COA Theory' <-> 'COA'), aliases, and normalization.
  static bool isSameSubject(String a, String b) {
    if (a.trim().isEmpty || b.trim().isEmpty) return false;
    final cleanA = a.trim().toLowerCase().replaceAll('_', ' ');
    final cleanB = b.trim().toLowerCase().replaceAll('_', ' ');

    if (cleanA == cleanB) return true;

    // 1. Strip component suffixes (Theory, Lab, Tutorial, etc.)
    final strippedA = TimetableEntry.stripComponentSuffix(cleanA)
        .trim()
        .replaceAll(
          RegExp(
            r'[\s_]+(theory|lab|tutorial|project|seminar|viva)$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final strippedB = TimetableEntry.stripComponentSuffix(cleanB)
        .trim()
        .replaceAll(
          RegExp(
            r'[\s_]+(theory|lab|tutorial|project|seminar|viva)$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (strippedA == strippedB) return true;

    // 2. Check courseAliases dictionary
    for (final entry in courseAliases.entries) {
      final code = entry.key.toLowerCase().replaceAll('_', ' ');
      final fullName = entry.value.toLowerCase().replaceAll('_', ' ');

      final aIsCode = strippedA == code;
      final aIsFull =
          strippedA == fullName ||
          strippedA.contains(fullName) ||
          fullName.contains(strippedA);

      final bIsCode = strippedB == code;
      final bIsFull =
          strippedB == fullName ||
          strippedB.contains(fullName) ||
          fullName.contains(strippedB);

      if ((aIsCode && bIsFull) || (bIsCode && aIsFull)) return true;
      if (aIsCode && bIsCode) return true;
    }

    // 3. Acronym matching (e.g. "Computer Organization and Architecture" -> "coa")
    String getAcronym(String text) {
      final words = text
          .split(RegExp(r'[\s_]+'))
          .where(
            (w) =>
                w.isNotEmpty &&
                w.toLowerCase() != 'and' &&
                w.toLowerCase() != '&',
          )
          .toList();
      if (words.length > 1) {
        return words.map((w) => w[0].toLowerCase()).join();
      }
      return '';
    }

    final acrA = getAcronym(strippedA);
    final acrB = getAcronym(strippedB);

    if (acrA.isNotEmpty &&
        (acrA == strippedB ||
            strippedB == acrA ||
            strippedB.startsWith(acrA))) {
      return true;
    }
    if (acrB.isNotEmpty &&
        (acrB == strippedA ||
            strippedA == acrB ||
            strippedA.startsWith(acrB))) {
      return true;
    }

    // 4. Normalized contains check
    final simpleA = strippedA.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final simpleB = strippedB.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (simpleA.isNotEmpty && simpleB.isNotEmpty && simpleA == simpleB) {
      return true;
    }

    return false;
  }

  /// Fetches the assigned SR identities for a given division and subject.
  /// Searches canonical section ID, direct assignment IDs, aliases, and scans
  /// all subcollection documents safely without throwing on malformed records.
  static Future<List<String>> getAssignedSRs({
    required String division,
    required String subject,
  }) async {
    if (division.trim().isEmpty || subject.trim().isEmpty) return [];

    try {
      final sectionId = await resolveCanonicalSectionId(division);

      // Strategy 1: Direct document lookups with various key candidates
      final strippedSubject = TimetableEntry.stripComponentSuffix(subject);
      final candidates = <String>{
        subject.toLowerCase().replaceAll(' ', '_'),
        subject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
        strippedSubject.toLowerCase().replaceAll(' ', '_'),
        strippedSubject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
        strippedSubject.toLowerCase(),
      };

      for (final cand in candidates) {
        if (cand.isEmpty) continue;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('sections')
              .doc(sectionId)
              .collection('sr_assignments')
              .doc(cand)
              .get();

          if (doc.exists && doc.data() != null) {
            final srs = _extractSrsFromData(doc.data(), doc.id);
            if (srs.isNotEmpty) return srs;
          }
        } catch (e) {
          debugPrint(
            '[FacultySrConnectionService] Warning reading sections/$sectionId/sr_assignments/$cand: $e',
          );
        }
      }

      // Strategy 2: Query the entire sr_assignments subcollection for the section
      final snap = await FirebaseFirestore.instance
          .collection('sections')
          .doc(sectionId)
          .collection('sr_assignments')
          .get();

      for (final doc in snap.docs) {
        final docId = doc.id;
        final data = doc.data();
        final docSubject =
            data['subject']?.toString() ??
            data['subjectName']?.toString() ??
            data['courseName']?.toString() ??
            docId;

        if (isSameSubject(docId, subject) ||
            isSameSubject(docSubject, subject)) {
          final srs = _extractSrsFromData(data, docId);
          if (srs.isNotEmpty) return srs;
        }
      }
    } catch (e) {
      debugPrint(
        '[FacultySrConnectionService] getAssignedSRs exception for $division / $subject: $e',
      );
    }
    return [];
  }

  /// Extracts SR identity strings safely from any Firestore document structure.
  static List<String> _extractSrsFromData(
    Map<String, dynamic>? data,
    String docId,
  ) {
    if (data == null) return [];
    final results = <String>[];

    final rawSrs = data['srs'];
    if (rawSrs is Iterable) {
      for (final item in rawSrs) {
        if (item == null) continue;
        if (item is String && item.trim().isNotEmpty) {
          results.add(item.trim());
        } else if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final rollNo = item['rollNo']?.toString() ?? '';
          if (name.isNotEmpty) {
            results.add(rollNo.isNotEmpty ? '$name ($rollNo)' : name);
          }
        }
      }
    }

    // Single-string SR fields fallback
    if (results.isEmpty) {
      final single =
          data['sr'] ?? data['srName'] ?? data['studentName'] ?? data['name'];
      if (single != null && single.toString().trim().isNotEmpty) {
        results.add(single.toString().trim());
      }
    }

    return results;
  }

  /// Fetches the faculty assigned to teach a subject in a division.
  /// Robust bidirectional lookup supporting division normalization, subject aliases,
  /// excel schedules, and safe map parsing.
  static Future<List<Map<String, dynamic>>> getAssignedFaculty({
    required String division,
    required String subject,
  }) async {
    if (division.trim().isEmpty || subject.trim().isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    try {
      final canonicalSectionId = await resolveCanonicalSectionId(division);

      final snap = await FirebaseFirestore.instance
          .collection('faculty_profiles')
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final docId = doc.id;

        // 1. Division matching across assignedDivisions
        final divs = parseDivisions(data['assignedDivisions']);
        bool divMatches = divs.any(
          (d) => matchesDivision(d, division, canonicalSectionId),
        );

        final subjectsMap = parseSubjectsMap(data['subjects']);
        if (!divMatches) {
          divMatches = subjectsMap.keys.any(
            (d) => matchesDivision(d, division, canonicalSectionId),
          );
        }

        if (!divMatches) continue;

        // 2. Subject matching inside subjects map
        bool subjectMatches = false;
        for (final entry in subjectsMap.entries) {
          final d = entry.key;
          if (matchesDivision(d, division, canonicalSectionId)) {
            final divSubjects = entry.value;
            if (divSubjects.any((s) => isSameSubject(s, subject))) {
              subjectMatches = true;
              break;
            }
          }
        }

        // 3. Fallback: check excelSchedule if present
        if (!subjectMatches && data['excelSchedule'] is Iterable) {
          for (final item in data['excelSchedule'] as Iterable) {
            if (item is Map) {
              final itemDiv = item['division']?.toString() ?? '';
              final itemSubj = item['subject']?.toString() ?? '';
              if (matchesDivision(itemDiv, division, canonicalSectionId) &&
                  isSameSubject(itemSubj, subject)) {
                subjectMatches = true;
                break;
              }
            }
          }
        }

        if (subjectMatches && !seenIds.contains(docId)) {
          seenIds.add(docId);
          results.add({'id': docId, ...data});
        }
      }

      // 4. Fallback: check section subject metadata: sections/{sectionId}/subjects/{subject}
      if (results.isEmpty) {
        try {
          final stripped = TimetableEntry.stripComponentSuffix(subject);
          final candidates = {
            subject,
            stripped,
            subject.toUpperCase(),
            stripped.toUpperCase(),
          };

          for (final cand in candidates) {
            final subjDoc = await FirebaseFirestore.instance
                .collection('sections')
                .doc(canonicalSectionId)
                .collection('subjects')
                .doc(cand)
                .get();

            if (subjDoc.exists && subjDoc.data() != null) {
              final sData = subjDoc.data()!;
              final facultyId = sData['facultyId']?.toString().trim();
              final facultyName = sData['faculty']?.toString().trim();

              if (facultyId != null &&
                  facultyId.isNotEmpty &&
                  !seenIds.contains(facultyId)) {
                final facSnap = await FirebaseFirestore.instance
                    .collection('faculty_profiles')
                    .doc(facultyId)
                    .get();
                if (facSnap.exists && facSnap.data() != null) {
                  seenIds.add(facultyId);
                  results.add({'id': facSnap.id, ...facSnap.data()!});
                  break;
                }
              } else if (facultyName != null && facultyName.isNotEmpty) {
                results.add({
                  'id': 'faculty_${canonicalSectionId}_$cand',
                  'name': facultyName,
                  'designation': 'Faculty',
                  'department': '',
                  'cabin': '',
                });
                break;
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint(
        '[FacultySrConnectionService] getAssignedFaculty exception: $e',
      );
    }
    return results;
  }

  static bool matchesDivision(
    String a,
    String targetDiv, [
    String? canonicalTargetDiv,
  ]) {
    final lowerA = a.trim().toLowerCase().replaceAll(' ', '_');
    final lowerTarget = targetDiv.trim().toLowerCase().replaceAll(' ', '_');

    if (lowerA == lowerTarget) return true;
    if (canonicalTargetDiv != null) {
      final lowerCanonical = canonicalTargetDiv.trim().toLowerCase().replaceAll(
        ' ',
        '_',
      );
      if (lowerA == lowerCanonical) return true;
      if (lowerA.endsWith(lowerCanonical) || lowerCanonical.endsWith(lowerA)) {
        return true;
      }
    }
    if (lowerA.endsWith(lowerTarget) || lowerTarget.endsWith(lowerA)) {
      return true;
    }
    final cleanA = lowerA.replaceAll('-', '_');
    final cleanTarget = lowerTarget.replaceAll('-', '_');
    if (cleanA == cleanTarget ||
        cleanA.endsWith(cleanTarget) ||
        cleanTarget.endsWith(cleanA)) {
      return true;
    }
    return false;
  }

  /// Returns the list of subjects for a division from a parsed subjects map,
  /// matching by division name or canonical division name.
  static List<String> getSubjectsForDivision(
    Map<String, List<String>> subjectsMap,
    String division,
  ) {
    if (division.trim().isEmpty) return [];
    if (subjectsMap.containsKey(division)) {
      return subjectsMap[division]!;
    }
    for (final entry in subjectsMap.entries) {
      if (matchesDivision(entry.key, division)) {
        return entry.value;
      }
    }
    return [];
  }

  /// Parses `subjects` from Firestore safely without throwing TypeErrors.
  static Map<String, List<String>> parseSubjectsMap(dynamic rawSubjects) {
    final result = <String, List<String>>{};
    if (rawSubjects is Map) {
      rawSubjects.forEach((k, v) {
        if (k != null) {
          final divKey = k.toString().trim();
          final list = <String>[];
          if (v is Iterable) {
            for (final s in v) {
              if (s != null && s.toString().trim().isNotEmpty) {
                list.add(s.toString().trim());
              }
            }
          }
          result[divKey] = list;
        }
      });
    }
    return result;
  }

  /// Parses `assignedDivisions` from Firestore safely without throwing TypeErrors.
  static List<String> parseDivisions(dynamic rawDivisions) {
    final list = <String>[];
    if (rawDivisions is Iterable) {
      for (final d in rawDivisions) {
        if (d != null && d.toString().trim().isNotEmpty) {
          list.add(d.toString().trim());
        }
      }
    }
    return list;
  }
}
