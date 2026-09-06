import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../app_settings.dart';
import '../user_roles.dart';
import '../models/gamification_profile.dart';
import '../widgets/gamification/schedly_top3_sheet.dart';

class LeaderboardPopupData {
  final List<GamificationProfile> top3;
  final GamificationProfile? bestCR;
  final GamificationProfile? bestSR;

  const LeaderboardPopupData({
    required this.top3,
    this.bestCR,
    this.bestSR,
  });
}

class GamificationService {
  GamificationService._();
  static final GamificationService instance = GamificationService._();

  static const int dailyExpReward = 20;
  static const int timetableActionReward = 25;
  static const String _prefDailyClaimDateKey = 'schedly_last_daily_claim_date';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory cache & guards
  bool _claimedThisSession = false;
  bool hasShownAutoPopup = false;
  DateTime? _lastTimetableActionTime;

  // Reactive notifier for current user's EXP and points
  final ValueNotifier<int> currentExpNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentCrPointsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentSrPointsNotifier = ValueNotifier<int>(0);

  CollectionReference<Map<String, dynamic>> get _gamificationRef =>
      _firestore.collection('gamification');

  String _getTodayDateStr() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  /// Ensures that the current authenticated user has a document in /gamification/{uid}
  Future<void> _ensureCurrentUserDocExists() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final docRef = _gamificationRef.doc(user.uid);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        String displayName = AppSettings.studentName ??
            AppSettings.facultyName ??
            user.displayName ??
            'Student';
        String? photoUrl = AppSettings.profilePhotoUrl ?? user.photoURL;
        String year = AppSettings.academicYear ?? '';
        String branch = AppSettings.branch ?? '';
        String division = AppSettings.sectionId ?? AppSettings.division ?? '';
        String role = AppSettings.currentRole.name.toUpperCase();

        await docRef.set({
          'uid': user.uid,
          'displayName': displayName,
          if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
          'academicYear': year,
          'branch': branch,
          'division': division,
          'role': role,
          'exp': dailyExpReward,
          'crPoints': 0,
          'srPoints': 0,
          'lastDailyExpClaimDate': _getTodayDateStr(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[GAMIFICATION] Initialized gamification profile for ${user.uid}');
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Note ensuring user doc: $e');
    }
  }

  /// Initial load or refresh of current user's stats
  Future<GamificationProfile?> loadCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _gamificationRef.doc(user.uid).get();
      if (doc.exists) {
        final profile = GamificationProfile.fromFirestore(doc);
        currentExpNotifier.value = profile.exp;
        currentCrPointsNotifier.value = profile.crPoints;
        currentSrPointsNotifier.value = profile.srPoints;
        return profile;
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Error loading user profile: $e');
    }
    return null;
  }

  /// Checks and awards the daily app-open EXP (+20 XP) if not yet claimed today.
  Future<bool> checkAndClaimDailyExp() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    debugPrint('[GAMIFICATION] Daily EXP check started');
    final todayStr = _getTodayDateStr();

    // 1. In-memory session check
    if (_claimedThisSession) {
      debugPrint('[GAMIFICATION] Daily EXP already claimed this session');
      return false;
    }

