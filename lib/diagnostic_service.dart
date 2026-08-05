import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticService {
  static Future<String> runDiagnostics() async {
    final buffer = StringBuffer();
    void log(String msg) {
      print(msg);
      buffer.writeln(msg);
    }
    
    log('================ DIAGNOSTICS START ================');
    try {
      final prefs = await SharedPreferences.getInstance();
      
      log('1. AppSettings & SharedPreferences Runtime Values:');
      log('  - AppSettings.sectionId: ${AppSettings.sectionId}');
      log('  - AppSettings.division: ${AppSettings.division}');
      log('  - prefs.getString("selected_division"): ${prefs.getString("selected_division")}');
      
      final divisionToQuery = AppSettings.sectionId ?? AppSettings.division ?? prefs.getString('selected_division') ?? 'Unknown';
      log('  - Value that WOULD be passed to Rosters/Requests: $divisionToQuery');
      
      log('\n2. Firestore Data Verification:');
      
      log('  - Querying sections/$divisionToQuery:');
      try {
        final secDoc = await FirebaseFirestore.instance.collection('sections').doc(divisionToQuery).get();
        log('    Exists: ${secDoc.exists}');
        if(secDoc.exists) {
          log('    Data: ${secDoc.data()}');
        }
      } catch (e) {
        log('    Error reading sections/$divisionToQuery: $e');
      }

      log('\n  - Querying users for sectionId/division $divisionToQuery:');
      try {
        final usersSnap = await FirebaseFirestore.instance.collection('users').where('division', isEqualTo: divisionToQuery).get();
        log('    Found ${usersSnap.docs.length} users with division == $divisionToQuery');
        if(usersSnap.docs.isNotEmpty) {
           log('    Sample User Data: ${usersSnap.docs.first.data()}');
        }
        
        final usersSnapSection = await FirebaseFirestore.instance.collection('users').where('sectionId', isEqualTo: divisionToQuery).get();
        log('    Found ${usersSnapSection.docs.length} users with sectionId == $divisionToQuery');
      } catch (e) {
        log('    Error reading users: $e');
      }

      log('\n  - Querying faculty_profiles for assignedDivisions containing $divisionToQuery:');
      try {
        final facSnap = await FirebaseFirestore.instance.collection('faculty_profiles').where('assignedDivisions', arrayContains: divisionToQuery).get();
        log('    Found ${facSnap.docs.length} faculty profiles with arrayContains: $divisionToQuery');
        if(facSnap.docs.isNotEmpty) {
           log('    Sample: ${facSnap.docs.first.data()}');
        }
        
        // Also let's just grab one faculty profile to see what assignedDivisions actually looks like
        final anyFac = await FirebaseFirestore.instance.collection('faculty_profiles').limit(1).get();
        if(anyFac.docs.isNotEmpty) {
           log('    Random Faculty Profile assignedDivisions: ${anyFac.docs.first.data()['assignedDivisions']}');
        }
      } catch (e) {
        log('    Error reading faculty_profiles: $e');
      }

      log('\n  - Querying section_memberships for sectionId/division $divisionToQuery:');
      try {
        final membSnap = await FirebaseFirestore.instance.collection('section_memberships').limit(10).get();
        log('    Sample of section_memberships docs:');
        for (var doc in membSnap.docs) {
          log('      ${doc.id} -> ${doc.data()}');
        }
      } catch (e) {
        log('    Error reading section_memberships: $e');
      }

      log('\n  - Querying sections/$divisionToQuery/faculty_requests:');
      try {
        final reqSnap = await FirebaseFirestore.instance.collection('sections').doc(divisionToQuery).collection('faculty_requests').get();
        log('    Found ${reqSnap.docs.length} faculty requests');
        if(reqSnap.docs.isNotEmpty) {
           log('    Sample Request: ${reqSnap.docs.first.data()}');
        }
      } catch (e) {
        log('    Error reading faculty_requests: $e');
      }

    } catch (e) {
      log('FATAL ERROR in Diagnostics: $e');
    }
    log('================ DIAGNOSTICS END ================');
    
    return buffer.toString();
  }
  
  static Future<void> logNavigation(String pageName, String? division) async {
    print('================ NAVIGATION LOG ================');
    print('NAVIGATING TO: $pageName');
    print('PASSED DIVISION/SECTION_ID: $division');
    print('================================================');
  }
}
