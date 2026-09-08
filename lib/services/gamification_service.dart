import 'dart:async';
import 'package:flutter/material.dart';

import '../models/gamification_profile.dart';

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
  GamificationService._() {
    championThemeUnlockedNotifier.value = true;
  }
  static final GamificationService instance = GamificationService._();

  static const int dailyExpReward = 20;
  static const int attendanceExpReward = 10;
  static const int timetableActionReward = 25;

  // Reactive notifiers for current user's EXP, points, and Champion status
  final ValueNotifier<int> currentExpNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentCrPointsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentSrPointsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isChampionNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> championThemeUnlockedNotifier = ValueNotifier<bool>(true);

  /// Champion visual theme is universally unlocked for every user.
  bool get hasChampionThemeAccess => true;

  /// Initial load or refresh of current user's stats (Suppressed)
  Future<GamificationProfile?> loadCurrentUserProfile() async => null;

  /// Checks if current user is the active weekly Champion (Universally unlocked)
  Future<bool> checkChampionStatus() async {
    championThemeUnlockedNotifier.value = true;
    return true;
  }
  /// All EXP and Gamification logic is temporarily suppressed for stability.
  Future<bool> checkAndClaimDailyExp() async => false;
  Future<bool> recordAttendanceView() async => false;
  Future<void> recordTimetableAction({required String division}) async {}
  Future<List<GamificationProfile>> fetchGlobalTop3() async => const [];
  Future<GamificationProfile?> fetchBestCR() async => null;
  Future<GamificationProfile?> fetchBestSR() async => null;
  Future<GamificationProfile?> fetchCurrentChampion() async => null;
  Future<LeaderboardPopupData?> loadPopupData() async => null;
  Future<void> showAutoLeaderboardPopupIfEligible(BuildContext context) async {}
}