    try {
      final userDocRef = _gamificationRef.doc(user.uid);
      final prefs = await SharedPreferences.getInstance();
      final lastLocalClaim = prefs.getString(_prefDailyClaimDateKey);

      String displayName = AppSettings.studentName ??
          AppSettings.facultyName ??
          user.displayName ??
          'Student';
      String? photoUrl = AppSettings.profilePhotoUrl ?? user.photoURL;
      String year = AppSettings.academicYear ?? '';
      String branch = AppSettings.branch ?? '';
      String division = AppSettings.sectionId ?? AppSettings.division ?? '';
      String role = AppSettings.currentRole.name.toUpperCase();

      final docSnap = await userDocRef.get();

      if (!docSnap.exists) {
        // Document doesn't exist yet: initialize it with 20 EXP!
        final newProfile = GamificationProfile(
          uid: user.uid,
          displayName: displayName,
          photoUrl: photoUrl,
          academicYear: year,
          branch: branch,
          division: division,
          role: role,
          exp: dailyExpReward,
          lastDailyExpClaimDate: todayStr,
          updatedAt: DateTime.now(),
        );
        await userDocRef.set(newProfile.toFirestore());
        _claimedThisSession = true;
        await prefs.setString(_prefDailyClaimDateKey, todayStr);
        await loadCurrentUserProfile();
        debugPrint('[GAMIFICATION] Daily EXP awarded: +$dailyExpReward XP (new profile created)');
        return true;
      }

      // Document exists: check remote and local claim dates
      final data = docSnap.data();
      final lastRemoteClaim = data?['lastDailyExpClaimDate'] as String?;

      if (lastLocalClaim == todayStr || lastRemoteClaim == todayStr) {
        _claimedThisSession = true;
        if (lastLocalClaim != todayStr) {
          await prefs.setString(_prefDailyClaimDateKey, todayStr);
        }
        await loadCurrentUserProfile();
        debugPrint('[GAMIFICATION] Daily EXP already claimed today ($todayStr)');
        return false;
      }

      // Claim for today
      await userDocRef.update({
        'exp': FieldValue.increment(dailyExpReward),
        'lastDailyExpClaimDate': todayStr,
        'displayName': displayName,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        if (year.isNotEmpty) 'academicYear': year,
        if (branch.isNotEmpty) 'branch': branch,
        if (division.isNotEmpty) 'division': division,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _claimedThisSession = true;
      await prefs.setString(_prefDailyClaimDateKey, todayStr);
      await loadCurrentUserProfile();
      debugPrint('[GAMIFICATION] Daily EXP awarded: +$dailyExpReward XP');
      return true;
    } catch (e) {
      debugPrint('[GAMIFICATION] Failed to claim daily EXP: $e');
      return false;
    }
  }

  /// Records a successful timetable modification action performed by CR or SR.
  /// Awards +25 activity points (to crPoints for CR, srPoints for SR).
  Future<void> recordTimetableAction({required String division}) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final role = AppSettings.currentRole;
    if (role != UserRole.cr && role != UserRole.sr) return;

    // Cooldown & deduplication: minimum 20 seconds between rewarded actions
    final now = DateTime.now();
    if (_lastTimetableActionTime != null &&
        now.difference(_lastTimetableActionTime!).inSeconds < 20) {
      debugPrint('[GAMIFICATION] Timetable action ignored due to cooldown.');
      return;
    }
    _lastTimetableActionTime = now;

    try {
      final userDocRef = _gamificationRef.doc(user.uid);
      final pointField = role == UserRole.cr ? 'crPoints' : 'srPoints';

      String displayName = AppSettings.studentName ??
          user.displayName ??
          (role == UserRole.cr ? 'CR' : 'SR');
      String? photoUrl = AppSettings.profilePhotoUrl ?? user.photoURL;
      String year = AppSettings.academicYear ?? '';
      String branch = AppSettings.branch ?? '';
      String div = division.isNotEmpty ? division : (AppSettings.sectionId ?? '');

      await userDocRef.set({
        'uid': user.uid,
        'displayName': displayName,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        'academicYear': year,
        'branch': branch,
        'division': div,
        'role': role == UserRole.cr ? 'CR' : 'SR',
        pointField: FieldValue.increment(timetableActionReward),
        'lastTimetableActionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await loadCurrentUserProfile();
      debugPrint('[GAMIFICATION] Successfully awarded $timetableActionReward points to $pointField');
    } catch (e) {
      debugPrint('[GAMIFICATION] Error recording timetable action: $e');
    }
  }

  /// Fetches the Global Top 3 users ordered by EXP descending.
  Future<List<GamificationProfile>> fetchGlobalTop3() async {
    try {
      final snap = await _gamificationRef
          .orderBy('exp', descending: true)
          .limit(3)
          .get();

      return snap.docs
          .map((doc) => GamificationProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[GAMIFICATION] Error fetching global top 3: $e');
      return [];
    }
  }

  /// Fetches the current Best CR based on highest crPoints (> 0).
  Future<GamificationProfile?> fetchBestCR() async {
    try {
      final snap = await _gamificationRef
          .where('crPoints', isGreaterThan: 0)
          .orderBy('crPoints', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return GamificationProfile.fromFirestore(snap.docs.first);
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Error fetching best CR: $e');
    }
    return null;
  }

  /// Fetches the current Best SR based on highest srPoints (> 0).
  Future<GamificationProfile?> fetchBestSR() async {
    try {
      final snap = await _gamificationRef
          .where('srPoints', isGreaterThan: 0)
          .orderBy('srPoints', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return GamificationProfile.fromFirestore(snap.docs.first);
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Error fetching best SR: $e');
    }
    return null;
  }

  /// Loads leaderboard data asynchronously. Returns null on failure or if empty.
  Future<LeaderboardPopupData?> loadPopupData() async {
    debugPrint('[GAMIFICATION] Leaderboard fetch started');
    try {
      // Ensure current user exists in gamification collection
      await _ensureCurrentUserDocExists();

      final results = await Future.wait([
        fetchGlobalTop3(),
        fetchBestCR(),
        fetchBestSR(),
      ]);

      final top3 = results[0] as List<GamificationProfile>;
      final bestCR = results[1] as GamificationProfile?;
      final bestSR = results[2] as GamificationProfile?;

      debugPrint('[GAMIFICATION] Top 3 count: ${top3.length}');
      debugPrint('[GAMIFICATION] Best CR result: ${bestCR != null ? '${bestCR.displayName} (${bestCR.crPoints} pts)' : 'none'}');
      debugPrint('[GAMIFICATION] Best SR result: ${bestSR != null ? '${bestSR.displayName} (${bestSR.srPoints} pts)' : 'none'}');

      if (top3.isEmpty) {
        debugPrint('[GAMIFICATION] Top 3 is empty, skipping popup');
        return null;
      }

      return LeaderboardPopupData(
        top3: top3,
        bestCR: bestCR,
        bestSR: bestSR,
      );
    } catch (e) {
      debugPrint('[GAMIFICATION] Error loading popup data: $e');
      return null;
    }
  }

  /// Automatically displays the 3-second leaderboard popup once per session
  /// if valid leaderboard data is available. Non-blocking.
  Future<void> showAutoLeaderboardPopupIfEligible(BuildContext context) async {
    if (hasShownAutoPopup) {
      debugPrint('[GAMIFICATION] Leaderboard popup already shown this session');
      return;
    }

    final data = await loadPopupData();
    if (data == null) {
      debugPrint('[GAMIFICATION] No popup data available, skipping popup');
      return;
    }

    if (!context.mounted) {
      debugPrint('[GAMIFICATION] Context no longer mounted, skipping popup');
      return;
    }

    hasShownAutoPopup = true;
    debugPrint('[GAMIFICATION] Showing leaderboard popup');
    try {
      await SchedlyTop3Sheet.show(context, data: data);
      debugPrint('[GAMIFICATION] Popup dismissed');
    } catch (e) {
      debugPrint('[GAMIFICATION] Error showing popup: $e');
    }
  }
}
