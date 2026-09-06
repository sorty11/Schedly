import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../app_settings.dart';
import '../user_roles.dart';
import '../models/gamification_profile.dart';
import '../widgets/gamification/schedly_top3_sheet.dart';

class LeaderboardPopupData {
  final List<GamificationProfile> top3;
  final GamificationProfile? bestCR;
  final GamificationProfile? bestSR;
  final GamificationProfile? champion;

  const LeaderboardPopupData({
    required this.top3,
    this.bestCR,
    this.bestSR,
    this.champion,
  });
}

class GamificationService {
  GamificationService._();
  static final GamificationService instance = GamificationService._();

  static const int dailyExpReward = 20;
  static const int attendanceExpReward = 10;
  static const int timetableActionReward = 25;

  static const String _prefDailyClaimDateKey = 'schedly_last_daily_claim_date';
  static const String _prefAttendanceClaimDateKey = 'schedly_last_attendance_claim_date';

  static const String _defaultBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://schedly-p61g.onrender.com',
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory cache & guards
  bool _claimedDailyThisSession = false;
  bool _claimedAttendanceThisSession = false;
  bool hasShownAutoPopup = false;

  // Reactive notifiers for current user's EXP, points, and Champion status
  final ValueNotifier<int> currentExpNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentCrPointsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentSrPointsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isChampionNotifier = ValueNotifier<bool>(false);

  CollectionReference<Map<String, dynamic>> get _gamificationRef =>
      _firestore.collection('gamification');

  String _getTodayDateStr() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
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
        await checkChampionStatus();
        return profile;
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Error loading user profile: $e');
    }
    return null;
  }

  /// Checks if current user is the active weekly Champion.
  Future<bool> checkChampionStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      isChampionNotifier.value = false;
      return false;
    }

    try {
      final champDoc = await _firestore
          .collection('gamification_meta')
          .doc('current_champion')
          .get();

      if (champDoc.exists) {
        final data = champDoc.data() ?? {};
        final champUid = data['championUid'] as String?;
        final isChamp = champUid != null && champUid.isNotEmpty && champUid == user.uid;
        isChampionNotifier.value = isChamp;
        return isChamp;
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Error checking champion status: $e');
    }

    isChampionNotifier.value = false;
    return false;
  }

  /// Claims daily app-open EXP (+20 XP) via trusted server backend.
  /// Strictly rate-limited to once per Asia/Kolkata calendar day.
  Future<bool> checkAndClaimDailyExp() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    debugPrint('[GAMIFICATION] Daily EXP check started');
    final todayStr = _getTodayDateStr();

    // 1. Session and local preference guard (anti-farming)
    if (_claimedDailyThisSession) {
      debugPrint('[GAMIFICATION] Daily EXP already claimed this session');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastLocalClaim = prefs.getString(_prefDailyClaimDateKey);
    if (lastLocalClaim == todayStr) {
      _claimedDailyThisSession = true;
      debugPrint('[GAMIFICATION] Daily EXP already claimed today locally ($todayStr)');
      return false;
    }

    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return false;

      final url = Uri.parse('$_defaultBackendUrl/api/gamification/claim-daily');
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final success = data['success'] == true;
        final alreadyClaimed = data['alreadyClaimed'] == true;
        final newTotal = (data['newTotalExp'] as num?)?.toInt();

        _claimedDailyThisSession = true;
        await prefs.setString(_prefDailyClaimDateKey, todayStr);

        if (newTotal != null) {
          currentExpNotifier.value = newTotal;
        }

        if (success) {
          debugPrint('[GAMIFICATION] Daily EXP awarded: +$dailyExpReward XP');
          return true;
        } else if (alreadyClaimed) {
          debugPrint('[GAMIFICATION] Server confirms daily EXP already claimed for today');
          return false;
        }
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Failed to claim daily EXP via server: $e');
    }
    return false;
  }

  /// Claims attendance view EXP (+10 XP) via trusted server backend.
  /// Triggered strictly after attendance page/data has successfully loaded.
  Future<bool> recordAttendanceView() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    final todayStr = _getTodayDateStr();

    // Anti-farming guards: session + local preference
    if (_claimedAttendanceThisSession) {
      debugPrint('[GAMIFICATION] Attendance EXP already claimed this session');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastLocalClaim = prefs.getString(_prefAttendanceClaimDateKey);
    if (lastLocalClaim == todayStr) {
      _claimedAttendanceThisSession = true;
      debugPrint('[GAMIFICATION] Attendance EXP already claimed today ($todayStr)');
      return false;
    }

    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return false;

      final url = Uri.parse('$_defaultBackendUrl/api/gamification/claim-attendance');
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final success = data['success'] == true;
        final alreadyClaimed = data['alreadyClaimed'] == true;
        final newTotal = (data['newTotalExp'] as num?)?.toInt();

        _claimedAttendanceThisSession = true;
        await prefs.setString(_prefAttendanceClaimDateKey, todayStr);

        if (newTotal != null) {
          currentExpNotifier.value = newTotal;
        }

        if (success) {
          debugPrint('[GAMIFICATION] Attendance EXP awarded: +$attendanceExpReward XP');
          return true;
        } else if (alreadyClaimed) {
          debugPrint('[GAMIFICATION] Attendance EXP already claimed today according to server');
          return false;
        }
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Failed to claim attendance EXP via server: $e');
    }
    return false;
  }

  /// Observes timetable modification action.
  /// Note: The actual +25 points are awarded server-side by the trusted outbox worker.
  Future<void> recordTimetableAction({required String division}) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final role = AppSettings.currentRole;
    if (role != UserRole.cr && role != UserRole.sr) return;

    // Refresh user's profile after outbox worker processes the event
    Future.delayed(const Duration(seconds: 4), () {
      loadCurrentUserProfile();
    });
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

  /// Fetches the current weekly Champion from server-managed metadata.
  Future<GamificationProfile?> fetchCurrentChampion() async {
    try {
      final doc = await _firestore
          .collection('gamification_meta')
          .doc('current_champion')
          .get();

      if (doc.exists) {
        final profile = GamificationProfile.fromChampionDoc(doc);
        if (profile.uid.isNotEmpty) {
          return profile;
        }
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Error fetching current champion: $e');
    }
    return null;
  }

  /// Loads leaderboard popup data asynchronously. Returns null on failure.
  Future<LeaderboardPopupData?> loadPopupData() async {
    debugPrint('[GAMIFICATION] Leaderboard fetch started');
    try {
      final results = await Future.wait([
        fetchGlobalTop3(),
        fetchBestCR(),
        fetchBestSR(),
        fetchCurrentChampion(),
      ]);

      final top3 = results[0] as List<GamificationProfile>;
      final bestCR = results[1] as GamificationProfile?;
      final bestSR = results[2] as GamificationProfile?;
      final champion = results[3] as GamificationProfile?;

      debugPrint('[GAMIFICATION] Top 3 result count: ${top3.length}');
      debugPrint('[GAMIFICATION] Best CR result: ${bestCR != null ? '${bestCR.displayName} (${bestCR.crPoints} pts)' : 'none'}');
      debugPrint('[GAMIFICATION] Best SR result: ${bestSR != null ? '${bestSR.displayName} (${bestSR.srPoints} pts)' : 'none'}');
      debugPrint('[GAMIFICATION] Champion result: ${champion != null ? '${champion.displayName} (${champion.weeklyExp} XP)' : 'none'}');

      return LeaderboardPopupData(
        top3: top3,
        bestCR: bestCR,
        bestSR: bestSR,
        champion: champion,
      );
    } catch (e, st) {
      debugPrint('[GAMIFICATION] Error loading popup data: $e\n$st');
      return null;
    }
  }

  /// Automatically displays the 6-second leaderboard popup once per session
  /// if valid leaderboard data is available. Non-blocking.
  Future<void> showAutoLeaderboardPopupIfEligible(BuildContext context) async {
    debugPrint('[GAMIFICATION] Session popup check started');
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
    } catch (e, st) {
      debugPrint('[GAMIFICATION] Error showing popup: $e\n$st');
    }
  }
}
